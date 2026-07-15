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
  description = "Resource group that will hold the jumpbox and its NIC / IP / NSG / UAMI."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource created by this module."
  default     = {}
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet the jumpbox NIC will attach to."
}

variable "vm_size" {
  type        = string
  description = "Azure VM SKU. Standard_B2s is fine for a jumpbox."
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "Local admin user on the VM. Used for SSH and for the AAD SSH login extension binding."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "OpenSSH public key installed for `admin_username`. Password auth is always disabled on this VM."
}

variable "enable_public_ip" {
  type        = bool
  description = "Whether to attach a Standard public IP + NSG (with SSH allowlist) to the NIC. Set to false if you'll reach the VM only from inside the VNet or via a peered network."
  default     = true
}

variable "allowed_source_ip_prefixes" {
  type        = list(string)
  description = "Source CIDRs allowed to reach SSH (22) inbound when `enable_public_ip = true`. Ignored otherwise. NEVER set to `[\"*\"]` in a real environment."
  default     = []
}

variable "enable_entra_ssh_login" {
  type        = bool
  description = "Install the AADSSHLoginForLinux extension so operators can sign in with `az ssh vm` using their Entra ID identity."
  default     = true
}

variable "entra_admin_object_ids" {
  type        = list(string)
  description = "Entra ID object IDs that receive `Virtual Machine Administrator Login` at the VM scope. Only used when `enable_entra_ssh_login = true`."
  default     = []
}
