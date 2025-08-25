#--------------------------------------------------------------------------------------------------------------------------------
# General configuration
#--------------------------------------------------------------------------------------------------------------------------------

locals {
  amdcr_name = "amdcr-container-insights-${var.base_name}-${var.environment}-${var.location}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# Container Insights
#--------------------------------------------------------------------------------------------------------------------------------

resource "null_resource" "enable_container_insights_addon" {
  provisioner "local-exec" {
    command = <<EOT

      # Login using service principal from environment variables.   
      # This is required if using service principal authentication.
      az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

      az aks enable-addons \
        --addon monitoring \
        --name ${var.aks_name} \
        --resource-group ${var.resource_group_name} \
        --workspace-resource-id ${var.log_analytics_workspace_id}
    EOT
  }
}

resource "azurerm_monitor_data_collection_rule" "dcr_msci" {
  name                = local.amdcr_name
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = var.streams
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      streams        = var.streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : var.data_collection_interval,
          "namespaceFilteringMode" : var.namespace_filtering_mode_for_data_collection,
          "namespaces" : var.namespaces_for_data_collection
          "enableContainerLogV2" : var.enableContainerLogV2
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  description = "Data Collection Rule (DCR) for Azure Monitor Container Insights"

  depends_on = [
    null_resource.enable_container_insights_addon
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "dcra_msci" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = var.aks_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_msci.id
  description             = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}