output "vm_id" {
  description = "Resource ID of the jumpbox VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the jumpbox VM (useful for `az ssh vm --name`)."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Primary private IP of the jumpbox NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip_address" {
  description = "Public IP address if `enable_public_ip = true`, otherwise null."
  value       = var.enable_public_ip ? azurerm_public_ip.this[0].ip_address : null
}

output "system_assigned_principal_id" {
  description = "Principal ID of the VM's system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}

output "user_assigned_identity_id" {
  description = "Resource ID of the user-assigned managed identity attached to the VM."
  value       = azurerm_user_assigned_identity.this.id
}

output "user_assigned_principal_id" {
  description = "Principal ID of the user-assigned managed identity attached to the VM."
  value       = azurerm_user_assigned_identity.this.principal_id
}
