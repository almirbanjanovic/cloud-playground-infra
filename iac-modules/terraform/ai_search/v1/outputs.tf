output "id" {
  description = "The ID of the AI Search service."
  value       = azurerm_search_service.this.id
}

output "name" {
  description = "The name of the AI Search service."
  value       = azurerm_search_service.this.name
}

output "search_service_url" {
  description = "URL of the Search Service."
  value       = "https://${local.name}.search.windows.net"
}

output "principal_id" {
  description = "The principal ID of the system-assigned managed identity, if enabled."
  value       = try(azurerm_search_service.this.identity[0].principal_id, null)
}

output "tenant_id" {
  description = "The tenant ID of the system-assigned managed identity, if enabled."
  value       = try(azurerm_search_service.this.identity[0].tenant_id, null)
}

output "role_assignment_ids" {
  description = "IDs of the role assignments created on this search service."
  value       = { for k, v in azurerm_role_assignment.this : k => v.id }
}