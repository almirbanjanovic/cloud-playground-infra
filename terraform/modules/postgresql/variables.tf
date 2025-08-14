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

variable "suffix" {
  description = "Suffix to append to the storage account name"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet id"
  type        = string
}

variable "subresource_names" {
  description = "Names of the subresources"
  type        = list(string)
  default     = ["postgresqlServer"]
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone ids"
  type        = list(string)
}

variable "administrator_login" {
  description = "Administrator login"
  type        = string
}

variable "administrator_password" {
  description = "Administrator password"
  type        = string
}

variable "storage_mb" {
  description = "Storage in MB"
  type        = number
  default     = 32768
}

variable "storage_tier" {
  description = "Storage tier"
  type        = string
  default     = "P4"
}

variable "backup_retention_days" {
  description = "Backup retention days"
  type        = number
  default     = 7
}

variable "postgre_sql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "SKU name"
  type        = string
  default     = "B_Standard_B1ms"
}