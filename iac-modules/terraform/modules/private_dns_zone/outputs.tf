output "id" {
  value = azurerm_private_dns_zone.this.id
}

output "name" {
  value = azurerm_private_dns_zone.this.name
}

output "vnet_link_id" {
  value = azurerm_private_dns_zone_virtual_network_link.this.id
}

output "vnet_link_name" {
  value = azurerm_private_dns_zone_virtual_network_link.this.name
}
