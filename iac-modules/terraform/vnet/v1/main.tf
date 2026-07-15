#----------------------------------------------------------------
# Virtual Network — just the VNet. Subnets are a separate concern
# and belong to the caller (see iac-modules/terraform/subnet/v1).
#----------------------------------------------------------------

locals {
  vnet_name = "vnet-${var.base_name}-${var.environment}-${var.location}"
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}
