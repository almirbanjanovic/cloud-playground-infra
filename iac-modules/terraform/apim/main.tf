locals {
  apim_name = "apim-${var.base_name}-${var.environment}-${var.location}"
}

resource "azurerm_api_management" "this" {
  name                = local.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = "${var.sku_name}_${var.sku_count}"
}