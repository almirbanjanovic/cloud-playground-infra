module "apim" {
  source              = "../../iac-modules/terraform/apim"
  base_name           = "mcp"
  environment         = "dev"
  location            = "centralus"
  resource_group_name = var.resource_group_name
  publisher_email     = "mcp@contoso.io"
  publisher_name      = "mcp"
  sku_name            = "BasicV2"
  sku_count           = 1
}