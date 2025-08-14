variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Base name for storage account"
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

variable "search_sku" {
  description = "SKU for the search service"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the search service will be deployed"
  type        = string
}

variable "subresource_names" {
  description = "Names of the subresources"
  type        = list(string)
  default     = ["searchService"]
}

variable "private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "search_public_network_access_enabled" {
  description = "Enable public network access for the search service"
  type        = bool
}