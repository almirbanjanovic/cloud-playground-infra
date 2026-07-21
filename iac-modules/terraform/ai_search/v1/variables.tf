variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Short project / workload identifier used as a prefix for the AI Search service name."
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
  description = "ID of the subnet where the AI Search PRIVATE ENDPOINT will be created. The Search service itself is not VNet-injected — this subnet only hosts its PE NIC."
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

variable "allowed_ips" {
  description = "IPv4 addresses or CIDR ranges allowed to reach the search service's public endpoint. Only takes effect when `search_public_network_access_enabled = true`. Use to allow the deploying user's public IP for testing while keeping VNet workloads on the private endpoint."
  type        = list(string)
  default     = []
}

variable "local_authentication_enabled" {
  description = "Whether admin/query API keys can be used to authenticate. Defaults to false — Entra ID / RBAC only."
  type        = bool
  default     = false
}

variable "identity_type" {
  description = "Type of managed identity to assign to the search service."
  type        = string
  default     = "SystemAssigned"
  validation {
    condition     = contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.identity_type)
    error_message = "identity_type must be one of: SystemAssigned, UserAssigned, 'SystemAssigned, UserAssigned'."
  }
}

variable "identity_ids" {
  description = "List of User Assigned Identity resource IDs. Only used when identity_type is UserAssigned or 'SystemAssigned, UserAssigned'."
  type        = list(string)
  default     = null
  validation {
    condition     = var.identity_ids == null || (try(length(var.identity_ids), 0) > 0)
    error_message = "identity_ids must be null or a non-empty list of User Assigned Identity resource IDs."
  }
}

variable "role_assignments" {
  description = "Role assignments to create on this search service. Grant principals data-plane roles like 'Search Index Data Contributor' or 'Search Service Contributor'."
  type = map(object({
    principal_id         = string
    role_definition_name = string
    principal_type       = optional(string, "ServicePrincipal")
  }))
  default = {}
}