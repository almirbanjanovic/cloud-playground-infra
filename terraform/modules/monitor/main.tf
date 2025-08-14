#--------------------------------------------------------------------------------------------------------------------------------
# General configuration
#--------------------------------------------------------------------------------------------------------------------------------

locals {
  azure_monitor_private_link_scope_name = "ampls-${var.base_name}-${var.environment}-${var.location}"
  app_insights_name                     = "appi-${var.base_name}-${var.environment}-${var.location}"
  ampls_to_log                          = "ampls-to-log-${var.base_name}-${var.environment}-${var.location}"
  log_analytics_name                    = "log-${var.base_name}-${var.environment}-${var.location}"
  ampls_to_appi                         = "ampls-to-appi-${var.base_name}-${var.environment}-${var.location}"
}

# Assign the "Storage Blob Data Contributor" role to the "Diagnostic Services Trusted Storage Access"
resource "azurerm_role_assignment" "diagnostics_services_trusted_storage_access" {
  principal_id         = var.diagnostic_services_trusted_storage_access_object_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = var.storage_account_id
}

#--------------------------------------------------------------------------------------------------------------------------------
# Log Analytics Workspace
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                       = local.log_analytics_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  sku                        = "PerGB2018"

  tags = var.tags

  depends_on = [azurerm_role_assignment.diagnostics_services_trusted_storage_access]
}


resource "azurerm_monitor_private_link_scoped_service" "ampls_link_to_log" {
  name                = local.ampls_to_log
  resource_group_name = var.ampls_resource_group_name
  scope_name          = var.monitor_private_link_scope_name
  linked_resource_id  = azurerm_log_analytics_workspace.this.id

  depends_on = [azurerm_log_analytics_workspace.this]
}


resource "azurerm_log_analytics_linked_storage_account" "log_query" {
  data_source_type      = "Query"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  storage_account_ids   = [var.storage_account_id]
}

resource "azurerm_log_analytics_linked_storage_account" "log_custom_logs" {
  data_source_type      = "CustomLogs"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  storage_account_ids   = [var.storage_account_id]
}


resource "azurerm_log_analytics_linked_storage_account" "log_alerts" {
  data_source_type      = "Alerts"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  storage_account_ids   = [var.storage_account_id]
}

/*
resource "azurerm_log_analytics_linked_storage_account" "log_ingestion" {
  data_source_type      = "Ingestion"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  storage_account_ids   = [var.storage_account_id]
}
*/

#--------------------------------------------------------------------------------------------------------------------------------
# App Insights 
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_application_insights" "this" {
  name                       = local.app_insights_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  workspace_id               = azurerm_log_analytics_workspace.this.id
  application_type           = "web"

  tags = var.tags
}

resource "azurerm_monitor_private_link_scoped_service" "ampls_link_to_appi" {
  name                = local.ampls_to_appi
  resource_group_name = var.ampls_resource_group_name
  scope_name          = var.monitor_private_link_scope_name
  linked_resource_id  = azurerm_application_insights.this.id

  depends_on = [azurerm_application_insights.this]
}

/*resource "azapi_resource" "app_insights_linked_storage_account" {
  type      = "microsoft.insights/components/linkedStorageAccounts@2020-03-01-preview"
  name      = "ServiceProfiler"
  parent_id = azurerm_application_insights.this.id
  body = {
    properties = {
      linkedStorageAccount = var.storage_account_id
    }
  }
}*/