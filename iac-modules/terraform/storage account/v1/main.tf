#----------------------------------------------------------------
# General configuration
#----------------------------------------------------------------
locals {
  name = "st${var.base_name}${var.environment}${var.location}${var.suffix != "" ? "${var.suffix}" : ""}"
}

resource "azurerm_storage_account" "this" {
  name                             = local.name
  resource_group_name              = var.resource_group_name
  location                         = var.location
  account_tier                     = var.storage_account_tier
  account_replication_type         = var.storage_account_replication_type
  min_tls_version                  = var.min_tls_version
  https_traffic_only_enabled       = var.enable_https_traffic_only
  allow_nested_items_to_be_public  = var.allow_nested_items_to_be_public
  cross_tenant_replication_enabled = var.cross_tenant_replication_enabled
  public_network_access_enabled    = var.public_network_access_enabled

  shared_access_key_enabled       = var.shared_access_key_enabled
  default_to_oauth_authentication = var.default_to_oauth_authentication

  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "SystemAssigned" ? null : var.identity_ids
  }

  blob_properties {
    delete_retention_policy {
      days = 30 # Retain deleted blobs for 30 days
    }

    container_delete_retention_policy {
      days = 30 # Retain deleted containers for 30 days
    }

    last_access_time_enabled = true                   # Enable last access time tracking
    versioning_enabled       = var.versioning_enabled # Enable versioning for additional protection
  }

  network_rules {
    bypass         = ["AzureServices"]
    default_action = var.network_rules_default_action
    ip_rules       = var.allowed_ips
  }

  routing {
    publish_microsoft_endpoints = var.publish_microsoft_endpoint
  }

  is_hns_enabled = var.is_hns_enabled
  sftp_enabled   = var.sftp_enabled

  tags = var.tags
}

#----------------------------------------------------------------
# Role Assignments (managed identity access)
#----------------------------------------------------------------
resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = azurerm_storage_account.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}

#----------------------------------------------------------------
# Private Endpoint configuration
#----------------------------------------------------------------
module "blob_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_storage_account.this.id
  resource_name                   = "${local.name}-blob"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.blob_subresource_names
  private_dns_zone_ids            = var.blob_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_storage_account.this]
}

module "table_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_storage_account.this.id
  resource_name                   = "${local.name}-table"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.table_subresource_names
  private_dns_zone_ids            = var.table_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_storage_account.this]
}

module "queue_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_storage_account.this.id
  resource_name                   = "${local.name}-queue"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.queue_subresource_names
  private_dns_zone_ids            = var.queue_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_storage_account.this]
}

module "file_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_storage_account.this.id
  resource_name                   = "${local.name}-file"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.file_subresource_names
  private_dns_zone_ids            = var.file_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_storage_account.this]
}

module "azure_data_lake_file_system_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_storage_account.this.id
  resource_name                   = "${local.name}-dfs"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.dfs_subresource_names
  private_dns_zone_ids            = var.dfs_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_storage_account.this]
}

module "web_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_storage_account.this.id
  resource_name                   = "${local.name}-web"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  subnet_id                       = var.subnet_id
  subresource_names               = var.web_subresource_names
  private_dns_zone_ids            = var.web_private_dns_zone_ids
  private_dns_a_record_name       = local.name
  private_dns_resource_group_name = var.resource_group_name

  tags = var.tags

  depends_on = [azurerm_storage_account.this]
}