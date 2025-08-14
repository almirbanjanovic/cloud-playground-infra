locals {
  name                  = "dnspr-${var.base_name}-${var.environment}-${var.location}"
  subnet_name           = "snet-${var.base_name}-${var.environment}-${local.name}"
  inbound_endpoint_name = "in-${var.base_name}-${var.environment}-${local.name}"
}

resource "azurerm_private_dns_resolver" "this" {
  name                = local.name
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_network_id  = var.virtual_network_id

  tags = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  name                    = local.inbound_endpoint_name
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = var.location

  ip_configurations {
    subnet_id                    = var.subnet_id
    private_ip_allocation_method = var.private_ip_allocation_method
    private_ip_address           = var.private_ip_address
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_resolver.this]
}
