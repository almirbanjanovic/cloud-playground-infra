output "id" {
  value = azurerm_storage_account.this.id
}


output "name" {
  value = azurerm_storage_account.this.name
}

output "principal_id" {
  description = "The principal ID of the system-assigned managed identity, if enabled."
  value       = try(azurerm_storage_account.this.identity[0].principal_id, null)
}

output "tenant_id" {
  description = "The tenant ID of the system-assigned managed identity, if enabled."
  value       = try(azurerm_storage_account.this.identity[0].tenant_id, null)
}

output "role_assignment_ids" {
  description = "IDs of the role assignments created on this storage account."
  value       = { for k, v in azurerm_role_assignment.this : k => v.id }
}