variable "resource_group_name" {
  description = "Resource group the workload deploys into. Must match the RG used by the base stack (both stacks share it). Defaults to `rg-ai-foundry-dev-westus3`; override for a different name."
  type        = string
  default     = "rg-ai-foundry-dev-westus3"
}

# -----------------------------------------------------------------------------
# Naming inputs (defaults reproduce the base stack's convention).
#
# Every name has a null-defaulted variable + a computed fallback in main.tf's
# `locals`. Change `base_name` / `environment` / `location` here to shift the
# whole set at once, or override an individual name variable to point this
# stack at a resource that doesn't follow the convention (e.g. a shared VNet
# provisioned by another team).
# -----------------------------------------------------------------------------

variable "base_name" {
  description = "Short project identifier used as a prefix in every derived resource name (VNet, subnets, Foundry account). Must match the base stack unless the corresponding name variables are overridden individually below."
  type        = string
  default     = "ai-foundry"
}

variable "environment" {
  description = "Environment suffix used in derived resource names. Must match the base stack unless individual name variables are overridden."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for the workload resources. Must match the base stack. Default `westus3` is on Microsoft's list of Foundry Agent Service regions that support the private-networking Standard Setup, has 3 availability zones, and has broad Azure OpenAI model coverage. If you change this, change it in both stacks and verify the target region is on https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions."
  type        = string
  default     = "westus3"
}

# --- Optional overrides for individual data-source names ---

variable "vnet_name" {
  description = "Name of the pre-existing VNet created by the base stack. Leave null to use the convention `vnet-$${var.base_name}-$${var.environment}-$${var.location}`."
  type        = string
  default     = null
}

variable "subnet_name_cognitive_pep" {
  description = "Name of the subnet where the Foundry (Cognitive AIServices) private endpoint lives. Leave null to use the convention `snet-cognitive-$${var.base_name}-$${var.environment}`."
  type        = string
  default     = null
}

variable "subnet_name_storage_pep" {
  description = "Name of the subnet where the Storage account private endpoints (blob/file/queue/table/dfs/web) live. Leave null to use the convention `snet-storage-$${var.base_name}-$${var.environment}`."
  type        = string
  default     = null
}

variable "subnet_name_cosmos_pep" {
  description = "Name of the subnet where the Cosmos DB private endpoint lives. Leave null to use the convention `snet-cosmos-$${var.base_name}-$${var.environment}`."
  type        = string
  default     = null
}

variable "subnet_name_search_pep" {
  description = "Name of the subnet where the AI Search private endpoint lives. Leave null to use the convention `snet-search-$${var.base_name}-$${var.environment}`."
  type        = string
  default     = null
}

variable "subnet_name_agent" {
  description = "Name of the delegated subnet (`Microsoft.App/environments`) that Foundry Agent Service network-injects into. Leave null to use the convention `snet-agent-$${var.base_name}-$${var.environment}`."
  type        = string
  default     = null
}

variable "cognitive_custom_subdomain_name" {
  description = "The `custom_subdomain_name` (and privatelink hostname prefix) of the Foundry / Cognitive AIServices account this stack creates. This is NOT the Azure resource name — the underlying account is always named `ais-$${var.base_name}-$${var.environment}-$${var.location}` by the cognitive_account module. Leave null to use the convention `cog-acc-$${var.base_name}-$${var.environment}-$${var.location}` for the subdomain."
  type        = string
  default     = null
}

# --- Optional overrides for private DNS zone names ---
#
# Defaults match the required set for each service. Only override if you're
# consuming DNS zones with non-standard names (e.g. custom Azure clouds).

variable "cognitive_private_dns_zone_names" {
  description = "The 3 private DNS zones the Foundry account's `account` sub-resource resolves through. Leave null to use the required Standard Setup set (`privatelink.cognitiveservices.azure.com`, `privatelink.openai.azure.com`, `privatelink.services.ai.azure.com`)."
  type        = list(string)
  default     = null

  validation {
    condition     = var.cognitive_private_dns_zone_names == null || length(var.cognitive_private_dns_zone_names) == 3
    error_message = "cognitive_private_dns_zone_names must contain exactly 3 zones (cognitiveservices, openai, services.ai) or be null to use the built-in defaults."
  }
}

