resource "azurerm_api_management" "this" {
  name                = "apim-lab-dev-centralus-01"
  location            = "centralus"
  resource_group_name = var.resource_group_name
  publisher_name      = "MS"
  publisher_email     = "company@terraform.io"

  sku_name = "StandardV2_1"
}

# resource "azurerm_api_management_workspace" "this" {
#   name              = "workspace-1"
#   api_management_id = azurerm_api_management.this.id
#   display_name      = "workspace-1"
# }

resource "azurerm_api_management_api" "colors" {
  name                = "colors-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Colors API"
  protocols           = ["https"]
  service_url = "https://colors-api.azurewebsites.net/"
  import {
    content_format = "openapi+json-link"
    content_value  = "https://colors-api.azurewebsites.net/swagger/v1/swagger.json"
  }
}

resource "azurerm_api_management_api" "petstore" {
  name                = "petstore-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Petstore API"
  protocols           = ["https"]
  service_url = "http://petstore.swagger.io/v2"
  import {
    content_format = "openapi+json-link"
    content_value  = "https://petstore3.swagger.io/api/v3/openapi.json"
  }
}