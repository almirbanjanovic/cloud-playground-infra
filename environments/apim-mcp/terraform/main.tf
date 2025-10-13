module "apim" {
  source              = "../../../iac-modules/terraform/apim"
  base_name           = "mcp"
  environment         = "dev"
  location            = "centralus"
  resource_group_name = var.resource_group_name
  publisher_email     = "mcp@contoso.io"
  publisher_name      = "mcp"
  sku_name            = "BasicV2"
  sku_count           = 1
}

resource "azurerm_api_management_api" "colors-api" {
  name                = "colors-api"
  resource_group_name = var.resource_group_name
  api_management_name = module.apim.api_management_service_name
  revision            = "1"
  display_name        = "Colors API"
  protocols           = ["https"]
  service_url = "https://colors-api.azurewebsites.net/"
  path = "colors"

  import {
    content_format = "openapi+json-link"
    content_value  = "https://colors-api.azurewebsites.net/swagger/v1/swagger.json"
  }
}