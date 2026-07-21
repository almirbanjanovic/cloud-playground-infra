#================================================================================
# Foundry Project module — creates an AI Foundry Agent Service project with a
# BYO stateful stack (Storage / Cosmos DB / AI Search) and all the plumbing
# needed for it to actually work: RBAC, connections, and capability hosts.
#
# The five things this module creates, in order:
#   1. The project resource itself (gets its own system-assigned MI).
#   2. Three "connections" at the parent account scope, one per BYO service.
#      A connection is just a name → target-endpoint record with auth mode.
#      Agents reference them by name via the project capability host below.
#   3. All RBAC granted to the project's MI (details in the roster below).
#   4. A 60-second time_sleep so those RBAC assignments propagate through
#      Entra ID before ARM checks them during step 5.
#   5. Two "capability hosts" (see the explainer near that section).
#
# ─────────────────────────────────────────────────────────────────────────────
# RBAC ROSTER — every role assignment this module creates
# ─────────────────────────────────────────────────────────────────────────────
# All are granted to the PROJECT's system-assigned managed identity (the
# `principal_id` output of azurerm_cognitive_account_project). Microsoft's
# Standard Agent Setup docs split these into two phases based on when
# Foundry needs each permission. We grant BOTH before the capability host
# runs so nothing races.
#
# ── Phase 3 (control plane — Foundry needs these to CREATE the backing
#            containers and databases during capability-host provisioning):
#
#   Cosmos DB Operator          on the Cosmos account
#     → lets Foundry create the `enterprise_memory` database + its
#       containers (agent-definitions-v1, run-state-v1, etc.)
#
#   Storage Account Contributor on the Storage account
#     → lets Foundry create the two blob containers it needs:
#       <workspaceId>-agents-blobstore and <workspaceId>-azureml-blobstore
#
# ── Phase 5 (data plane — the RUNTIME roles agents use to persist state):
#
#   Search Index Data Contributor    on the AI Search service
#     → agents read/write documents in vector-store indexes
#
#   Search Service Contributor       on the AI Search service
#     → agents create new vector-store indexes on demand
#
#   Storage Blob Data Contributor   on the Storage account
#     → agents read/write files in the two auto-created containers.
#       Contributor (not Owner) is the least-privilege choice for the
#       runtime data-plane use case — Owner adds ACL / POSIX management
#       that agents don't need.
#       (Broader than the doc's per-container scoping, but the container
#       names aren't known at plan time — see comment below)
#
#   Cosmos DB Built-in Data Contributor  on the Cosmos account (SQL role)
#     → agents read/write documents in the `enterprise_memory` database
#       (this is Cosmos's own data-plane RBAC — a different resource type
#       than the standard azurerm_role_assignment)
#
# Prerequisite — the principal that RUNS terraform apply needs BOTH:
#   • roleAssignments/write (Owner, User Access Administrator, or Role
#     Based Access Administrator) to create the assignments above, AND
#   • the usual RP registration + resource-creation permissions.
# Contributor alone is NOT enough. See env providers.tf for details.
# ─────────────────────────────────────────────────────────────────────────────
#================================================================================

locals {
  project_name = "proj-${var.base_name}-${var.environment}-${var.location}"

  # Cosmos DB SQL role assignments need the RG and account name separately,
  # not the account ID. Extract them from the ARM ID (structure:
  # /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{acct}).
  cosmos_rg_name      = var.cosmos_db_account_id == null ? null : split("/", var.cosmos_db_account_id)[4]
  cosmos_account_name = var.cosmos_db_account_id == null ? null : split("/", var.cosmos_db_account_id)[8]
}

#--------------------------------------------------------------------------------------------------------------------------------
# 1. Foundry Project
#
# Lives INSIDE a Cognitive/AIServices account. The parent account must have:
#   - project_management_enabled = true
#   - kind = "AIServices"
#   - a system-assigned identity
#   - a custom_subdomain_name set
# (see the cognitive_account/v1 module — this env sets all four.)
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_cognitive_account_project" "this" {
  name                 = coalesce(var.name, local.project_name)
  cognitive_account_id = var.cognitive_account_id
  location             = var.location
  description          = var.description
  display_name         = coalesce(var.display_name, local.project_name)

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

#--------------------------------------------------------------------------------------------------------------------------------
# BYO stateful-stack connections
#
# Each connection is authored at the *account* scope (not the project). The
#--------------------------------------------------------------------------------------------------------------------------------
# 2. Connections — one per BYO service, all Entra-ID (managed-identity) auth
#
# A "connection" in Foundry is a named record on the ACCOUNT that says
# "the resource at target-URL is available for projects to consume, using
# THIS auth mode." The project capability host below picks them by name.
# Using entra_id (not account_key or api_key) means Foundry authenticates
# with the project's MI — no secrets in state.
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_cognitive_account_connection_entra_id" "storage" {
  count                = var.storage_account_id == null ? 0 : 1
  name                 = "conn-storage"
  cognitive_account_id = var.cognitive_account_id
  category             = "AzureStorageAccount"
  target               = var.storage_blob_endpoint

  metadata = {
    ApiType    = "Azure"
    ResourceId = var.storage_account_id
    Location   = var.location
  }
}

