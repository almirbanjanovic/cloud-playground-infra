locals {
  azure_monitor_private_link_scope_name = "ampls-${var.base_name}-${var.environment}-${var.location}"
}




resource "azurerm_monitor_private_link_scope" "this" {
  name                = local.azure_monitor_private_link_scope_name
  resource_group_name = var.resource_group_name

  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"

  tags = var.tags
}

module "private_endpoint_ampls" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_monitor_private_link_scope.this.id
  resource_name                   = local.azure_monitor_private_link_scope_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.ampls_subresource_names
  is_manual_connection            = false
  private_dns_zone_ids            = var.ampls_private_dns_zone_ids
  private_dns_a_record_name       = local.azure_monitor_private_link_scope_name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_monitor_private_link_scope.this]
}
