output "vm_id" {
  description = "Resource ID of the runner VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the runner VM."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Primary private IP of the runner NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "system_assigned_principal_id" {
  description = "Principal ID of the VM's system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}

output "user_assigned_identity_id" {
  description = "Resource ID of the user-assigned managed identity attached to the VM. Attach a GitHub Actions federated identity credential here."
  value       = azurerm_user_assigned_identity.this.id
}

output "user_assigned_identity_name" {
  description = "Name of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.name
}

output "user_assigned_principal_id" {
  description = "Principal ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "user_assigned_client_id" {
  description = "Client ID of the user-assigned managed identity. Use as the `client-id` input to `azure/login@v2` in GitHub Actions workflows."
  value       = azurerm_user_assigned_identity.this.client_id
}
