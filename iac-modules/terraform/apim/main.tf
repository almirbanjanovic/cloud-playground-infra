resource "azurerm_api_management" "api" {
  name                = "apiservice${random_string.azurerm_api_management_name.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = "${var.sku_name}_${var.sku_count}"
}