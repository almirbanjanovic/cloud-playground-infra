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

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}

variable "ampls_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones for Azure Monitor Private Link Scope."
  type        = list(string)
}

variable "ampls_subresource_names" {
  description = "Names of the subresources for Azure Monitor Private Link Scope."
  type        = list(string)
  default     = ["azuremonitor"]
}