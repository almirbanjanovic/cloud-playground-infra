output "id" {
  description = "The ID of the Foundry project."
  value       = azurerm_cognitive_account_project.this.id
}

output "name" {
  description = "The name of the Foundry project."
  value       = azurerm_cognitive_account_project.this.name
}

output "principal_id" {
  description = "Principal ID of the project's system-assigned managed identity."
  value       = try(azurerm_cognitive_account_project.this.identity[0].principal_id, null)
}

output "tenant_id" {
  description = "Tenant ID of the project's system-assigned managed identity."
  value       = try(azurerm_cognitive_account_project.this.identity[0].tenant_id, null)
}

output "endpoints" {
  description = "Map of endpoint names to URLs for the project."
  value       = azurerm_cognitive_account_project.this.endpoints
}

output "storage_connection_id" {
  description = "ID of the Foundry account-level storage connection, if enabled."
  value       = try(azurerm_cognitive_account_connection_entra_id.storage[0].id, null)
}

output "cosmos_connection_id" {
  description = "ID of the Foundry account-level Cosmos DB connection, if enabled."
  value       = try(azurerm_cognitive_account_connection_entra_id.cosmos[0].id, null)
}

output "search_connection_id" {
  description = "ID of the Foundry account-level AI Search connection, if enabled."
  value       = try(azurerm_cognitive_account_connection_entra_id.search[0].id, null)
}

output "capability_host_id" {
  description = "ID of the project-scoped Agent Service capability host, if enabled."
  value       = try(azapi_resource.capability_host[0].id, null)
}

output "account_capability_host_id" {
  description = "ID of the account-scoped Agent Service capability host, if enabled. Required to exist alongside the project host per Standard Agent Setup."
  value       = try(azapi_resource.account_capability_host[0].id, null)
}
