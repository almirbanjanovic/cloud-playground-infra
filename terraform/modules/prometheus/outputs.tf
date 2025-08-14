output "azure_monitor_workspace_id" {
  description = "The ID of the Azure Monitor Workspace for Prometheus monitoring"
  value       = azurerm_monitor_workspace.this.id
}

output "azure_monitor_workspace_name" {
  description = "The name of the Azure Monitor Workspace for Prometheus monitoring"
  value       = azurerm_monitor_workspace.this.name
}
