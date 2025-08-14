#----------------------------------------------------------------
# General configuration
#----------------------------------------------------------------
locals {
  name                                         = "st${var.base_name}${var.environment}${var.location}${var.suffix != "" ? "${var.suffix}" : ""}"
  block_blob_lifecycle_management_policy_name  = "block-blob-smp-rule-${azurerm_storage_account.this.name}"
  append_blob_lifecycle_management_policy_name = "append-blob-smp-rule-${azurerm_storage_account.this.name}"
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

resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = local.block_blob_lifecycle_management_policy_name
    enabled = true

    filters {
      blob_types = ["blockBlob"] # Apply to all block blobs in all containers
    }

    actions {
      base_blob {
        # Transition from Hot to Cool after 30 days
        tier_to_cool_after_days_since_modification_greater_than = 90

        # Transition from Cool to Cold after 1 year
        tier_to_cold_after_days_since_last_access_time_greater_than = 356

        # Delete after 7 years (HIPAA minimum + safety margin)
        delete_after_days_since_modification_greater_than = 2555
      }

      version {
        # Transition from Hot to Cool after 30 days
        change_tier_to_cool_after_days_since_creation = 90

        # Transition from Cool to Cold after 1 year
        tier_to_cold_after_days_since_creation_greater_than = 356

        # Delete after 7 years (HIPAA minimum + safety margin)
        delete_after_days_since_creation = 2555
      }
    }
  }

  rule {
    name    = local.append_blob_lifecycle_management_policy_name
    enabled = true

    filters {
      blob_types = ["appendBlob"] # Apply to all block blobs in all containers
    }

    actions {
      base_blob {
        # Delete after 7 years (HIPAA minimum + safety margin)
        delete_after_days_since_modification_greater_than = 2555
      }

      version {
        # Delete after 7 years (HIPAA minimum + safety margin)
        delete_after_days_since_creation = 2555
      }
    }
  }
}

#----------------------------------------------------------------
# Private Endpoint configuration
#----------------------------------------------------------------
module "blob_private_endpoint" {
  source = "../private_endpoint"

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
  source = "../private_endpoint"

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
  source = "../private_endpoint"

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
  source = "../private_endpoint"

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
  source = "../private_endpoint"

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
  source = "../private_endpoint"

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