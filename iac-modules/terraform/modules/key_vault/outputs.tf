output "id" {
  description = "The ID of the safetower key vault."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "The name of the safetower key vault."
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "The URI of the safetower key vault."
  value       = azurerm_key_vault.this.vault_uri
}