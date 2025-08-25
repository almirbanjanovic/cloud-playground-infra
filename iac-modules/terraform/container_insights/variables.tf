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

variable "log_analytics_workspace_id" {
  description = "The ID of a Log Analytic Workspace resource"
  type        = string
}

variable "monitor_private_link_scope_name" {
  description = "Name of the private link scope for Azure Monitor"
  type        = string
}

variable "streams" {
  default = [
    "Microsoft-ContainerLog",
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
    "Microsoft-KubePVInventory",
    "Microsoft-KubeServices",
    "Microsoft-KubeMonAgentEvents",
    "Microsoft-InsightsMetrics",
    "Microsoft-ContainerInventory",
    "Microsoft-ContainerNodeInventory",
    "Microsoft-Perf"
  ]
}

variable "data_collection_interval" {
  default = "1m"
}

variable "namespace_filtering_mode_for_data_collection" {
  default = "Off"
}

variable "namespaces_for_data_collection" {
  default = ["kube-system", "gatekeeper-system", "azure-arc"]
}

variable "enableContainerLogV2" {
  default = true
}

variable "aks_id" {
  description = "ID of AKS cluster"
  type        = string
}

variable "aks_name" {
  description = "Name of AKS cluster"
  type        = string
}