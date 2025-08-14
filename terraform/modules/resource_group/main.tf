locals {
  name = "rg-${var.base_name}-${var.environment}-${var.location}"
}

resource "azurerm_resource_group" "this" {
  name     = local.name
  location = var.location

  tags = var.tags
}
