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

variable "storage_account_id" {
  description = "Storage account ID"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "storage_account_primary_access_key" {
  description = "Storage account primary access key"
  type        = string
}

variable "aks_namespace_name" {
  description = "AKS namespace name"
  type        = string
}

variable "aks_identity_id" {
  description = "AKS identity ID"
  type        = string
}

variable "sql_cron_job_schedule" {
  description = "SQL cron job schedule"
  type        = string
}

variable "sql_database_name" {
  description = "SQL database name"
  type        = string
}

variable "sql_server_name" {
  description = "SQL server name"
  type        = string
}

variable "sql_admin_user" {
  description = "SQL admin user"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password"
  type        = string
}

variable "sql_server_id" {
  description = "SQL server ID"
  type        = string
}