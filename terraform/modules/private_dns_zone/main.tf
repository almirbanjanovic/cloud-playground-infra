
resource "azurerm_private_dns_zone" "this" {
  name                = var.dns_zone
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "vnet-link-${var.virtual_network_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false

  tags = var.tags

  depends_on = [azurerm_private_dns_zone.this]
}