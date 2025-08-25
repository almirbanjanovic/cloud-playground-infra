#--------------------------------------------------------------------------------------------------------------------------------
# General configuration
#--------------------------------------------------------------------------------------------------------------------------------
locals {
  name     = "acr${var.base_name}${var.environment}${var.location}"
  pep_name = "pep-${local.name}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# Azure Container Registry
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_container_registry" "this" {
  name                    = local.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku                     = var.sku
  zone_redundancy_enabled = var.zone_redundancy_enabled
  admin_enabled           = var.admin_enabled
  data_endpoint_enabled   = true

  network_rule_set {
    default_action = "Deny"

    #ip_rule {
    #  action = "Allow"
    #  ip_range = var.allowed_ips[0]
    #}       
  }

  tags = var.tags
}

module "private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_container_registry.this.id
  resource_name                   = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = [var.private_dns_zone_id, var.data_private_dns_zone_id]
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_container_registry.this]
}

resource "azurerm_private_dns_a_record" "this" {
  name                = local.name
  resource_group_name = var.resource_group_name
  zone_name           = var.data_private_dns_zone_name
  ttl                 = 300
  records             = [module.private_endpoint.acr_data_ip_address]
}