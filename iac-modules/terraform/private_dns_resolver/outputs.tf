output "dns_resolver_id" {
  value = azurerm_private_dns_resolver.this.id
}

output "inbound_endpoint_id" {
  value = azurerm_private_dns_resolver_inbound_endpoint.this.id
}

output "ip_address" {
  value = azurerm_private_dns_resolver_inbound_endpoint.this.ip_configurations[0].private_ip_address
}