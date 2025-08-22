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

resource "azurerm_api_management_api" "calculator" {
  name                = "calculator-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Calculator API"
  protocols           = ["http"]
  service_url = "http://calcapi.cloudapp.net/calcapi.json"
  import {
    content_format = "swagger-link-json"
    content_value  = "https://raw.githubusercontent.com/Azure/api-management-samples/refs/heads/master/apis/calculator.swagger.json"
  }
}