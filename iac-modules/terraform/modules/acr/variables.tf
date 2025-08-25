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

variable "admin_enabled" {
  description = "Enable admin user"
  type        = bool
}

variable "sku" {
  description = "SKU for the container registry"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}

variable "subresource_names" {
  description = "Names of the subresources"
  type        = list(string)
  default     = ["registry"]
}

variable "private_dns_zone_id" {
  description = "The IDs of the private DNS zones."
  type        = string
}

variable "data_private_dns_zone_id" {
  description = "The IDs of the private DNS zones."
  type        = string
}

variable "data_private_dns_zone_name" {
  description = "The name of the private DNS zones."
  type        = string
}

variable "allowed_ips" {
  description = "List of allowed IP addresses"
  type        = list(string)
}

variable "zone_redundancy_enabled" {
  description = "Enable or disable zone redundancy"
  type        = bool
}