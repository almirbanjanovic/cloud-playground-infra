#================================================================================
# AI Foundry — WORKLOAD stack.
#
# This stack owns the Foundry account + project + BYO stateful stack
# (Storage, Cosmos DB, AI Search) and their private endpoints. The four
# data-plane services (Foundry / Cognitive, Storage, Cosmos, AI Search)
# all set `public_network_access_enabled = false` and can ONLY be reached
# from inside the VNet — which is why this stack MUST be deployed via the
# self-hosted GitHub Actions runner created by the `base` stack (or from
# the jumpbox for hand-testing). Non-data-plane resources (RBAC
# assignments, connections, capability hosts) live in ARM control plane
# and don't have that setting; they're reachable from any authenticated
# principal, but their creation depends on the private services above.
#
# Prereqs (owned by the base stack):
#   - Resource group (created by terraform-init-backend.yaml)
#   - VNet + all 7 subnets (including agent subnet delegated to
#     Microsoft.App/environments, plus cognitive/storage/cosmos/search
#     PE subnets)
#   - Private DNS zones, VNet-linked, for every service below
#   - Jumpbox + CI/CD runner (bare VM — CI workflows authenticate as the
#     App Registration federated to the shared `ai-foundry` GitHub
#     environment; the runner VM only provides a network path into the VNet)
#
# Cross-stack coupling:
#   Workload looks up base-created Azure resources by NAME via `data`
#   sources (see section 2 below). It does NOT read base's Terraform
#   `outputs`. Base's outputs are for humans (`terraform output` after
#   base apply). This means the two stacks share only the naming convention
#   below — not each other's state files.
#
# RBAC prerequisite:
#   The deploying principal must be able to create the resources in this
#   RG AND grant role assignments (the foundry_project module creates
#   Phase-3 / Phase-5 assignments on the Foundry project MI). The README
#   documents granting the App Registration subscription-scope Owner +
#   Storage Blob Data Contributor, which covers this stack, the state
#   backend, and RP registration. A narrower RG-scope Owner would work for
#   this stack alone, but only if providers are already registered and the
#   state backend is separately reachable.
#
# Ref: Microsoft's Foundry Standard Agent Setup docs
#      https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup
#================================================================================

#----------------------------------------------------------------
# 1. Naming — MUST match the base stack's locals exactly.
#
# Base and workload use identical values for base_name / environment /
# location so both stacks derive the same VNet / subnet / DNS zone names.
# If you change these values, change them in both places.
#----------------------------------------------------------------

locals {
  base_name   = "playground"
  environment = "dev"
  location    = "centralus"

  vnet_name              = "vnet-${local.base_name}-${local.environment}-${local.location}"
  cognitive_account_name = "cog-acc-${local.base_name}-${local.environment}-${local.location}"

  tags = {
    environment = local.environment
    workload    = "ai-foundry"
    stack       = "workload"
    managed_by  = "terraform"
  }

  # Zone names — used only for lookups; the zones themselves live in base.
  cognitive_private_dns_zones = [
    "privatelink.cognitiveservices.azure.com",
    "privatelink.openai.azure.com",
    "privatelink.services.ai.azure.com",
  ]

  storage_private_dns_zones = [
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.dfs.core.windows.net",
    "privatelink.web.core.windows.net",
  ]

  cosmos_private_dns_zone = "privatelink.documents.azure.com"
  search_private_dns_zone = "privatelink.search.windows.net"
}

#----------------------------------------------------------------
# 2. Data sources — everything the base stack created.
#
# All lookups are by NAME in the shared RG using azurerm data sources.
# No `terraform_remote_state` and no reads of base's Terraform outputs,
# so the two stacks aren't coupled through state files.
#----------------------------------------------------------------

