output "nat_gateway_id" {
  description = "The ID of the NAT Gateway."
  value       = azurerm_nat_gateway.this.id
}

output "nat_gateway_name" {
  description = "The name of the NAT Gateway."
  value       = azurerm_nat_gateway.this.name
}

output "public_ip_prefix_id" {
  description = "The ID of the Public IP Prefix."
  value       = azurerm_public_ip_prefix.this.id
}

output "public_ip_prefix_name" {
  description = "The name of the Public IP Prefix."
  value       = azurerm_public_ip_prefix.this.name
}

output "nat_gateway_ip_prefix_association_id" {
  description = "The ID of the NAT Gateway IP Prefix Association."
  value       = azurerm_nat_gateway_public_ip_prefix_association.this.id
}
