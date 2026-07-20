variable "resource_group_name" {
  type        = string
  description = "Resource group that owns everything in this base stack. Must already exist (created by `terraform-init-backend.yaml`)."
}

# -----------------------------------------------------------------------------
# Jumpbox / runner shared inputs
# -----------------------------------------------------------------------------

variable "admin_username" {
  type        = string
  description = "Local admin user provisioned on both the jumpbox and the runner VM."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "OpenSSH public key installed on both VMs. On the jumpbox this is the primary access method (unless Entra ID SSH is used). On the runner it is not usable in practice — the runner has no public IP and its NSG denies all inbound at priority 4000 — but `azurerm_linux_virtual_machine` requires an admin_ssh_key when password auth is disabled, so we install one anyway."
}

# -----------------------------------------------------------------------------
# Jumpbox — inbound access controls
# -----------------------------------------------------------------------------

variable "allowed_ssh_source_prefixes" {
  type        = list(string)
  description = "Source CIDRs allowed to SSH into the jumpbox. Set to your office / home / VPN egress IPs. Never `[\"0.0.0.0/0\"]` outside of a throwaway lab."
}

variable "jumpbox_entra_admin_object_ids" {
  type        = list(string)
  description = "Entra ID object IDs (users or groups) that get `Virtual Machine Administrator Login` on the jumpbox, enabling `az ssh vm` with Entra ID authentication."
  default     = []
}

# -----------------------------------------------------------------------------
# CI/CD runner — GitHub registration inputs
# (Federation between the App Registration and the ai-foundry GitHub
#  environment is configured manually in Entra ID / GitHub — not by this
#  stack. See the ai-foundry README, Prereq A.)
# -----------------------------------------------------------------------------

variable "github_org" {
  type        = string
  description = "GitHub org / user that owns the repo (e.g. `myuser` or `myorg`)."
}

variable "github_repo" {
  type        = string
  description = "GitHub repo name the runner registers against (e.g. `cloud-playground-infra`)."
}

variable "github_pat" {
  type        = string
  description = "Fine-grained GitHub PAT with repository `Administration: read/write` on the target repo. Used by cloud-init to mint a runner registration token at boot."
  sensitive   = true
}
