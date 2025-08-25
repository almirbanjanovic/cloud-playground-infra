variable "tags" {
  type = map(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "base_name" {
  description = "Base name for the VNet"
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

variable "subresource_names" {
  description = "Subresource names"
  type        = list(string)
  default     = ["account"]
}

variable "sku_name" {
  description = "SKU name"
  type        = string
}

variable "open_ai_deployment_name" {
  description = "OpenAI deployment name"
  type        = string
}

variable "open_ai_deployment_version" {
  description = "OpenAI deployment version"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs"
  type        = list(string)
}

variable "open_ai_deployment_sku_name" {
  description = "OpenAI deployment SKU name"
  type        = string
}

variable "open_ai_deployment_capacity" {
  description = "OpenAI deployment capacity (tokens per minute)"
  type        = string
  default     = 20
}
