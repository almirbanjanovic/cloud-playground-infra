#--------------------------------------------------------------------------------------------------------------------------------
# General Configuration
#--------------------------------------------------------------------------------------------------------------------------------
locals {
  name = "cosmos-${var.base_name}-${var.environment}-${var.location}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# Cosmos DB Account (SQL API by default)
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = var.offer_type
  kind                = var.kind

  minimal_tls_version           = var.minimal_tls_version
  automatic_failover_enabled    = var.automatic_failover_enabled
  public_network_access_enabled = var.public_network_access_enabled
  ip_range_filter               = var.ip_range_filter
  # local_authentication_enabled is only valid for the SQL API (GlobalDocumentDB).
  local_authentication_enabled = var.kind == "GlobalDocumentDB" ? var.local_authentication_enabled : null
  free_tier_enabled            = var.free_tier_enabled

  consistency_policy {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.max_interval_in_seconds
    max_staleness_prefix    = var.max_staleness_prefix
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = var.zone_redundant
  }

  dynamic "capabilities" {
    for_each = toset(var.capabilities)
    content {
      name = capabilities.value
    }
  }

  identity {
    type = var.identity_type
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length(local.name) >= 3 && length(local.name) <= 44 && can(regex("^[a-z0-9-]+$", local.name))
      error_message = "Cosmos DB account name must be 3-44 characters and contain only lowercase letters, numbers, and hyphens. Got: ${local.name}"
    }
  }
}

#--------------------------------------------------------------------------------------------------------------------------------
# Role Assignments (managed identity access)
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = azurerm_cosmosdb_account.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}

resource "azurerm_cosmosdb_sql_role_assignment" "this" {
  for_each            = var.sql_role_assignments
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  role_definition_id  = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/${each.value.role_definition_id}"
  principal_id        = each.value.principal_id
  scope               = "${azurerm_cosmosdb_account.this.id}${each.value.scope_suffix}"
}

#--------------------------------------------------------------------------------------------------------------------------------
# Private Endpoint
#--------------------------------------------------------------------------------------------------------------------------------
module "cosmos_private_endpoint" {
  source = "../../private_endpoint/v1"

  base_name   = var.base_name
  environment = var.environment

  resource_id                     = azurerm_cosmosdb_account.this.id
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
