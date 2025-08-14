#--------------------------------------------------------------------------------------------------------------------------------
# General Configuration
#--------------------------------------------------------------------------------------------------------------------------------
locals {
  name = "srch-${var.base_name}-${var.environment}-${var.location}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# AI Search
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_search_service" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.search_sku

  network_rule_bypass_option = "AzureServices"

  allowed_ips = []

  public_network_access_enabled = var.search_public_network_access_enabled

  tags = var.tags
}

module "search_private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_search_service.this.id
  resource_name                   = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = var.private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [
    azurerm_search_service.this
  ]
}