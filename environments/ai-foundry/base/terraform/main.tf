#================================================================================
# AI Foundry — BASE stack.
#
# This stack owns the shared infrastructure that has to exist BEFORE the
# private workload (Foundry + BYO services) can be deployed:
#
#   1. VNet + all subnets (including the agent subnet delegated to
#      Microsoft.App/environments — required by Foundry Agent Service).
#   2. Private DNS zones for every service the workload stack will
#      privatelink to (Foundry / Cognitive, Storage subresources, Cosmos,
#      Search) — with VNet links, so any VM in this VNet resolves those
#      services to their private-endpoint IPs.
#   3. NAT Gateway attached to the CI/CD and jumpbox subnets, so outbound
#      Internet works even when public IPs are absent / restricted.
#   4. Jumpbox VM — operator entry point for validating private
#      connectivity end-to-end.
#   5. CI/CD self-hosted GitHub Actions runner — the ONLY runner able to
#      reach the workload stack's services (which will have
#      `public_network_access_enabled = false`).
#   6. UAMI + federated identity credential + RBAC so the runner UAMI can
#      terraform-apply the workload stack via GitHub Actions OIDC.
#
# Why split from workload:
#   Workload data-plane operations (Cosmos SQL role assignments, Foundry
#   capability hosts, Storage container access) require reaching resources
#   with public network access disabled — which a GitHub-hosted runner
#   cannot do. This stack provisions the private runner so those workload
#   applies can run from inside the VNet.
#
# Where this stack runs from:
#   `ubuntu-latest` (GitHub-hosted). It has to — the private runner
#   doesn't exist yet on the first apply.
#================================================================================

#----------------------------------------------------------------
# 1. Locals — names, address prefixes, DNS zone list
#----------------------------------------------------------------

locals {
  base_name   = "playground"
  environment = "dev"
  location    = "centralus"

  vnet_name = "vnet-${local.base_name}-${local.environment}-${local.location}"

  # Same 10.0.0.0/16 space the workload stack uses. Class A is required
  # by Foundry Agent Service in centralus per
  # https://learn.microsoft.com/azure/foundry/agents/concepts/limits-quotas-regions#supported-regions
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
# Seven subnets:
#   - Four PE subnets (one per privatelinked service in workload).
#   - agent — delegated to Microsoft.App/environments for Foundry Agent
#     Service network injection.
#   - cicd — hosts the self-hosted GitHub Actions runner.
#   - jumpbox — hosts the operator jumpbox VM.
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
    cicd = {
      name             = "snet-cicd-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.20.0/24"]
    }
    jumpbox = {
      name             = "snet-jumpbox-${local.base_name}-${local.environment}"
      address_prefixes = ["10.0.21.0/24"]
    }
  }
}

#----------------------------------------------------------------
# 3. NAT Gateway — outbound Internet for cicd + jumpbox subnets
#
# Runner needs github.com / ghcr.io / packages / Azure ARM. Jumpbox
# needs apt updates and az CLI. Neither should rely on their public IP
# for outbound (jumpbox's PIP is inbound-only per NSG; runner has none).
#----------------------------------------------------------------

module "nat_gateway" {
  source = "../../../../iac-modules/terraform/nat_gateway/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_subnet_nat_gateway_association" "cicd" {
  subnet_id      = module.subnets.subnet_ids["cicd"]
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "jumpbox" {
  subnet_id      = module.subnets.subnet_ids["jumpbox"]
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

#----------------------------------------------------------------
# 4. Private DNS zones — VNet-linked so any resource in this VNet
#    (runner, jumpbox, agent runtime) resolves privatelink hosts to
#    their private-endpoint IPs.
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
# 5. Jumpbox — operator entry point.
#
# Public IP + SSH allowlist restricted to `var.allowed_ssh_source_prefixes`.
# Entra ID SSH login enabled so operators use `az ssh vm` with their AAD
# identity — no local SSH key management on the operator side.
#----------------------------------------------------------------

module "jumpbox" {
  source = "../../../../iac-modules/terraform/jumpbox/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  subnet_id            = module.subnets.subnet_ids["jumpbox"]
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key

  enable_public_ip           = true
  allowed_source_ip_prefixes = var.allowed_ssh_source_prefixes

  enable_entra_ssh_login = true
  entra_admin_object_ids = var.jumpbox_entra_admin_object_ids
}

#----------------------------------------------------------------
# 6. CI/CD runner — self-hosted GitHub Actions runner.
#
# Cloud-init installs Azure CLI, Terraform, tflint, and registers the
# runner against `${github_org}/${github_repo}` using the PAT to mint a
# fresh registration token at boot.
#----------------------------------------------------------------

module "cicd_runner" {
  source = "../../../../iac-modules/terraform/cicd_runner/v1"

  base_name           = local.base_name
  environment         = local.environment
  location            = local.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  subnet_id            = module.subnets.subnet_ids["cicd"]
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key

  github_org  = var.github_org
  github_repo = var.github_repo
  github_pat  = var.github_pat

  runner_labels = ["self-hosted", "linux", "ai-foundry"]
}

#----------------------------------------------------------------
# 7. Federated identity credential on the runner UAMI + RBAC.
#
# Trust GitHub Actions OIDC for the `ai-foundry-workload` GitHub
# environment on this repo. The workflow deploying workload authenticates
# to Azure via `azure/login@v2 (client-id = runner UAMI client ID)`.
#
# Role: Owner on the resource group so the workload apply can
#   (a) create resources and (b) create role assignments needed by
#   the Foundry project setup (phase 3 + phase 5 RBAC — see
#   iac-modules/terraform/foundry_project/v1/main.tf).
#----------------------------------------------------------------

resource "azurerm_federated_identity_credential" "runner_workload" {
  name                = "github-actions-${var.github_org}-${var.github_repo}-workload"
  resource_group_name = var.resource_group_name
  parent_id           = module.cicd_runner.user_assigned_identity_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:environment:${var.workload_github_environment}"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "runner_rg_owner" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Owner"
  principal_id         = module.cicd_runner.user_assigned_principal_id
}

# ------------------------------------------------------------------------------
# Storage Blob Data Contributor on the RG for the runner UAMI.
#
# `Owner` above grants ARM control-plane perms but NOT data-plane blob access.
# Terraform's azurerm backend runs with `ARM_USE_AZUREAD=true`, which
# authenticates to blob storage via Entra ID and requires a data-plane role
# on the state storage account. Granting at RG scope covers the state SA
# (created by terraform-init-backend.yaml in the same RG) plus any workload
# storage accounts the runner needs to reach.
#
# Ref: https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "runner_rg_blob_data_contributor" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.cicd_runner.user_assigned_principal_id
}
