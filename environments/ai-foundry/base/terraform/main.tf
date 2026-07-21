#================================================================================
# AI Foundry — BASE stack.
#
# This stack owns the shared infrastructure that has to exist BEFORE the
# workload (Foundry + BYO services) can be deployed:
#
#   1. VNet + all subnets:
#        - 4 private-endpoint subnets (cognitive / storage / cosmos / search).
#        - agent subnet delegated to Microsoft.App/environments — required
#          by Foundry Agent Service network injection.
#   2. Private DNS zones for every service the workload stack privatelinks
#      to (Foundry / Cognitive, Storage subresources, Cosmos, Search) —
#      with VNet links, so any workload inside this VNet resolves those
#      services to their private-endpoint IPs.
#
# No jumpbox, no NAT gateway. Both `terraform apply` runs happen from
# your laptop: the workload stack sets `public_network_access_enabled =
# true` on every data-plane service and adds YOUR public IP to each
# service's firewall allowlist. The private endpoints created by the
# workload stack continue to serve the VNet-injected agent runtime; the
# public endpoint is only reachable from the IPs you allowlist.
#
# Deploy model:
#   Base stack:     `terraform apply` from your laptop (`az login` as a
#                   user with Owner on the target RG).
#   Workload stack: `terraform apply` from your laptop as well — the
#                   http provider auto-detects your public IP and pins
#                   it into every service firewall.
#
# See the ai-foundry README for the full walkthrough.
#================================================================================

#----------------------------------------------------------------
# 1. Locals — names, address prefixes, DNS zone list
#----------------------------------------------------------------

locals {
  base_name   = var.base_name
  environment = var.environment
  location    = var.location

  vnet_name = "vnet-${local.base_name}-${local.environment}-${local.location}"

  # 10.0.0.0/16 is a Class A range that fits comfortably in any of the
  # regions on Microsoft's Foundry Agent Service private-networking list
  # (westus3 default; see the `location` variable). Foundry accepts any
  # RFC1918 range in supported regions; Class A aligns with Microsoft's
  # Foundry Standard Setup examples and leaves plenty of room to grow.
  # https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions
  vnet_address_space = ["10.0.0.0/16"]

  tags = {
    environment = local.environment
    workload    = "ai-foundry"
    stack       = "base"
    managed_by  = "terraform"
  }

  # Private DNS zones. Kept in base so they're VNet-linked BEFORE any
  # private endpoint (created in workload) auto-registers its A record.

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
# 2. VNet + subnets
#
# Five subnets:
#   - Four PE subnets (one per privatelinked service in workload).
#   - agent — delegated to Microsoft.App/environments for Foundry
#     Agent Service network injection.
#----------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  address_space       = local.vnet_address_space
  location            = local.location
  resource_group_name = var.resource_group_name

  tags = local.tags
}

module "subnets" {
  source = "../../../../iac-modules/terraform/subnet/v1"

  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name

  subnets = {
    cognitive_pep = {
      name             = "snet-cognitive-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.1.0/24"]
    }
    storage_pep = {
      name             = "snet-storage-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.2.0/24"]
    }
    cosmos_pep = {
      name             = "snet-cosmos-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.3.0/24"]
    }
    search_pep = {
      name             = "snet-search-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.4.0/24"]
    }
    agent = {
      name             = "snet-agent-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.10.0/24"]
      delegations = [{
        name = "Microsoft.App/environments"
        service_delegation = {
          name    = "Microsoft.App/environments"
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }]
    }
  }
}

#----------------------------------------------------------------
# 3. Private DNS zones — VNet-linked so any resource in this VNet
#    (agent runtime, workload private endpoints) resolves privatelink
#    hosts to their private-endpoint IPs.
#----------------------------------------------------------------

module "cognitive_private_dns_zones" {
  for_each = toset(local.cognitive_private_dns_zones)
  source   = "../../../../iac-modules/terraform/private_dns_zone/v1"

  dns_zone             = each.value
  resource_group_name  = var.resource_group_name
  virtual_network_id   = azurerm_virtual_network.this.id
  virtual_network_name = azurerm_virtual_network.this.name

  tags = local.tags
}

module "storage_private_dns_zones" {
  for_each = toset(local.storage_private_dns_zones)
  source   = "../../../../iac-modules/terraform/private_dns_zone/v1"

