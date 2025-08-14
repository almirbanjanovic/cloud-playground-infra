output "id" {
  description = "The ID of the Application Gateway."
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "The name of the Application Gateway."
  value       = azurerm_application_gateway.this.name
}