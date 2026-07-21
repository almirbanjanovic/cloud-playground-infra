output "id" {
  description = "Resource ID of the private DNS zone. Wire this into a private endpoint's `private_dns_zone_group.private_dns_zone_ids`."
  value       = azurerm_private_dns_zone.this.id
}

output "name" {
  description = "Name of the private DNS zone."
  value       = azurerm_private_dns_zone.this.name
}

output "vnet_link_id" {
  description = "Resource ID of the VNet-to-zone link."
  value       = azurerm_private_dns_zone_virtual_network_link.this.id
}

output "vnet_link_name" {
  description = "Name of the VNet-to-zone link (derived from `virtual_network_name`)."
  value       = azurerm_private_dns_zone_virtual_network_link.this.name
}