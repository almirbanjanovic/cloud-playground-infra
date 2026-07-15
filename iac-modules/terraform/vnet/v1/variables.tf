variable "tags" {
  description = "Tags applied to the VNet."
  type        = map(string)
}

variable "resource_group_name" {
  description = "Resource group that will hold the VNet."
  type        = string
}

variable "base_name" {
  description = "Base name used to compose the VNet name: vnet-{base_name}-{environment}-{location}."
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod)."
  type        = string
}

variable "location" {
  description = "Azure region for the VNet."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the VNet (list of CIDR blocks)."
  type        = list(string)
}
