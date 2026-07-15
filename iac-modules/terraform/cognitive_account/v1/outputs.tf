output "id" {
  value = azurerm_cognitive_account.this.id
}

output "name" {
  value = azurerm_cognitive_account.this.name
}

output "endpoint" {
  value = azurerm_cognitive_account.this.endpoint
}

output "principal_id" {
  value = try(azurerm_cognitive_account.this.identity[0].principal_id, null)
}

output "tenant_id" {
  value = try(azurerm_cognitive_account.this.identity[0].tenant_id, null)
}

output "role_assignment_ids" {
  description = "IDs of the role assignments created on this Cognitive Services account."
  value       = { for k, v in azurerm_role_assignment.this : k => v.id }
}
