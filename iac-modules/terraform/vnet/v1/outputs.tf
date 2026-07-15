output "id" {
  description = "The ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "The address space of the Virtual Network."
  value       = azurerm_virtual_network.this.address_space
}

output "resource_group_name" {
  description = "Resource group of the Virtual Network (pass-through for convenience when wiring the subnet module)."
  value       = var.resource_group_name
}

