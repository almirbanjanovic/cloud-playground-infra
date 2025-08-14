

#------------------------------------------------------------------------------------------------------------------------------
# Storage Account and Container for SFTP
#------------------------------------------------------------------------------------------------------------------------------

module "sftp_storage_account" {
  source                           = "../storage_account"
  base_name                        = var.base_name
  environment                      = var.environment
  location                         = var.location
  resource_group_name              = var.resource_group_name
  storage_account_tier             = var.storage_account_tier
  storage_account_replication_type = var.storage_account_replication_type
  min_tls_version                  = var.storage_account_min_tls_version
  enable_https_traffic_only        = var.storage_account_enable_https_traffic_only
  allowed_ips                      = var.allowed_ips

  subnet_id                  = var.storage_account_subnet_id
  blob_private_dns_zone_ids  = [var.blob_private_dns_zone_id]
  table_private_dns_zone_ids = [var.table_private_dns_zone_id]
  queue_private_dns_zone_ids = [var.queue_private_dns_zone_id]
  file_private_dns_zone_ids  = [var.file_private_dns_zone_id]
  web_private_dns_zone_ids   = [var.web_private_dns_zone_id]
  dfs_private_dns_zone_ids   = [var.dfs_private_dns_zone_id]

  suffix             = "sftp"
  sftp_enabled       = true
  is_hns_enabled     = true
  versioning_enabled = false # SFTP does not support versioning

  prevent_destroy = true

  tags = var.tags
}

resource "azurerm_storage_container" "sftp" {
  name               = var.sftp_storage_container_name
  storage_account_id = module.sftp_storage_account.id

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    module.sftp_storage_account
  ]
}

resource "azurerm_storage_account_local_user" "this" {
  name                 = var.sftp_local_user_name
  storage_account_id   = module.sftp_storage_account.id
  ssh_password_enabled = true

  permission_scope {
    resource_name = azurerm_storage_container.sftp.name
    service       = "blob"
    permissions {
      create = true
      delete = true
      list   = true
      read   = true
      write  = true
    }
  }
}

module "sftp_secrets" {
  source = "../key_vault_secrets"

  key_vault_id = var.key_vault_id

  secrets = {
    "SftpPassword" = azurerm_storage_account_local_user.this.password
  }

  depends_on = [
    module.sftp_storage_account,
    azurerm_storage_container.sftp,
    azurerm_storage_account_local_user.this
  ]
}