data "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "cognitive_pep" {
  name                 = "snet-cognitive-${local.base_name}-${local.environment}"
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "storage_pep" {
  name                 = "snet-storage-${local.base_name}-${local.environment}"
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "cosmos_pep" {
  name                 = "snet-cosmos-${local.base_name}-${local.environment}"
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "search_pep" {
  name                 = "snet-search-${local.base_name}-${local.environment}"
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "agent" {
  name                 = "snet-agent-${local.base_name}-${local.environment}"
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_private_dns_zone" "cognitive" {
  for_each            = toset(local.cognitive_private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "storage" {
  for_each            = toset(local.storage_private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "cosmos" {
  name                = local.cosmos_private_dns_zone
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "search" {
  name                = local.search_private_dns_zone
  resource_group_name = var.resource_group_name
}

#----------------------------------------------------------------
# 3. Data plane — Storage, Cosmos DB, AI Search
#
# All three modules default to:
#   - local (key) auth DISABLED
#   - public network access DISABLED (private endpoints only)
#   - SystemAssigned managed identity
# so the only way in from Foundry is the Entra ID / MI + private endpoint
# path.
#----------------------------------------------------------------

module "storage" {
  source = "../../../../iac-modules/terraform/storage account/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  storage_account_tier             = "Standard"
  storage_account_replication_type = "LRS"
  min_tls_version                  = "TLS1_2"
  enable_https_traffic_only        = true
  public_network_access_enabled    = false
  network_rules_default_action     = "Deny"
  allowed_ips                      = []

  subnet_id = data.azurerm_subnet.storage_pep.id

  # The module wires six private endpoints (blob/file/queue/table/dfs/web),
  # so we need to hand back the DNS zone for each one.
  blob_private_dns_zone_ids  = [data.azurerm_private_dns_zone.storage["privatelink.blob.core.windows.net"].id]
  file_private_dns_zone_ids  = [data.azurerm_private_dns_zone.storage["privatelink.file.core.windows.net"].id]
  queue_private_dns_zone_ids = [data.azurerm_private_dns_zone.storage["privatelink.queue.core.windows.net"].id]
  table_private_dns_zone_ids = [data.azurerm_private_dns_zone.storage["privatelink.table.core.windows.net"].id]
  dfs_private_dns_zone_ids   = [data.azurerm_private_dns_zone.storage["privatelink.dfs.core.windows.net"].id]
  web_private_dns_zone_ids   = [data.azurerm_private_dns_zone.storage["privatelink.web.core.windows.net"].id]
}

module "cosmos_db" {
  source = "../../../../iac-modules/terraform/cosmos_db/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  subnet_id            = data.azurerm_subnet.cosmos_pep.id
  private_dns_zone_ids = [data.azurerm_private_dns_zone.cosmos.id]
  # subresource_names defaults to ["Sql"] — the correct group ID for the
  # NoSQL (SQL API) surface.
}

module "ai_search" {
  source = "../../../../iac-modules/terraform/ai_search/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  search_sku                           = "basic"
  search_public_network_access_enabled = false

  subnet_id            = data.azurerm_subnet.search_pep.id
  private_dns_zone_ids = [data.azurerm_private_dns_zone.search.id]
}

#----------------------------------------------------------------
# 4. Foundry account (Cognitive AIServices)
#----------------------------------------------------------------

module "cognitive_account" {
  source = "../../../../iac-modules/terraform/cognitive_account/v1"

  resource_group_name = var.resource_group_name
  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  kind                = "AIServices"
  sku_name            = "S0"

  # custom_subdomain_name is required for MI/Entra ID auth and for the
  # private endpoint to be attachable.
  custom_subdomain_name       = local.cognitive_account_name
  identity_type               = "SystemAssigned"
  network_acls_default_action = "Deny"
  network_acls_bypass         = "AzureServices"

  # project_management_enabled must be true for us to create
  # azurerm_cognitive_account_project resources under this account below.
  project_management_enabled = true

  subnet_id            = data.azurerm_subnet.cognitive_pep.id
  subresource_names    = ["account"]
  private_dns_zone_ids = [for z in data.azurerm_private_dns_zone.cognitive : z.id]

  # Network-inject Foundry Agent Service compute into our VNet so agent
  # runtime traffic to Storage / Cosmos / Search stays on the private plane.
  agent_subnet_id = data.azurerm_subnet.agent.id

  tags = local.tags
}

#----------------------------------------------------------------
# 5. Foundry project + capability hosts
#
# The foundry_project module owns the full project lifecycle in this
# order (all inside the module):
#   1. azurerm_cognitive_account_project      — creates the project MI
#   2. Entra ID connections (storage/cosmos/search) at the account scope
#   3. Phase 3 RBAC: Cosmos DB Operator + Storage Account Contributor
#   4. Phase 5 RBAC: Search Index/Service Data Contributor,
#      Storage Blob Data Owner, Cosmos SQL Data Contributor
#   5. 60s time_sleep to cover RBAC propagation
#   6. Account + project capability hosts (Foundry Agent Service
#      Standard Setup)
#----------------------------------------------------------------

module "foundry_project" {
  source = "../../../../iac-modules/terraform/foundry_project/v1"

  base_name   = local.base_name
  environment = local.environment
  location    = local.location
  tags        = local.tags

  cognitive_account_id = module.cognitive_account.id

  storage_account_id    = module.storage.id
  storage_blob_endpoint = "https://${module.storage.name}.blob.core.windows.net/"

  cosmos_db_account_id        = module.cosmos_db.id
  cosmos_db_document_endpoint = module.cosmos_db.endpoint

  ai_search_id       = module.ai_search.id
  ai_search_endpoint = module.ai_search.search_service_url

  # The BYO services' outputs (.id, .endpoint) become available as soon
  # as the service resource itself is created, NOT after the private
  # endpoint completes. Because the services have public network access
  # disabled, Foundry connections + capability-host provisioning can
  # only reach them via the PE. Wait for the whole service modules
  # (including their PEs) before creating the project connections.
  depends_on = [
    module.storage,
    module.cosmos_db,
    module.ai_search,
  ]
}
