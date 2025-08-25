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

variable "ampls_resource_group_name" {
  description = "Resource group name for Azure Monitor Private Link Scope"
  type        = string
}

variable "storage_account_id" {
  description = "ID of storage account"
  type        = string
}

variable "diagnostic_services_trusted_storage_access_object_id" {
  description = "value of the object id of the service principal that needs access to the storage account"
  type        = string
}

variable "monitor_private_link_scope_name" {
  description = "Name of the Azure Monitor Private Link Scope"
  type        = string
}

