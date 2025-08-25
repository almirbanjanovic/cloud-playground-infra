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

variable "amw_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones for Azure Monitor Workspace required for Prometheus."
  type        = list(string)
}

variable "amw_subresource_names" {
  description = "Names of the subresources for Azure Monitor Workspace required for Prometheus."
  type        = list(string)
  default     = ["prometheusMetrics"]
}

variable "aks_id" {
  description = "ID of AKS cluster"
  type        = string
}

variable "aks_name" {
  description = "Name of AKS cluster"
  type        = string
}

variable "monitor_private_link_scope_name" {
  description = "Name of the private link scope for Azure Monitor"
  type        = string
}