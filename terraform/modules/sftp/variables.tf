variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Base name for storage account"
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

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
}

variable "storage_account_replication_type" {
  description = "Storage account replication type"
  type        = string
}

variable "storage_account_min_tls_version" {
  description = "Minimum TLS version"
  type        = string
}

variable "storage_account_enable_https_traffic_only" {
  description = "Boolean indicating if only HTTPS traffic is enabled"
  type        = bool
}

variable "allowed_ips" {
  description = "List of allowed IP addresses"
  type        = list(string)
  default     = null
}

variable "storage_account_subnet_id" {
  description = "Storage account subnet ID"
  type        = string
}

variable "blob_private_dns_zone_id" {
  description = "Blob private DNS zone ID"
  type        = string
}

variable "table_private_dns_zone_id" {
  description = "Table private DNS zone ID"
  type        = string
}

variable "queue_private_dns_zone_id" {
  description = "Queue private DNS zone ID"
  type        = string
}

variable "file_private_dns_zone_id" {
  description = "File private DNS zone ID"
  type        = string
}

variable "web_private_dns_zone_id" {
  description = "Web private DNS zone ID"
  type        = string
}

variable "dfs_private_dns_zone_id" {
  description = "DFS private DNS zone ID"
  type        = string
}

variable "sftp_storage_container_name" {
  description = "SFTP storage container name"
  type        = string
}

variable "sftp_local_user_name" {
  description = "SFTP local user name"
  type        = string
}