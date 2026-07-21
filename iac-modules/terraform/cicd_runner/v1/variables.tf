variable "base_name" {
  type        = string
  description = "Short project / workload identifier used as a prefix for all resource names."
}

variable "environment" {
  type        = string
  description = "Environment slug (e.g. dev, prod)."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that will hold the runner VM and its supporting resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource created by this module."
  default     = {}
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet the runner NIC will attach to. Should be in a VNet with a NAT gateway so the runner has outbound Internet."
}

variable "vm_size" {
  type        = string
  description = "Azure VM SKU. Standard_B2s is enough for most terraform-apply workloads; bump for parallel jobs or heavy compilation."
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "Local admin user on the VM. Also owns the actions-runner install directory."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "OpenSSH public key installed for `admin_username`. Required by `azurerm_linux_virtual_machine` when password auth is disabled, but not actually reachable — the runner has no public IP and the NSG denies all inbound at priority 4000, blocking SSH even from inside the VNet. Diagnostics go through `az vm run-command invoke` instead."
}

variable "github_org" {
  type        = string
  description = "GitHub organization (or user) that owns the repo the runner registers against."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name the runner registers against (repo-level runner)."
}

variable "github_pat" {
  type        = string
  description = "Fine-grained GitHub PAT with `Administration: read/write` on the target repo. Used by cloud-init to mint a fresh registration token at boot."
  sensitive   = true
}

variable "runner_labels" {
  type        = list(string)
  description = "Labels applied to the runner. Workflow callers select this runner with e.g. `runs-on: [self-hosted, ai-foundry]`."
  default     = ["self-hosted", "linux", "azure"]
}

variable "runner_version" {
  type        = string
  description = "GitHub Actions runner release tag. Bump when GitHub deprecates older versions. See https://github.com/actions/runner/releases."
  default     = "2.328.0"
}

variable "runner_group" {
  type        = string
  description = "Optional runner group name passed to `config.sh --runnergroup`. This module registers the runner at REPO scope only (cloud-init hits the repo-level registration endpoint), so most GitHub deployments will leave this empty — runner groups are typically an org-level feature."
  default     = ""
}
