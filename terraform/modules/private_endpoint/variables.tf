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

variable "resource_name" {
  description = "Name of the resource for which this private endpoint is being created"
  type        = string
}

variable "resource_id" {
  description = "ID of the resource for which this private endpoint is being created"
  type        = string
}

variable "subresource_names" {
  description = "Subresource names for the private endpoint connection"
  type        = list(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "is_manual_connection" {
  type    = bool
  default = false
}

variable "private_dns_zone_ids" {
  type = list(string)
}

variable "private_dns_a_record_name" {
  type = string
}

variable "private_dns_resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}