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

variable "amg_subresource_names" {
  description = "Names of the subresources for Azure Managed Grafana."
  type        = list(string)
  default     = ["grafana"]
}

variable "amg_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones for Azure Managed Grafana."
  type        = list(string)
}

variable "azure_monitor_workspace_id" {
  description = "ID of Azure Monitor Workspace"
  type        = string
}

variable "azurerm_monitor_private_link_scope_id" {
  description = "ID of Azure Monitor Private Link Scope"
  type        = string
}