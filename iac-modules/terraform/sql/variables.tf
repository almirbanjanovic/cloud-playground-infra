variable "tags" {
  type = map(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "base_name" {
  description = "Base name"
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

variable "tenant_sql_username" {
  description = "SQL Server username"
  type        = string
}

variable "tenant_sql_password" {
  description = "SQL Server password"
  type        = string
}

variable "admin_group_name" {
  description = "Name of the admin group"
  type        = string
}

variable "admin_group_object_id" {
  description = "Object ID of the admin group"
  type        = string
}

variable "sql_server_version" {
  description = "SQL Server version"
  type        = string
}

variable "sql_server_minimum_tls_version" {
  description = "SQL Server minimum TLS version"
  type        = string
}

variable "sql_db_maintenance_configuration_name" {
  description = "Name of the SQL DB maintenance configuration"
  type        = string
  default     = "SQL_Default"
}

variable "sql_db_sku_name" {
  description = "SQL DB SKU name"
  type        = string
}

variable "sql_db_min_capacity" {
  description = "Minimum capacity for the SQL DB"
  type        = number
}

variable "sql_db_max_size_gb" {
  description = "Maximum size for the SQL DB"
  type        = number
}

variable "sql_db_storage_account_type" {
  description = "Storage account type for the SQL DB"
  type        = string
}

variable "sql_db_auto_pause_delay_in_minutes" {
  description = "Auto-pause delay in minutes for the SQL DB"
  type        = number
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "subresource_names" {
  description = "Names of the subresources"
  type        = list(string)
  default     = ["sqlServer"]
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs"
  type        = list(string)
}

variable "suffix" {
  description = "Suffix to append to the storage account name"
  type        = string
  default     = ""
}

variable "database_suffix_only" {
  description = "Suffix to append to the database name"
  type        = string
  default     = ""
}

variable "zone_redundant" {
  description = "Zone redundant"
  type        = bool
  default     = false
}

variable "sql_db_name_for_migration" {
  description = "SQL DB name for migration"
  type        = string
  default     = ""
}