#================================================================================
# AI Foundry — WORKLOAD stack.
#
# This stack owns the Foundry account + project + BYO stateful stack
# (Storage, Cosmos DB, AI Search) and their private endpoints. Each of
# the four data-plane services (Foundry / Cognitive, Storage, Cosmos, AI
# Search) is deployed with:
#
#   - A private endpoint in its dedicated PE subnet (VNet-injected agent
#     runtime reaches services via the PE).
#   - `public_network_access_enabled = true` with `default_action = Deny`
#     and the deploying user's public IP pinned into the firewall
#     allowlist. This lets Terraform's data-plane calls during apply
#     (Foundry project connections, capability-host provisioning) reach
#     the services from your laptop while still blocking every other
#     public IP.
#
# Prereqs (owned by the base stack):
#   - Resource group
#   - VNet + 5 subnets (agent subnet delegated to
#     Microsoft.App/environments, plus cognitive/storage/cosmos/search
#     PE subnets)
#   - Private DNS zones, VNet-linked, for every service below
#
# Cross-stack coupling:
#   Workload looks up base-created Azure resources by NAME via `data`
#   sources (see section 3 below). It does NOT read base's Terraform
#   `outputs`. Base's outputs are for humans (`terraform output` after
#   base apply). This means the two stacks share only the naming
#   convention below — not each other's state files.
#
# Deploy model:
#   `terraform apply` runs from YOUR LAPTOP (`az login` first). The http
#   provider auto-detects your public egress IP and pins it into every
#   service firewall. See the ai-foundry README.
#
# RBAC prerequisite:
#   Your `az login` user must be able to create resources in this RG AND
#   grant role assignments (the foundry_project module creates Phase-3 /
#   Phase-5 assignments on the Foundry project MI). Subscription-scope
#   Owner covers this; RG-scope Owner works too if the RG already exists
#   and providers are already registered.
#
# Ref: Microsoft's Foundry Standard Agent Setup docs
#      https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup
#================================================================================

#----------------------------------------------------------------
# 1. Naming — resolves each name from a variable, falling back to the
#    base stack's convention when the variable is null.
#
# Default flow (nothing overridden):
#   base_name = "playground", environment = "dev", location = "eastus2"
#   -> VNet name, subnet names, Foundry custom subdomain all derived from
#      those three -> exact match to the base stack's outputs.
#
# Override flow: set any of `vnet_name`, `subnet_name_*`,
# `cognitive_custom_subdomain_name`, `*_private_dns_zone_name(s)` in tfvars to
# point this stack at pre-existing resources named differently (e.g.
# a shared VNet provisioned by another team).
#----------------------------------------------------------------

locals {
  base_name   = var.base_name
  environment = var.environment
  location    = var.location

  vnet_name                       = coalesce(var.vnet_name, "vnet-${local.base_name}-${local.environment}-${local.location}")
  cognitive_custom_subdomain_name = coalesce(var.cognitive_custom_subdomain_name, "cog-acc-${local.base_name}-${local.environment}-${local.location}")

  subnet_name_cognitive_pep = coalesce(var.subnet_name_cognitive_pep, "snet-cognitive-${local.base_name}-${local.environment}")
  subnet_name_storage_pep   = coalesce(var.subnet_name_storage_pep, "snet-storage-${local.base_name}-${local.environment}")
  subnet_name_cosmos_pep    = coalesce(var.subnet_name_cosmos_pep, "snet-cosmos-${local.base_name}-${local.environment}")
  subnet_name_search_pep    = coalesce(var.subnet_name_search_pep, "snet-search-${local.base_name}-${local.environment}")
  subnet_name_agent         = coalesce(var.subnet_name_agent, "snet-agent-${local.base_name}-${local.environment}")

  tags = {
    environment = local.environment
    workload    = "ai-foundry"
    stack       = "workload"
    managed_by  = "terraform"
  }

  # Zone names — used only for data lookups; the zones themselves live in
  # base. Defaults are the required Standard-Setup set for each service.
  # `coalesce` can't accept null for a list argument, so use the ternary.
  cognitive_private_dns_zones = var.cognitive_private_dns_zone_names != null ? var.cognitive_private_dns_zone_names : [
    "privatelink.cognitiveservices.azure.com",
    "privatelink.openai.azure.com",
    "privatelink.services.ai.azure.com",
  ]

  storage_private_dns_zones = var.storage_private_dns_zone_names != null ? var.storage_private_dns_zone_names : [
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.dfs.core.windows.net",
    "privatelink.web.core.windows.net",
  ]

  cosmos_private_dns_zone = coalesce(var.cosmos_private_dns_zone_name, "privatelink.documents.azure.com")
  search_private_dns_zone = coalesce(var.search_private_dns_zone_name, "privatelink.search.windows.net")

  # ------------------------------------------------------------------
  # Deployer-IP allowlist.
  #
  # `var.deployer_ip` semantics:
  #   null (default)  -> ask api.ipify.org (via `data.http.myip`) for our IP
  #   ""              -> skip: don't add any deployer IP to the allowlist
  #   "203.0.113.42"  -> use exactly this IP
  #
  # `data "http" "myip"` uses `count` so it's only queried in the auto-detect
  # case (`var.deployer_ip == null`). This keeps the stack usable when the
  # deployer's egress can't reach ipify (corporate proxy, offline lab) OR
  # when hardening (deployer_ip = "" skips the http call entirely).
  #
  # `compact()` filters empty strings out of the final list so an explicit
  # `deployer_ip = ""` produces `allowed_ips = concat([], allowed_ips_extra)`.
  # When both are empty and `enable_public_network_access = true` the
  # default-deny firewall blocks everyone -- fine for hardened-with-public-on
  # posture. When `enable_public_network_access = false`, the entire public
  # endpoint is disabled and the allowlist is moot.
  # ------------------------------------------------------------------
  deployer_ip = var.deployer_ip != null ? var.deployer_ip : chomp(data.http.myip[0].response_body)

  allowed_ips = compact(concat([local.deployer_ip], var.allowed_ips_extra))
}

