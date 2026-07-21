variable "resource_group_name" {
  type        = string
  description = "Resource group that owns everything in this base stack. Must already exist (create it manually with `az group create` before running `terraform apply` — see the ai-foundry README, Step 1). Defaults to `rg-ai-foundry-dev`; override for a different name."
  default     = "rg-ai-foundry-dev"
}

# -----------------------------------------------------------------------------
# Naming inputs.
#
# Both stacks (base + workload) accept these three variables with identical
# defaults. If you change any of them, change them in BOTH stacks' tfvars so
# the workload's data-source lookups still resolve base's outputs.
# -----------------------------------------------------------------------------

variable "base_name" {
  description = "Short project identifier used as a prefix in every derived resource name (VNet, subnets)."
  type        = string
  default     = "playground"
}

variable "environment" {
  description = "Environment suffix used in derived resource names (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for the VNet and every regional resource. Default `eastus2` is on Microsoft's list of Foundry Agent Service regions that support the private-networking Standard Setup, has 3 availability zones, and hosts the full model catalog. If you change this, verify the target region is on https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions."
  type        = string
  default     = "eastus2"
}

# -----------------------------------------------------------------------------
# Terraform-state storage account (created by base, consumed as backend by workload)
# -----------------------------------------------------------------------------

variable "tfstate_container_name" {
  description = "Blob container name inside the tfstate storage account. The workload stack initialises its `azurerm` backend against this container (see workload/terraform/providers.tf). Default `tfstate`."
  type        = string
  default     = "tfstate"
}

variable "tfstate_storage_account_name" {
  description = "Full override for the Terraform-state storage account name. Leave null (default) to use the derived `sttfs<md5(...)>` name. Override when the derived name collides with an existing globally-unique storage account name -- pick any 3-24 char lowercase alphanumeric string. Whatever you set here must match the value passed to `terraform init -backend-config=storage_account_name=...`."
  type        = string
  default     = null

  validation {
    condition     = var.tfstate_storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.tfstate_storage_account_name))
    error_message = "tfstate_storage_account_name must be null or a 3-24 char lowercase alphanumeric string."
  }
}

# -----------------------------------------------------------------------------
# Public-endpoint / IP-allowlist controls (applies to the tfstate storage account)
#
# The tfstate storage account created by this stack needs the deployer's IP
# on its firewall allowlist so the WORKLOAD stack (running from the same
# laptop) can read/write the state file via the storage data plane. The BASE
# stack itself doesn't consume this storage account -- it just creates it --
# so hardening the allowlist doesn't break base's own runs.
# -----------------------------------------------------------------------------

variable "enable_public_network_access" {
  description = "Master switch for the tfstate storage account's public endpoint. When true (default) the account is reachable via its public FQDN, filtered by the IP allowlist (`deployer_ip` + `allowed_ips_extra`). When false the public endpoint is disabled entirely -- only VNet traffic through the private endpoint can reach the tfstate blob. Flip to false to harden the state store; you'll then need VPN/private access from your laptop to reach state on the next workload apply."
  type        = bool
  default     = true
}

variable "deployer_ip" {
  description = "Public IPv4 of the machine running `terraform apply` (added to the tfstate storage account's firewall allowlist). Leave null to auto-detect via api.ipify.org. Set explicitly when your egress IP is masked (VPN, corporate proxy). Set to \"\" to skip. Format: bare IPv4 or CIDR /0-/30."
  type        = string
  default     = null

  validation {
    condition = var.deployer_ip == null || var.deployer_ip == "" || can(regex(
      "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-9]|[12][0-9]|30))?$",
    var.deployer_ip))
    error_message = "deployer_ip must be null (auto-detect), \"\" (skip), or a bare IPv4 / CIDR /0-/30 (e.g. 203.0.113.42 or 203.0.113.0/24). Do NOT use /31 or /32."
  }
}

variable "allowed_ips_extra" {
  description = "Additional IPv4 / CIDR entries allowlisted on the tfstate storage account, on top of `deployer_ip`. Same format rules."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.allowed_ips_extra : can(regex(
        "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-9]|[12][0-9]|30))?$",
      ip))
    ])
    error_message = "Every entry in allowed_ips_extra must be a bare IPv4 or CIDR /0-/30. Do NOT use /31 or /32."
  }
}
