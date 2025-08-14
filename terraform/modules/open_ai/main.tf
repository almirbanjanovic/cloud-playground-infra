#--------------------------------------------------------------------------------------------------------------------------------
# General Configuration
#--------------------------------------------------------------------------------------------------------------------------------
locals {
  name         = "oai-${var.base_name}-${var.environment}-${var.location}"
  account_name = "ais-${var.base_name}-${var.environment}-${var.location}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# Open AI
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_cognitive_account" "this" {
  name                          = local.account_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "OpenAI"
  sku_name                      = var.sku_name # S0
  public_network_access_enabled = false
  custom_subdomain_name         = local.name
  tags                          = var.tags
}

module "open_ai_private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_cognitive_account.this.id
  resource_name                   = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = var.private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags
}


#--------------------------------------------------------------------------------------------------------------------------------
# Model Deployments
#--------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_cognitive_deployment" "this" {
  name                 = local.name
  cognitive_account_id = azurerm_cognitive_account.this.id
  model {
    format  = "OpenAI"
    name    = var.open_ai_deployment_name
    version = var.open_ai_deployment_version
  }

  sku {
    name     = var.open_ai_deployment_sku_name
    capacity = var.open_ai_deployment_capacity
  }
}
