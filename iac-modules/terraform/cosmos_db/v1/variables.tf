variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
}

variable "base_name" {
  description = "Base name for the Cosmos DB account."
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod, etc.)."
  type        = string
}

variable "location" {
  description = "Azure location for the Cosmos DB account and its primary geo replica."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Azure resource group."
  type        = string
}

variable "offer_type" {
  description = "The offer type for the Cosmos DB account. Currently only 'Standard' is supported."
  type        = string
  default     = "Standard"
  validation {
    condition     = var.offer_type == "Standard"
    error_message = "offer_type must be 'Standard'."
  }
}

variable "kind" {
  description = "The kind of Cosmos DB account (GlobalDocumentDB, MongoDB, or Parse)."
  type        = string
  default     = "GlobalDocumentDB"
  validation {
    condition     = contains(["GlobalDocumentDB", "MongoDB", "Parse"], var.kind)
    error_message = "kind must be one of: GlobalDocumentDB, MongoDB, Parse."
  }
}

variable "minimal_tls_version" {
  description = "The minimal TLS version for the Cosmos DB account. Possible values are Tls, Tls11, and Tls12."
  type        = string
  default     = "Tls12"
  validation {
    condition     = contains(["Tls", "Tls11", "Tls12"], var.minimal_tls_version)
    error_message = "minimal_tls_version must be one of: Tls, Tls11, Tls12."
  }
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover for the Cosmos DB account."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access. Defaults to false since this module attaches a private endpoint."
  type        = bool
  default     = false
}

variable "ip_range_filter" {
  description = "Set of IPv4 addresses or CIDR ranges allowed to reach the account's public endpoint. Only takes effect when `public_network_access_enabled = true`. Use to allow the deploying user's public IP for testing while keeping VNet workloads on the private endpoint."
  type        = set(string)
  default     = []
}

variable "local_authentication_enabled" {
  description = "Whether local (key-based) authentication is enabled. Defaults to false — Entra ID / RBAC only. SQL API only."
  type        = bool
  default     = false
}

variable "free_tier_enabled" {
  description = "Enable the Cosmos DB free tier. Only one free-tier account is allowed per subscription."
  type        = bool
  default     = false
}

variable "consistency_level" {
  description = "The consistency level of the Cosmos DB account."
  type        = string
  default     = "Session"
  validation {
    condition     = contains(["BoundedStaleness", "Eventual", "Session", "Strong", "ConsistentPrefix"], var.consistency_level)
    error_message = "consistency_level must be one of: BoundedStaleness, Eventual, Session, Strong, ConsistentPrefix."
  }
}

variable "max_interval_in_seconds" {
  description = "Max staleness interval in seconds. Only relevant when consistency_level is BoundedStaleness."
  type        = number
  default     = 5
}

variable "max_staleness_prefix" {
  description = "Max staleness prefix. Only relevant when consistency_level is BoundedStaleness."
  type        = number
  default     = 100
}

variable "zone_redundant" {
  description = "Whether the primary geo replica is zone-redundant."
  type        = bool
  default     = false
}

variable "capabilities" {
  description = "List of Cosmos DB capabilities to enable (e.g., EnableServerless, EnableNoSQLVectorSearch, EnableMongo). Note: some capabilities are required to match a non-SQL kind (e.g., EnableMongo with kind=MongoDB)."
  type        = list(string)
  default     = []
}

variable "identity_type" {
  description = "The type of managed identity to assign to the account. This module only supports SystemAssigned to keep the surface simple; use a dedicated variant for user-assigned identities."
  type        = string
  default     = "SystemAssigned"
  validation {
    condition     = var.identity_type == "SystemAssigned"
    error_message = "identity_type must be 'SystemAssigned' in this module."
  }
}

variable "subnet_id" {
  description = "ID of the subnet where the private endpoint should be created."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "IDs of the private DNS zones to associate with the private endpoint. For SQL API use privatelink.documents.azure.com; MongoDB, Cassandra, Gremlin, Table, and Analytical each use their own zone."
  type        = list(string)
}

variable "subresource_names" {
  description = "Subresource (group) names for the private endpoint connection. Valid values include: Sql (NoSQL / SQL API), MongoDB, Cassandra, Gremlin, Table, SqlDedicated. Must match the account's kind/capabilities."
  type        = list(string)
  default     = ["Sql"]
  validation {
    condition     = length(var.subresource_names) == 1 && contains(["Sql", "MongoDB", "Cassandra", "Gremlin", "Table", "SqlDedicated"], var.subresource_names[0])
    error_message = "subresource_names must be exactly one of: Sql, MongoDB, Cassandra, Gremlin, Table, SqlDedicated."
  }
}

variable "role_assignments" {
  description = "Control-plane role assignments (azurerm_role_assignment) to create on this Cosmos DB account. Map key is a stable identifier for state addressing."
  type = map(object({
    principal_id         = string
    role_definition_name = string
    principal_type       = optional(string, "ServicePrincipal")
  }))
  default = {}
}

variable "sql_role_assignments" {
  description = "Cosmos DB SQL (data-plane) role assignments — used to grant Entra ID principals read/write access via managed identity. role_definition_id is the last GUID of the built-in role (00000000-0000-0000-0000-000000000001 = Data Reader, 00000000-0000-0000-0000-000000000002 = Data Contributor) or a custom role GUID."
  type = map(object({
    principal_id       = string
    role_definition_id = string
    scope_suffix       = optional(string, "")
  }))
  default = {}
}
