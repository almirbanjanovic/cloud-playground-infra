locals {
  azure_managed_grafana_name = substr("amg-${var.base_name}-${var.environment}-${var.location}", 0, 23)
}

// Get current Azure Client Configuration
data "azurerm_client_config" "current" {}

# Null resource that triggers a recreation every time due to timestamp()
resource "null_resource" "force_recreate" {
  triggers = {
    always_run = timestamp() # This will change every time `terraform apply` is run
  }
}

#--------------------------------------------------------------------------------------------------------------------------------
# Grafana
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "grafana_subscription_monitoring_data_reader" {
  scope                = format("/subscriptions/%s", data.azurerm_client_config.current.subscription_id)
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id

  depends_on = [azurerm_dashboard_grafana.this]
}

resource "azurerm_dashboard_grafana" "this" {
  name                          = local.azure_managed_grafana_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  public_network_access_enabled = false
  sku                           = "Standard"
  zone_redundancy_enabled       = false
  grafana_major_version         = "11"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = var.azure_monitor_workspace_id
  }
  tags = var.tags
}

module "private_endpoint_amg" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_dashboard_grafana.this.id
  resource_name                   = local.azure_managed_grafana_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.amg_subresource_names
  private_dns_zone_ids            = var.amg_private_dns_zone_ids
  private_dns_a_record_name       = local.azure_managed_grafana_name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_dashboard_grafana.this]
}

#--------------------------------------------------------------------------------------------------------------------------------
# Create Managed Private Endpoint Connection to Azure Monitor Workspace and Azure Monitor Private Link Scope
#--------------------------------------------------------------------------------------------------------------------------------

resource "azapi_resource" "grafana_managed_private_endpoint_connection_amw" {
  type      = "Microsoft.Dashboard/grafana/managedPrivateEndpoints@2023-09-01"
  name      = "mpep-amw"
  tags      = var.tags
  location  = var.location
  parent_id = azurerm_dashboard_grafana.this.id
  body = {
    properties = {
      groupIds = [
        "prometheusMetrics"
      ]
      privateLinkResourceId     = var.azure_monitor_workspace_id
      privateLinkResourceRegion = var.location
      requestMessage            = "Created by Terraform"
    }
  }

  # Lifecycle block to force recreation based on null_resource trigger
  lifecycle {
    replace_triggered_by = [null_resource.force_recreate]
  }

  depends_on = [azurerm_dashboard_grafana.this]
}

resource "azapi_resource" "grafana_managed_private_endpoint_connection_ampls" {
  type      = "Microsoft.Dashboard/grafana/managedPrivateEndpoints@2023-09-01"
  name      = "mpep-ampls"
  tags      = var.tags
  location  = var.location
  parent_id = azurerm_dashboard_grafana.this.id
  body = {
    properties = {
      groupIds = [
        "azuremonitor"
      ]
      privateLinkResourceId     = var.azurerm_monitor_private_link_scope_id
      privateLinkResourceRegion = var.location
      requestMessage            = "Created by Terraform"
    }
  }

  # Lifecycle block to force recreation based on null_resource trigger
  lifecycle {
    replace_triggered_by = [null_resource.force_recreate]
  }

  depends_on = [azapi_resource.grafana_managed_private_endpoint_connection_amw, azurerm_dashboard_grafana.this]
}

# the actual azurerm_monitor_workspace resource doesn't yet export the private endpoint connections information
# so we use the azapi provider to get that (once they've been created, otherwise things fail)
data "azapi_resource" "azurerm_monitor_workspace" {
  type                   = "Microsoft.Monitor/accounts@2023-04-03"
  resource_id            = var.azure_monitor_workspace_id
  response_export_values = ["properties.privateEndpointConnections"]
  depends_on             = [azapi_resource.grafana_managed_private_endpoint_connection_amw]
}

data "azapi_resource" "azurerm_private_link_scope" {
  type                   = "Microsoft.Insights/privateLinkScopes@2021-07-01-preview"
  resource_id            = var.azurerm_monitor_private_link_scope_id
  response_export_values = ["properties.privateEndpointConnections"]
  depends_on             = [azapi_resource.grafana_managed_private_endpoint_connection_ampls]
}

# Retrieve the private endpoint connection name from the monitor account based on the private endpoint name
locals {
  private_endpoint_connection_name_amw = element([
    for connection in jsondecode(data.azapi_resource.azurerm_monitor_workspace.output).properties.privateEndpointConnections
    : connection.name
    if endswith(connection.properties.privateEndpoint.id, "grafana-${local.azure_managed_grafana_name}-${azapi_resource.grafana_managed_private_endpoint_connection_amw.name}")
    ],
    0
  )

  private_endpoint_connection_name_ampls = element([
    for connection in jsondecode(data.azapi_resource.azurerm_private_link_scope.output).properties.privateEndpointConnections
    : connection.name
    if endswith(connection.properties.privateEndpoint.id, "grafana-${local.azure_managed_grafana_name}-${azapi_resource.grafana_managed_private_endpoint_connection_ampls.name}")
    ],
    0
  )
}

# Approve the managed private endpoints - have to use azapi provider since the azurerm
# provider doesn't have the ability to do this natively yet 
resource "azapi_update_resource" "grafana_managed_private_endpoint_connection_amw_approval" {
  type      = "Microsoft.Monitor/accounts/privateEndpointConnections@2023-04-03"
  name      = local.private_endpoint_connection_name_amw
  parent_id = var.azure_monitor_workspace_id

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        actionsRequired = "None"
        description     = "Approved via Terraform"
        status          = "Approved"
      }
    }
  }

  ignore_missing_property = true
  ignore_casing           = true

  depends_on = [azapi_resource.grafana_managed_private_endpoint_connection_amw]
}

resource "azapi_update_resource" "grafana_managed_private_endpoint_connection_ampls_approval" {
  type      = "Microsoft.Insights/privateLinkScopes/privateEndpointConnections@2021-07-01-preview"
  name      = local.private_endpoint_connection_name_ampls
  parent_id = var.azurerm_monitor_private_link_scope_id

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        actionsRequired = "None"
        description     = "Approved via Terraform"
        status          = "Approved"
      }
    }
  }

  ignore_missing_property = true
  ignore_casing           = true

  depends_on = [azapi_resource.grafana_managed_private_endpoint_connection_ampls]
}
