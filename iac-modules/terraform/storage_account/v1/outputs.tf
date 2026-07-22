output "id" {
  value = azurerm_storage_account.this.id
}


output "name" {
  value = azurerm_storage_account.this.name
}

# Cloud-suffix-aware blob endpoint. Callers must NOT string-interpolate
# `.blob.core.windows.net` — that suffix only holds in the Azure public
# cloud (China / Government / Stack use different suffixes). This output
# lifts the correct value from the ARM RP's computed properties so the
# module works in every sovereign cloud without changes.
output "blob_endpoint" {
  description = "Primary blob endpoint URL (e.g. https://<name>.blob.core.windows.net/). Uses the sovereign-cloud-correct suffix from the ARM RP."
  value       = azurerm_storage_account.this.primary_blob_endpoint
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