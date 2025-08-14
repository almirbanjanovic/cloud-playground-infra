#--------------------------------------------------------------------------------------------------------------------------------
# General Configuration
#--------------------------------------------------------------------------------------------------------------------------------
locals {
  name                               = "${var.suffix}-${var.base_name}-${var.environment}-${var.location}"
  aks_compute_name                   = "aks-compute"
  alert_failed_jobs_alert_rule_name  = "apr-mlw-failedJobsAlert-${var.base_name}-${var.environment}-${var.location}"
  alert_failed_jobs_alert_group_name = "ag-mlw-failedJobsAlert-${var.base_name}-${var.environment}-${var.location}"
  alert_failed_jobs_email_receivers  = jsondecode(var.alert_failed_jobs_email_receivers)
}

// Get current Azure Client Configuration
data "azurerm_client_config" "current" {}

#--------------------------------------------------------------------------------------------------------------------------------
# Storage Acccount
#--------------------------------------------------------------------------------------------------------------------------------
module "machine_learning_storage_account" {
  source                           = "../storage_account"
  base_name                        = var.base_name
  environment                      = var.environment
  location                         = var.location
  resource_group_name              = var.resource_group_name
  suffix                           = var.suffix
  storage_account_tier             = var.storage_account_tier
  storage_account_replication_type = var.storage_account_replication_type
  min_tls_version                  = var.storage_account_min_tls_version
  enable_https_traffic_only        = var.storage_account_enable_https_traffic_only
  publish_microsoft_endpoint       = true
  #network_rules_default_action     = var.storage_account_network_rules_default_action

  subnet_id                  = var.subnet_id
  blob_private_dns_zone_ids  = var.blob_private_dns_zone_ids
  table_private_dns_zone_ids = var.table_private_dns_zone_ids
  queue_private_dns_zone_ids = var.queue_private_dns_zone_ids
  file_private_dns_zone_ids  = var.file_private_dns_zone_ids
  web_private_dns_zone_ids   = var.web_private_dns_zone_ids
  dfs_private_dns_zone_ids   = var.dfs_private_dns_zone_ids

  tags = var.tags
}


#--------------------------------------------------------------------------------------------------------------------------------
# Key Vault
#--------------------------------------------------------------------------------------------------------------------------------
module "kv" {
  source                          = "../key_vault"
  base_name                       = var.base_name
  suffix                          = var.suffix
  environment                     = var.environment
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku_name                        = var.kv_sku
  tenant_id                       = var.kv_tenant_id
  enable_rbac_authorization       = var.kv_enable_rbac_authorization
  enabled_for_template_deployment = var.kv_enabled_for_template_deployment
  network_acls_bypass             = var.kv_network_acls_bypass
  network_acls_default_action     = var.kv_network_acls_default_action
  soft_delete_retention_days      = var.kv_soft_delete_retention_days
  purge_protection_enabled        = var.kv_purge_protection_enabled

  subnet_id            = var.subnet_id
  private_dns_zone_ids = var.kv_private_dns_zone_ids

  allowed_ips = var.kv_allowed_ips

  tags = var.tags
}

module "kv_secrets" {
  source = "../key_vault_secrets"

  key_vault_id = module.kv.id

  secrets = {
    "pyodbConnectionString" = var.python_connection_string
    "OpenAiApiKey"          = var.openai_api_key
  }

  depends_on = [module.kv]
}

#--------------------------------------------------------------------------------------------------------------------------------
# Machine Learning Workspace
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_machine_learning_workspace" "this" {
  name                    = local.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = var.application_insights_id
  key_vault_id            = module.kv.id
  storage_account_id      = module.machine_learning_storage_account.id
  container_registry_id   = var.container_registry_id

  high_business_impact          = true
  public_network_access_enabled = var.machine_learning_public_network_access_enabled
  friendly_name                 = var.machine_learning_friendly_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [module.kv, module.machine_learning_storage_account]
}

module "machine_learning_private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_machine_learning_workspace.this.id
  resource_name                   = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.machine_learning_subresource_names
  private_dns_zone_ids            = var.machine_learning_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_machine_learning_workspace.this]
}

resource "null_resource" "az_login_ml_install" {
  provisioner "local-exec" {
    command = <<-EOT
      # Login using service principal
      echo "Login using service principal ..."
      az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

      # Enable dynamic extension installation
      echo "Enable dynamic extension installation ..."
      az config set extension.use_dynamic_install=yes_without_prompt

      # Disable preview versions
      echo "Disable preview versions ..."
      az config set extension.dynamic_install_allow_preview=false    

    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}


resource "null_resource" "create_compute" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "Checking if AKS compute is already attached..."

      if az ml compute show --name $AKS_COMPUTE_NAME \
        --resource-group $MLW_RESOURCE_GROUP \
        --workspace-name $MLW_NAME > /dev/null 2>&1; then
        echo "Compute $AKS_COMPUTE_NAME already exists, skipping creation."
      else
        echo "Compute $AKS_COMPUTE_NAME does not exist. Creating AKS compute target..."
        az ml compute attach \
          --name $AKS_COMPUTE_NAME \
          --resource-group $MLW_RESOURCE_GROUP \
          --workspace-name $MLW_NAME \
          --type Kubernetes \
          --resource-id $AKS_ID \
          --identity-type SystemAssigned \
          --namespace $AKS_COMPUTE_NAMESPACE

        if [ $? -eq 0 ]; then
          echo "Compute $AKS_COMPUTE_NAME created successfully..."
        else
          echo "Failed to create compute $AKS_COMPUTE_NAME..." >&2
          exit 1
        fi
      fi
    EOT

    environment = {
      MLW_NAME              = azurerm_machine_learning_workspace.this.name
      MLW_RESOURCE_GROUP    = azurerm_machine_learning_workspace.this.resource_group_name
      AKS_COMPUTE_NAME      = local.aks_compute_name
      AKS_ID                = var.aks_id
      AKS_COMPUTE_NAMESPACE = var.aks_namespace_name
    }

    interpreter = ["bash", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    null_resource.az_login_ml_install,
    azurerm_machine_learning_workspace.this,
    module.machine_learning_storage_account,
    module.kv
  ]
}

