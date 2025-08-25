locals {
  name           = "ng-${var.base_name}-${var.environment}-${var.location}"
  ip_prefix_name = "ippre-${var.base_name}-${var.environment}-${var.location}"
}

resource "azurerm_nat_gateway" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_public_ip_prefix" "this" {
  name                = local.ip_prefix_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}


resource "azurerm_nat_gateway_public_ip_prefix_association" "this" {
  nat_gateway_id      = azurerm_nat_gateway.this.id
  public_ip_prefix_id = azurerm_public_ip_prefix.this.id

  depends_on = [azurerm_nat_gateway.this, azurerm_public_ip_prefix.this]
}