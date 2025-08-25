output "id" {
  description = "The ID of the Azure Container Registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "The name of the Azure Container Registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "The login server of the Azure Container Registry."
  value       = azurerm_container_registry.this.login_server
}