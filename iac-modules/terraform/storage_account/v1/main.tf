#----------------------------------------------------------------
# General configuration
#
# `local.name` is the effective storage account name. When `var.custom_name`
# is set, it wins outright -- callers that need a bespoke name (e.g. the
# terraform-state storage account in the ai-foundry base stack) pass one in
# rather than trying to squeeze it out of the `${base}${env}${loc}${suffix}`
# convention. When `var.custom_name` is empty, we derive from the standard
# inputs. Hyphens in the inputs (e.g. base_name="ai-foundry") are stripped --
# Storage rejects any non-alphanumeric character, and hyphens are the only
# invalid char that the rest of our naming convention actually uses. Anything
# more exotic: pass `custom_name`.
#----------------------------------------------------------------
locals {
  derived_name = replace(lower("st${var.base_name}${var.environment}${var.location}${var.suffix != "" ? "${var.suffix}" : ""}"), "-", "")
  name         = var.custom_name != "" ? var.custom_name : local.derived_name
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

  # Azure storage account names must be 3-24 chars, lowercase letters +
  # numbers only. `local.name` concatenates base_name/environment/location
  # (plus optional suffix) so misconfigured inputs (long names, uppercase,
  # hyphens) fail fast at plan time instead of during the ARM call.
  lifecycle {
    precondition {
      condition     = length(local.name) >= 3 && length(local.name) <= 24 && can(regex("^[a-z0-9]+$", local.name))
      error_message = "Storage account name must be 3-24 lowercase alphanumeric characters. Computed: '${local.name}' (length ${length(local.name)}). Shorten base_name/environment/location or set `suffix = \"\"`."
    }
  }
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
#
# Each PE module is `count`-guarded on its corresponding DNS zone list.
# Passing an empty list (e.g. `queue_private_dns_zone_ids = []`) skips
# that PE entirely -- matches the conditional Bicep peer at
# iac-modules/bicep/storage_account/v1/storage_account.bicep and lets
# callers who only need a subset of PEs (e.g. the tfstate storage account
# in ai-foundry base only needs blob) avoid provisioning the other 5.
#
# The 6 PEs are SERIALISED via a `depends_on` chain
# (blob -> table -> queue -> file -> dfs -> web) rather than the
# Terraform default of parallel siblings. Rationale:
#
#   * All 6 PEs target the SAME PE subnet, so each PE's NIC creation
#     writes to `subnet.properties.ipConfigurations` under Network
#     RP's per-subnet write lock.
#   * All 6 PEs target the SAME storage account, so each PE's
#     `privateLinkServiceConnections` write hits Storage RP's per-
#     account write lock.
#
# Two shared write-locks + 6 concurrent writers is the same class of
# race that produces `RetryableError` / `AnotherOperationInProgress`
# / `409 Conflict` on the first apply -- exactly the pattern we
# serialised for subnets in iac-modules/bicep/vnet/v1/vnet.bicep via
# `@batchSize(1)`. In Terraform we chain the module `depends_on` in a
# fixed order; the chain skips the disabled PEs correctly because
# `depends_on` on an empty (count=0) module is a no-op.
#
# Cost: ~5-10s added to first apply. Benefit: deterministic first-run
# success on the storage private-endpoint fan-out.
#----------------------------------------------------------------
module "blob_private_endpoint" {
  count  = length(var.blob_private_dns_zone_ids) > 0 ? 1 : 0
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
  count  = length(var.table_private_dns_zone_ids) > 0 ? 1 : 0
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

  depends_on = [
    azurerm_storage_account.this,
    module.blob_private_endpoint,
  ]
}

module "queue_private_endpoint" {
  count  = length(var.queue_private_dns_zone_ids) > 0 ? 1 : 0
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

  depends_on = [
    azurerm_storage_account.this,
    module.table_private_endpoint,
  ]
}

module "file_private_endpoint" {
  count  = length(var.file_private_dns_zone_ids) > 0 ? 1 : 0
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

  depends_on = [
    azurerm_storage_account.this,
    module.queue_private_endpoint,
  ]
}

module "azure_data_lake_file_system_private_endpoint" {
  count  = length(var.dfs_private_dns_zone_ids) > 0 ? 1 : 0
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

  depends_on = [
    azurerm_storage_account.this,
    module.file_private_endpoint,
  ]
}

module "web_private_endpoint" {
  count  = length(var.web_private_dns_zone_ids) > 0 ? 1 : 0
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

  depends_on = [
    azurerm_storage_account.this,
    module.azure_data_lake_file_system_private_endpoint,
  ]
}