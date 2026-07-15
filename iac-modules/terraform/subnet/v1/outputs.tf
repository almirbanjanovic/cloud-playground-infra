output "subnet_ids" {
  description = "Map from the caller's logical subnet key to the created subnet's Azure resource ID."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}

output "subnet_names" {
  description = "Map from the caller's logical subnet key to the actual Azure subnet name."
  value       = { for k, v in azurerm_subnet.this : k => v.name }
}

output "subnets" {
  description = "Full map of created subnet resources, keyed by the caller's logical subnet key."
  value       = azurerm_subnet.this
}
