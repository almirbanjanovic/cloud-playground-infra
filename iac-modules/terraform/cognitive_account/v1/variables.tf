variable "tags" {
  type = map(string)
}

variable "resource_group_name" {
  type        = string
  description = "The name of the Azure resource group."
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
  type        = string
  description = "Location for the Cognitive Services account."
}

variable "kind" {
  type        = string
  description = "The kind of the Cognitive Services account (e.g., AIServices, OpenAI, CognitiveServices)."
}

variable "sku_name" {
  type        = string
  description = "The SKU name of the Cognitive Services account."
}

variable "custom_subdomain_name" {
  type        = string
  description = "The custom subdomain name. Required for stateful development in Foundry including agent service."
}

variable "project_management_enabled" {
  type        = bool
  description = "Whether project management is enabled on the account."
}

variable "identity_type" {
  type        = string
  description = "The type of managed identity to assign to the account."
  default     = "SystemAssigned"
  validation {
    condition     = contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.identity_type)
    error_message = "identity_type must be one of: SystemAssigned, UserAssigned, 'SystemAssigned, UserAssigned'."
  }
}

variable "network_acls_default_action" {
  type        = string
  description = "The default action for the network ACLs."
}

variable "network_acls_bypass" {
  type        = string
  description = "The bypass setting for the network ACLs."
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs"
  type        = list(string)
}

variable "subresource_names" {
  description = "Subresource names"
  type        = list(string)
  #default     = ["account"]
}

variable "local_auth_enabled" {
  description = "Whether local (key-based) authentication is enabled. Defaults to false — Entra ID / RBAC only."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Whether the account is reachable from the public internet. Defaults to false; combine with a private endpoint for private-networking deployments. Setting to true and Deny in network_acls still restricts by rule, but false is the strict private-networking posture Foundry docs require."
  type        = bool
  default     = false
}

variable "role_assignments" {
  description = "Role assignments to create on this Cognitive Services account. Grant principals data-plane roles such as 'Cognitive Services User' or 'Cognitive Services OpenAI User'."
  type = map(object({
    principal_id         = string
    role_definition_name = string
    principal_type       = optional(string, "ServicePrincipal")
  }))
  default = {}
}

variable "agent_subnet_id" {
  description = "Optional subnet ID for Foundry Agent Service network injection. When set, agent-runtime compute is injected into this subnet. The subnet MUST be delegated to Microsoft.App/environments, be at least /27 (recommended /24), and use RFC1918 private IPv4 (172.16.0.0/12 or 192.168.0.0/16 in most regions). Only applicable when kind = AIServices."
  type        = string
  default     = null
}
