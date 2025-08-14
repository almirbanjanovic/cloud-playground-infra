output "app_insights_id" {
  value = azurerm_application_insights.this.id
}

output "app_insights_connection_string" {
  value = azurerm_application_insights.this.connection_string
}

output "app_insights_instrumentation_key" {
  value = azurerm_application_insights.this.instrumentation_key
}

output "app_insights_name" {
  value = azurerm_application_insights.this.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.this.name
}