# This script retrieves the service principal ID for the given AKS compute
# For more information please see Terraform documentation:
# https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external
data "external" "get_compute_sp_id" {

  count = var.enable_external_data ? 1 : 0

  program = ["bash", "../../../../../assets/scripts/get_compute_sp_id.sh"]

  query = {
    AKS_COMPUTE_NAME   = local.aks_compute_name
    MLW_RESOURCE_GROUP = azurerm_machine_learning_workspace.this.resource_group_name
    MLW_NAME           = azurerm_machine_learning_workspace.this.name
  }

  depends_on = [
    null_resource.az_login_ml_install,
    null_resource.create_compute
  ]
}

resource "null_resource" "test_sp" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Service Principal ID: ${data.external.get_compute_sp_id[0].result["compute_sp_id"]}"
    EOT
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    data.external.get_compute_sp_id
  ]
}

#--------------------------------------------------------------------------------------------------------------------------------
# Role Assignments
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "mlw_acr" {
  principal_id         = azurerm_machine_learning_workspace.this.identity[0].principal_id
  role_definition_name = "AcrPush"
  scope                = var.container_registry_id

  depends_on = [azurerm_machine_learning_workspace.this]
}

resource "azurerm_role_assignment" "mlw_storage_account" {
  principal_id         = azurerm_machine_learning_workspace.this.identity[0].principal_id
  role_definition_name = "Storage Blob Data Owner"
  scope                = module.machine_learning_storage_account.id

  depends_on = [azurerm_machine_learning_workspace.this]
}

resource "azurerm_role_assignment" "compute_sp_kv_contributor" {
  principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
  role_definition_name = "Contributor"
  scope                = module.kv.id

  depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0], module.kv]
}

resource "azurerm_role_assignment" "compute_sp_kv_admin" {
  principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
  role_definition_name = "Key Vault Administrator"
  scope                = module.kv.id

  depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0], module.kv]
}

# resource "azurerm_role_assignment" "compute_sp_storage_account_contributor" {
#   principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
#   role_definition_name = "Contributor"
#   scope                = module.machine_learning_storage_account.id

#   depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0], module.machine_learning_storage_account]
# }

resource "azurerm_role_assignment" "compute_sp_mlw_data_cientist" {
  principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
  role_definition_name = "AzureML Data Scientist"
  scope                = azurerm_machine_learning_workspace.this.id

  depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0], azurerm_machine_learning_workspace.this]
}

resource "azurerm_role_assignment" "compute_sp_storage_account_blob_data_owner" {
  principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
  role_definition_name = "Storage Blob Data Owner"
  scope                = module.machine_learning_storage_account.id

  depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0], module.machine_learning_storage_account]
}

resource "azurerm_role_assignment" "compute_sp_acr_pull" {
  principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
  role_definition_name = "AcrPull"
  scope                = var.container_registry_id

  depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0]]
}

# resource "azurerm_role_assignment" "compute_sp_mlw_contributor" {
#   principal_id         = data.external.get_compute_sp_id[0].result["compute_sp_id"]
#   role_definition_name = "Contributor"
#   scope                = azurerm_machine_learning_workspace.this.id

#   depends_on = [null_resource.create_compute, data.external.get_compute_sp_id[0], azurerm_machine_learning_workspace.this]
# }

#--------------------------------------------------------------------------------------------------------------------------------
# Alerts
#--------------------------------------------------------------------------------------------------------------------------------
#resource "azurerm_monitor_metric_alert" "failed_jobs_alert" {
#  name = local.alert_failed_jobs_alert_rule_name
#
#  count = var.alert_failed_jobs_enabled ? 1 : 0
#
#  resource_group_name = var.resource_group_name
#  scopes              = [azurerm_machine_learning_workspace.this.id]
#  description         = "triggers when any job fails in the workspace"
#  severity            = 1
#
#  action {
#    action_group_id = azurerm_monitor_action_group.failed_jobs_action_group[0].id
#  }
#
#  criteria {
#    metric_namespace = var.alert_failed_jobs_metric_namespace
#    metric_name      = "Failed Runs"
#    aggregation      = "Count"
#    operator         = "GreaterThanOrEqual"
#    threshold        = 1
#  }
#}

#resource "azurerm_monitor_action_group" "failed_jobs_action_group" {
#  name = local.alert_failed_jobs_alert_group_name
#
#  count = var.alert_failed_jobs_enabled ? 1 : 0
#
#  resource_group_name = var.resource_group_name
#  short_name          = "mlErrorGrp"
#
#  # Loop through each email receiver
#  dynamic "email_receiver" {
#    for_each = local.alert_failed_jobs_email_receivers
#    content {
#      name                    = email_receiver.value.name
#      email_address           = email_receiver.value.email_address
#      use_common_alert_schema = true
#    }
#  }
#}

