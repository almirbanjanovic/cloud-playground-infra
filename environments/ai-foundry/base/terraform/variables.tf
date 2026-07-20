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
  description = "OpenSSH public key installed on both VMs. Break-glass SSH only for the runner; primary access for the jumpbox unless Entra SSH is used."
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
  description = "Entra ID object IDs (users or groups) that get `Virtual Machine Administrator Login` on the jumpbox, enabling `az ssh vm` with AAD auth."
  default     = []
}

# -----------------------------------------------------------------------------
# CI/CD runner — GitHub registration + federated identity
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
