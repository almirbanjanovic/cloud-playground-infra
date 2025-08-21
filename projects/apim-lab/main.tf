resource "azurerm_api_management" "this" {
  name                = "apim-lab-dev-centralus-01"
  location            = centralus
  resource_group_name = var.resource_group_name
  publisher_name      = "MS"
  publisher_email     = "company@terraform.io"

  sku_name = "Developer_1"
}

resource "azurerm_api_management_workspace" "this" {
  name              = "workspace-1"
  api_management_id = azurerm_api_management.this.id
  display_name      = "workspace-1"
}