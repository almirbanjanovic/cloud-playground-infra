variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Base name for resource group"
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
  description = "Name of the resource group"
  type        = string
}

variable "virtual_network_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "private_ip_allocation_method" {
  description = "Allocation method for the private IP address for DNS resolver"
  type        = string
}

variable "private_ip_address" {
  description = "Private IP address for the DNS resolver inbound endpoint."
  type        = string

  validation {
    condition     = !(var.private_ip_allocation_method == "Static" && (var.private_ip_address == null || var.private_ip_address == ""))
    error_message = "The private_ip_address must be specified when private_ip_allocation_method is set to 'Static'."
  }
}

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}