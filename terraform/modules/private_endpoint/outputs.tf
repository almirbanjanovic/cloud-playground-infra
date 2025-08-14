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

#output "data_ip_address" {
#  description = "The private IP address of the private endpoint."
#  value       = azurerm_private_endpoint.this.private_dns_zone_configs[0].record_sets[0].ip_addresses[0]
#}

output "acr_data_ip_address" {
  description = "The private IP address of the private endpoint."

  value = one([
    for record_set in azurerm_private_endpoint.this.private_dns_zone_configs[0].record_sets : record_set.ip_addresses[0]
    if record_set.fqdn == "acr${var.base_name}${var.environment}${var.location}.eastus2.data.privatelink.azurecr.io"
  ])
}