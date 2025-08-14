variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Base name for key vault"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod, etc.)"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "suffix" {
  description = "Suffix to append to the key vault name"
  type        = string
  default     = ""
}

variable "sku_name" {
  description = "SKU name for the key vault"
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra Tenant ID to which this key vault belongs"
  type        = string
}

variable "enable_rbac_authorization" {
  description = "Enable RBAC authorization for the key vault"
  type        = bool
}

variable "enabled_for_template_deployment" {
  description = "Enable ARM template deployment for the key vault"
  type        = bool
}

variable "network_acls_bypass" {
  description = "Bypass for network network access control list"
  type        = string
}

variable "network_acls_default_action" {
  description = "Default action for network access control list"
  type        = string
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention days for the key vault"
  type        = number
}

variable "purge_protection_enabled" {
  description = "Enable purge protection for the key vault"
  type        = bool
}

variable "subnet_id" {
  description = "The ID of the subnet for the key vault private endpoint."
  type        = string
}

variable "subresource_names" {
  description = "The names of the subresources for the key vault private endpoint."
  type        = list(string)
  default     = ["vault"]
}

variable "private_dns_zone_ids" {
  description = "The IDs of the private DNS zones associated with the key vault private endpoint."
  type        = list(string)
}

variable "allowed_ips" {
  description = "The IP addresses allowed to access the key vault."
  type        = list(string)
  default     = null
}