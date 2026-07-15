output "id" {
  description = "The ID of the private endpoint."
  value       = azurerm_private_endpoint.this.id
}

output "name" {
  description = "The name of the private endpoint."
  value       = azurerm_private_endpoint.this.name
}

output "private_service_connection_id" {
  description = "The private service connection ID of the private endpoint."
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_connection_resource_id
}

output "private_service_connection_name" {
  description = "The name of the private service connection."
  value       = azurerm_private_endpoint.this.private_service_connection[0].name
}

output "private_dns_zone_group_id" {
  description = "The ID of the private DNS zone group."
  value       = azurerm_private_endpoint.this.private_dns_zone_group[0].id
}

output "private_dns_zone_group_name" {
  description = "The name of the private DNS zone group."
  value       = azurerm_private_endpoint.this.private_dns_zone_group[0].name
}