resource "azurerm_cognitive_account_connection_entra_id" "cosmos" {
  count                = var.cosmos_db_account_id == null ? 0 : 1
  name                 = "conn-cosmos"
  cognitive_account_id = var.cognitive_account_id
  category             = "CosmosDb"
  target               = var.cosmos_db_document_endpoint

  metadata = {
    ApiType    = "Azure"
    ResourceId = var.cosmos_db_account_id
    Location   = var.location
  }
}

resource "azurerm_cognitive_account_connection_entra_id" "search" {
  count                = var.ai_search_id == null ? 0 : 1
  name                 = "conn-aisearch"
  cognitive_account_id = var.cognitive_account_id
  category             = "CognitiveSearch"
  target               = var.ai_search_endpoint

  metadata = {
    ApiType    = "Azure"
    ResourceId = var.ai_search_id
    Location   = var.location
  }
}

#--------------------------------------------------------------------------------------------------------------------------------
# 3a. Phase 3 RBAC (control plane)
# See the RBAC roster at the top of this file for what each role is for.
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "project_cosmos_operator" {
  count                = var.enable_capability_host && var.cosmos_db_account_id != null ? 1 : 0
  scope                = var.cosmos_db_account_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azurerm_cognitive_account_project.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "project_storage_account_contributor" {
  count                = var.enable_capability_host && var.storage_account_id != null ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_cognitive_account_project.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

#--------------------------------------------------------------------------------------------------------------------------------
# 3b. Phase 5 RBAC (data plane)
# See the RBAC roster at the top of this file for what each role is for.
# Note the last one is a Cosmos-specific `_sql_role_assignment` resource,
# not the standard `azurerm_role_assignment` — Cosmos has its own RBAC
# system for data-plane access.
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "project_search_index_contributor" {
  count                = var.enable_capability_host && var.ai_search_id != null ? 1 : 0
  scope                = var.ai_search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_cognitive_account_project.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "project_search_service_contributor" {
  count                = var.enable_capability_host && var.ai_search_id != null ? 1 : 0
  scope                = var.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_cognitive_account_project.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "project_storage_blob_data_contributor" {
  count                = var.enable_capability_host && var.storage_account_id != null ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_cognitive_account_project.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_cosmosdb_sql_role_assignment" "project_cosmos_data_contributor" {
  count               = var.enable_capability_host && var.cosmos_db_account_id != null ? 1 : 0
  resource_group_name = local.cosmos_rg_name
  account_name        = local.cosmos_account_name
  role_definition_id  = "${var.cosmos_db_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_cognitive_account_project.this.identity[0].principal_id
  scope               = var.cosmos_db_account_id
}

#--------------------------------------------------------------------------------------------------------------------------------
# 4. RBAC propagation wait (60s)
#
# Azure RBAC assignments aren't instant — Entra ID typically takes ~30–60
# seconds to replicate a new role assignment out to the data-plane services
# that need to enforce it. Without any wait, the capability host below
# almost always fails with a 403 on first apply.
#
# 60 seconds is a best-effort gate that matches Microsoft's own
# private-networking sample and clears the common case. Under Entra ID
# load it can occasionally take longer — if the capability host still 403s,
# re-run the workflow (the sleep re-fires because triggers include the
# assignment IDs) or bump `create_duration`.
#
# Skipped entirely when the capability host is disabled (nothing to gate).
#--------------------------------------------------------------------------------------------------------------------------------
resource "time_sleep" "wait_for_rbac_propagation" {
  count           = var.enable_capability_host ? 1 : 0
  create_duration = "60s"

  triggers = {
    cosmos_operator     = try(azurerm_role_assignment.project_cosmos_operator[0].id, "")
    storage_contributor = try(azurerm_role_assignment.project_storage_account_contributor[0].id, "")
    search_index        = try(azurerm_role_assignment.project_search_index_contributor[0].id, "")
    search_service      = try(azurerm_role_assignment.project_search_service_contributor[0].id, "")
    storage_blob        = try(azurerm_role_assignment.project_storage_blob_data_contributor[0].id, "")
    cosmos_data         = try(azurerm_cosmosdb_sql_role_assignment.project_cosmos_data_contributor[0].id, "")
  }

  depends_on = [
    azurerm_role_assignment.project_cosmos_operator,
    azurerm_role_assignment.project_storage_account_contributor,
    azurerm_role_assignment.project_search_index_contributor,
    azurerm_role_assignment.project_search_service_contributor,
    azurerm_role_assignment.project_storage_blob_data_contributor,
    azurerm_cosmosdb_sql_role_assignment.project_cosmos_data_contributor,
  ]
}

#--------------------------------------------------------------------------------------------------------------------------------
# 5. Capability hosts (account + project)
#
# ── What is a "capability host"? ─────────────────────────────────────────
# A capability host is Azure Foundry's way of saying "this account /
# project participates in Agent Service, and here's the plumbing it
# should use." It's a small config record, not a compute resource.
#
# There are TWO of them, at different scopes:
#
#   Account-scoped host   (Microsoft.CognitiveServices/accounts/capabilityHosts)
#     A marker record on the parent Cognitive account. Body is essentially
#     empty — just `capabilityHostKind = "Agents"`. Its existence is what
#     lights up Agent Service for the account.
#
#   Project-scoped host   (Microsoft.CognitiveServices/accounts/projects/capabilityHosts)
#     A config record on THIS project that says: "when an agent in this
#     project needs to store a file, use the `conn-storage` connection.
#     For thread state use `conn-cosmos`. For vectors use `conn-aisearch`."
#     The three names refer to the connections created in section 2 above.
#
# ── Why do we need this? ────────────────────────────────────────────────
# Without the capability hosts, Foundry Agent Service either can't create
# agents at all (missing account host) or falls back to Microsoft-managed
# multi-tenant storage (missing project host) — which doesn't work when
# public network access is disabled on the BYO services like we've done.
# The capability host is what actually routes agent state INTO our
# Storage / Cosmos / Search accounts instead of Microsoft's shared ones.
#
# ── Why is it immutable? ─────────────────────────────────────────────────
# Foundry stores real customer data (agent threads, files, vectors) in
# the resources the capability host points at. Silently changing that
# pointer would orphan the data. So the ARM API returns 400 BadRequest on
# any UPDATE call. The `lifecycle.replace_triggered_by` block below makes
# Terraform destroy + recreate the project host when the referenced
# connections change, since update-in-place isn't allowed.
# WARNING: replacing the capability host severs the project's link to
# the BYO databases. Any agents that were writing threads / files /
# vectors will lose the reference and stop being able to reach that
# state until the new host is created. The underlying customer-owned
# data in Storage/Cosmos/Search is NOT deleted — but it becomes orphaned
# from the recreated project until you point the new host at it.
#
# ── Why azapi and not azurerm? ──────────────────────────────────────────
# The azurerm provider does not (yet) have first-class resources for
# capabilityHosts. Using the azapi provider against the raw ARM API is
# the currently-supported path. Migrate to azurerm once available.
#--------------------------------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------------------------------
resource "azapi_resource" "account_capability_host" {
  count     = var.enable_capability_host ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/capabilityHosts@2025-10-01-preview"
  parent_id = var.cognitive_account_id
  name      = "default"

  body = {
    properties = {
      capabilityHostKind = "Agents"
    }
  }
}

resource "azapi_resource" "capability_host" {
  count     = var.enable_capability_host ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-10-01-preview"
  parent_id = azurerm_cognitive_account_project.this.id
  name      = "default"

  # `capabilityHostKind` intentionally omitted: it is only present in the
  # ACCOUNT-scoped capability host schema. For the project-scoped host,
  # ARM infers the kind from the parent account, and the azapi 2.10
  # schema for this API version does not accept it here.
  body = {
    properties = {
      storageConnections       = var.storage_account_id == null ? [] : [azurerm_cognitive_account_connection_entra_id.storage[0].name]
      threadStorageConnections = var.cosmos_db_account_id == null ? [] : [azurerm_cognitive_account_connection_entra_id.cosmos[0].name]
      vectorStoreConnections   = var.ai_search_id == null ? [] : [azurerm_cognitive_account_connection_entra_id.search[0].name]
    }
  }

  depends_on = [
    azapi_resource.account_capability_host,
    time_sleep.wait_for_rbac_propagation,
    azurerm_cognitive_account_connection_entra_id.storage,
    azurerm_cognitive_account_connection_entra_id.cosmos,
    azurerm_cognitive_account_connection_entra_id.search,
  ]

  lifecycle {
    # Capability hosts are immutable; force replacement if the referenced
    # connections change.
    replace_triggered_by = [
      azurerm_cognitive_account_connection_entra_id.storage,
      azurerm_cognitive_account_connection_entra_id.cosmos,
      azurerm_cognitive_account_connection_entra_id.search,
    ]

    # Foundry Agent Service rejects a capability host with any empty
    # connection array, so require callers to provide all three BYO IDs
    # when enabling the capability host.
    precondition {
      condition = !var.enable_capability_host || (
        var.storage_account_id != null &&
        var.cosmos_db_account_id != null &&
        var.ai_search_id != null
      )
      error_message = "Foundry Agent Service capability host requires all three BYO services. Set storage_account_id, cosmos_db_account_id, and ai_search_id, or set enable_capability_host = false."
    }
  }
}