  dns_zone             = each.value
  resource_group_name  = var.resource_group_name
  virtual_network_id   = azurerm_virtual_network.this.id
  virtual_network_name = azurerm_virtual_network.this.name

  tags = local.tags
}

module "cosmos_private_dns_zone" {
  source = "../../../../iac-modules/terraform/private_dns_zone/v1"

  dns_zone             = local.cosmos_private_dns_zone
  resource_group_name  = var.resource_group_name
  virtual_network_id   = azurerm_virtual_network.this.id
  virtual_network_name = azurerm_virtual_network.this.name

  tags = local.tags
}

module "search_private_dns_zone" {
  source = "../../../../iac-modules/terraform/private_dns_zone/v1"

  dns_zone             = local.search_private_dns_zone
  resource_group_name  = var.resource_group_name
  virtual_network_id   = azurerm_virtual_network.this.id
  virtual_network_name = azurerm_virtual_network.this.name

  tags = local.tags
}

#----------------------------------------------------------------
# 4. Terraform-state storage account
#
# Consumed as an zurerm backend by the WORKLOAD stack (see
# workload/terraform/providers.tf). BASE itself keeps local state --
# there's no chicken-and-egg way for BASE to remote-state into a
# storage account BASE is about to create.
#
# Deployer-IP auto-detect via ipify unless var.deployer_ip is set:
#   null (default) -> auto-detect (data.http.myip queried below)
#   ""             -> skip (no deployer IP in the allowlist)
#   "203.0.113.42" -> use exactly this IP
#
# Naming: storage account names must be globally unique + 3-24 chars
# lowercase alnum. We hash the RG+base+env+location into a 12-char
# suffix so multiple deployers of this repo don't collide.
#----------------------------------------------------------------

locals {
  deployer_ip = var.deployer_ip != null ? var.deployer_ip : chomp(data.http.myip[0].response_body)
  allowed_ips = compact(concat([local.deployer_ip], var.allowed_ips_extra))

  # Deterministic short suffix -> unique per RG. md5 collisions at 12 hex chars
  # are astronomically unlikely; drop us into the 24-char storage account limit
  # with room to spare (sttfs + 12 = 17 chars). Users can override the whole
  # name via var.tfstate_storage_account_name if they hit an unlikely global
  # storage-account name collision.
  tfstate_hash         = substr(md5("${var.resource_group_name}${local.base_name}${local.environment}${local.location}"), 0, 12)
  tfstate_storage_name = var.tfstate_storage_account_name != null ? var.tfstate_storage_account_name : "sttfs${local.tfstate_hash}"
}

data "http" "myip" {
  count = var.deployer_ip == null ? 1 : 0
  url   = "https://api.ipify.org"

  retry {
    attempts     = 3
    min_delay_ms = 200
    max_delay_ms = 1000
  }
}

module "tfstate_storage" {
  source = "../../../../iac-modules/terraform/storage_account/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  # Skip the derived name -- pass a hashed short name that fits the
  # 24-char/alnum-lowercase storage-account rules regardless of base_name.
  custom_name = local.tfstate_storage_name

  storage_account_tier             = "Standard"
  storage_account_replication_type = "LRS"
  min_tls_version                  = "TLS1_2"
  enable_https_traffic_only        = true
  public_network_access_enabled    = var.enable_public_network_access
  network_rules_default_action     = "Deny"
  allowed_ips                      = local.allowed_ips

  # Only one PE needed (blob) -- terraform state files live in blob storage.
  # The module conditionally skips the other 5 subresource PEs when the
  # corresponding DNS-zone-ID list is empty.
  subnet_id                  = module.subnets.subnet_ids["storage_pep"]
  blob_private_dns_zone_ids  = [module.storage_private_dns_zones["privatelink.blob.core.windows.net"].id]
  file_private_dns_zone_ids  = []
  queue_private_dns_zone_ids = []
  table_private_dns_zone_ids = []
  dfs_private_dns_zone_ids   = []
  web_private_dns_zone_ids   = []
}

# tfstate blob container. Requires the deployer principal to have
# "Storage Blob Data Contributor" or Owner on the account -- azurerm uses
# Entra ID / OAuth for container operations (shared-key is disabled at
# the account level).
resource "azurerm_storage_container" "tfstate" {
  name                  = var.tfstate_container_name
  storage_account_id    = module.tfstate_storage.id
  container_access_type = "private"
}
