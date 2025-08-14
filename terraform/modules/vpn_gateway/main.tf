locals {
  name        = "vpng-${var.base_name}-${var.environment}-${var.location}"
  subnet_name = "GatewaySubnet"
  pip_name    = "pip-${local.name}"
}

resource "azurerm_public_ip" "this" {
  name                = local.pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.pip_allocation_method
  sku                 = var.pip_sku

  zones = ["1", "2", "3"]

  tags = var.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = var.gateway_type
  vpn_type            = var.vpn_type
  sku                 = var.sku
  enable_bgp          = var.enable_bgp
  active_active       = var.active_active

  ip_configuration {
    name                          = "ipconfig-${azurerm_public_ip.this.name}"
    public_ip_address_id          = azurerm_public_ip.this.id
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
  }

  vpn_client_configuration {
    address_space        = [var.vpn_client_address_space]
    vpn_auth_types       = var.vpn_auth_types
    vpn_client_protocols = var.vpn_client_protocols

    aad_tenant   = var.aad_tenant
    aad_issuer   = var.aad_issuer
    aad_audience = var.aad_audience
  }

  tags = var.tags
}