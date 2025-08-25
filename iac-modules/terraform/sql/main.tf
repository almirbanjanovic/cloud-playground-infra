#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {
  db_server_name = "sql-${var.base_name}-${var.environment}-${var.location}${var.suffix != "" ? "-${var.suffix}" : ""}"
  db_name        = var.sql_db_name_for_migration != "" ? var.sql_db_name_for_migration : "sqldb-${var.base_name}-${var.environment}-${var.location}${var.suffix != "" ? "-${var.suffix}" : ""}"
}

resource "azurerm_mssql_server" "this" {
  name                = local.db_server_name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.sql_server_version
  minimum_tls_version = var.sql_server_minimum_tls_version

  administrator_login          = var.tenant_sql_username
  administrator_login_password = var.tenant_sql_password

  azuread_administrator {
    login_username = var.admin_group_name
    object_id      = var.admin_group_object_id
  }

  tags = var.tags
}

resource "azurerm_mssql_firewall_rule" "this" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "this" {
  name      = local.db_name
  server_id = azurerm_mssql_server.this.id

  maintenance_configuration_name = var.sql_db_maintenance_configuration_name

  # The sku_name can be obtained by runnign the belwo az cli command:
  # az sql db list-editions --location eastus2 -o table 
  sku_name             = var.sql_db_sku_name
  min_capacity         = var.sql_db_min_capacity
  max_size_gb          = var.sql_db_max_size_gb
  storage_account_type = var.sql_db_storage_account_type
  zone_redundant       = var.zone_redundant

  tags = var.tags
}


module "private_endpoint" {
  source = "../private_endpoint"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_mssql_server.this.id
  resource_name                   = local.db_server_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.subresource_names
  private_dns_zone_ids            = var.private_dns_zone_ids
  private_dns_a_record_name       = local.db_server_name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_mssql_server.this]
}   