variable "storage_private_dns_zone_names" {
  description = "The 6 private DNS zones the Storage account's private endpoints resolve through (one per subresource: blob/file/queue/table/dfs/web). Leave null to use the required set."
  type        = list(string)
  default     = null

  validation {
    condition     = var.storage_private_dns_zone_names == null || length(var.storage_private_dns_zone_names) == 6
    error_message = "storage_private_dns_zone_names must contain exactly 6 zones (blob/file/queue/table/dfs/web) or be null to use the built-in defaults."
  }
}

variable "cosmos_private_dns_zone_name" {
  description = "Private DNS zone the Cosmos DB SQL-API private endpoint resolves through. Leave null to use `privatelink.documents.azure.com`."
  type        = string
  default     = null
}

variable "search_private_dns_zone_name" {
  description = "Private DNS zone the AI Search private endpoint resolves through. Leave null to use `privatelink.search.windows.net`."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Public-endpoint / IP-allowlist controls
#
# During normal operation `enable_public_network_access = true` keeps the
# services reachable from the public internet AND enforces a default-deny
# firewall that only lets the deployer + allowed_ips_extra through. Set to
# false to fully close the public endpoint (hardening mode). See the README
# section "Harden the deployment" for the lifecycle around this switch.
# -----------------------------------------------------------------------------

variable "enable_public_network_access" {
  description = "Master switch for the public endpoint on every workload data-plane service (Storage, Cosmos, AI Search, Foundry). When true (default) the services are reachable via their public FQDN, filtered by the IP allowlist (`deployer_ip` + `allowed_ips_extra`). When false the public endpoint is disabled entirely on all 4 services -- only VNet-injected agent runtime traffic can reach them via private endpoints. Flip to false to harden the deployment once you're done making changes; flip back to true before your next apply that touches Cosmos SQL role assignments or Foundry capability hosts (both of which use the data plane)."
  type        = bool
  default     = true
}

variable "deployer_ip" {
  description = "Public IPv4 of the machine running `terraform apply` (used to pin the workload services' firewalls to just this address). Leave null to auto-detect via the http provider (https://api.ipify.org). Set explicitly when your egress IP is masked (VPN, corporate proxy) or when you need to pin a stable value in CI. Set to \"\" (empty string) to skip adding the deployer IP -- useful for CI runs that shouldn't advertise their runner IP, or for the hardening step. Format: bare IPv4 (`203.0.113.42`) or CIDR /0-/30. `/31` and `/32` are rejected because Cognitive Services rejects them in `network_acls.ip_rules` -- use the bare IP."
  type        = string
  default     = null

  validation {
    # Strict IPv4/CIDR: each octet 0-255, optional /0-/30. Anchored, no /31 /32.
    # Accept: null (auto-detect), "" (skip), or a valid bare/CIDR IPv4.
    condition = var.deployer_ip == null || var.deployer_ip == "" || can(regex(
      "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-9]|[12][0-9]|30))?$",
    var.deployer_ip))
    error_message = "deployer_ip must be null (auto-detect), \"\" (skip), or a bare IPv4 / CIDR /0-/30 (e.g. 203.0.113.42 or 203.0.113.0/24). Do NOT use /31 or /32 -- Cognitive Services rejects them; use the bare IP."
  }
}

variable "allowed_ips_extra" {
  description = "Additional IPv4 addresses or CIDR ranges to allowlist on every workload service, on top of the deployer IP. Same format rules as `deployer_ip`: bare IPv4 or CIDR /0-/30 (`/31` and `/32` rejected -- use the bare IP)."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.allowed_ips_extra : can(regex(
        "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-9]|[12][0-9]|30))?$",
      ip))
    ])
    error_message = "Every entry in allowed_ips_extra must be a bare IPv4 (e.g. 203.0.113.42) or CIDR /0-/30 (e.g. 198.51.100.0/24). Do NOT use /31 or /32 -- Cognitive Services rejects them; use the bare IP."
  }
}