data "http" "myip" {
  count = var.deployer_ip == null ? 1 : 0

  url = "https://api.ipify.org"

  # Retry — ipify occasionally hiccups; a couple of quick retries keeps
  # `terraform plan` deterministic in dev.
  retry {
    attempts     = 3
    min_delay_ms = 200
    max_delay_ms = 1000
  }
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
  name                 = local.subnet_name_cognitive_pep
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "storage_pep" {
  name                 = local.subnet_name_storage_pep
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "cosmos_pep" {
  name                 = local.subnet_name_cosmos_pep
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "search_pep" {
  name                 = local.subnet_name_search_pep
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "agent" {
  name                 = local.subnet_name_agent
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
# All three are configured here with:
#   - local (key) auth DISABLED
#   - SystemAssigned managed identity
#   - `public_network_access_enabled = true` + default-deny firewall +
#     the deployer's public IP allowlisted. This lets `terraform apply`
#     on your laptop reach the data planes for Foundry connection
#     provisioning; the agent runtime inside the VNet keeps using the
#     private endpoints.
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
  public_network_access_enabled    = var.enable_public_network_access
  network_rules_default_action     = "Deny"
  allowed_ips                      = local.allowed_ips

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

  public_network_access_enabled = var.enable_public_network_access
  ip_range_filter               = local.allowed_ips

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
  search_public_network_access_enabled = var.enable_public_network_access
  allowed_ips                          = local.allowed_ips

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
  custom_subdomain_name         = local.cognitive_custom_subdomain_name
  identity_type                 = "SystemAssigned"
  public_network_access_enabled = var.enable_public_network_access
  network_acls_default_action   = "Deny"
  network_acls_bypass           = "AzureServices"
  network_acls_ip_rules         = local.allowed_ips

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
# The foundry_project module owns the full project lifecycle. Terraform
# builds the dependency graph from `depends_on` inside the module; the
# effective ordering is:
#   1. azurerm_cognitive_account_project      — creates the project MI
#   2. Entra ID connections (storage/cosmos/search) at the account scope
#      (independent of the project — may parallelize)
#   3. Phase 3 RBAC (control plane):
#         Cosmos DB Operator          on Cosmos account
#         Storage Account Contributor on Storage account
#   4. Phase 5 RBAC (data plane):
#         Search Index Data Contributor    on AI Search
#         Search Service Contributor       on AI Search
#         Storage Blob Data Owner          on Storage account
#         Cosmos DB Built-in Data Contributor on Cosmos account
#   5. 60s time_sleep to cover RBAC propagation (best-effort)
#   6. Account + project capability hosts (Foundry Agent Service
#      Standard Setup) — gated behind the sleep and connections
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
