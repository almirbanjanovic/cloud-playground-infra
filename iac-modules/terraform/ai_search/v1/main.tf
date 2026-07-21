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

  allowed_ips = var.allowed_ips

  public_network_access_enabled = var.search_public_network_access_enabled

  local_authentication_enabled = var.local_authentication_enabled

  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "SystemAssigned" ? null : var.identity_ids
  }

  tags = var.tags
}

#--------------------------------------------------------------------------------------------------------------------------------
# Role Assignments (managed identity access)
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = azurerm_search_service.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}

module "search_private_endpoint" {
  source = "../../private_endpoint/v1"

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