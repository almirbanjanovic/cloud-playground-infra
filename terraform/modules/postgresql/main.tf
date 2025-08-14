#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {
  postgresql_db_server_name = "psql-${var.base_name}-${var.environment}-${var.location}${var.suffix != "" ? "-${var.suffix}" : ""}"
  postgresql_db_name        = "psqldb-${var.base_name}-${var.environment}-${var.location}${var.suffix != "" ? "-${var.suffix}" : ""}"
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = local.postgresql_db_server_name
  location            = var.location
  resource_group_name = var.resource_group_name

  version = var.postgre_sql_version

  sku_name = var.sku_name

  storage_mb            = var.storage_mb
  storage_tier          = var.storage_tier
  backup_retention_days = var.backup_retention_days

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  public_network_access_enabled = false

  tags = var.tags

  lifecycle {
    ignore_changes = [
      zone,
      high_availability.0.standby_availability_zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "this" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "citext"
}

module "private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_postgresql_flexible_server.this.id
  resource_name                   = local.postgresql_db_server_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = var.private_dns_zone_ids
  private_dns_a_record_name       = local.postgresql_db_server_name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [
    azurerm_postgresql_flexible_server.this
  ]
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = local.postgresql_db_name
  server_id = azurerm_postgresql_flexible_server.this.id
}