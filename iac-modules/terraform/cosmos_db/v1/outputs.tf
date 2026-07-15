output "id" {
  description = "The ID of the Cosmos DB account."
  value       = azurerm_cosmosdb_account.this.id
}

output "name" {
  description = "The name of the Cosmos DB account."
  value       = azurerm_cosmosdb_account.this.name
}

output "endpoint" {
  description = "The endpoint of the Cosmos DB account."
  value       = azurerm_cosmosdb_account.this.endpoint
}

output "read_endpoints" {
  description = "The read endpoints of the Cosmos DB account."
  value       = azurerm_cosmosdb_account.this.read_endpoints
}

output "write_endpoints" {
  description = "The write endpoints of the Cosmos DB account."
  value       = azurerm_cosmosdb_account.this.write_endpoints
}

output "principal_id" {
  description = "The principal ID of the system-assigned managed identity, if enabled."
  value       = try(azurerm_cosmosdb_account.this.identity[0].principal_id, null)
}

output "tenant_id" {
  description = "The tenant ID of the system-assigned managed identity, if enabled."
  value       = try(azurerm_cosmosdb_account.this.identity[0].tenant_id, null)
}

output "private_endpoint_id" {
  description = "The ID of the private endpoint attached to the Cosmos DB account."
  value       = module.cosmos_private_endpoint.id
}

output "role_assignment_ids" {
  description = "IDs of the control-plane role assignments created on this account."
  value       = { for k, v in azurerm_role_assignment.this : k => v.id }
}

output "sql_role_assignment_ids" {
  description = "IDs of the Cosmos DB SQL data-plane role assignments created on this account."
  value       = { for k, v in azurerm_cosmosdb_sql_role_assignment.this : k => v.id }
}
