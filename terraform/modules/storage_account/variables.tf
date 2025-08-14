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

variable "versioning_enabled" {
  description = "Boolean indicating if blob versioning is enabled"
  type        = bool
  default     = true
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
}

variable "storage_account_replication_type" {
  description = "Storage account replication type"
  type        = string
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
}

variable "enable_https_traffic_only" {
  description = "Boolean indicating if only HTTPS traffic is enabled"
  type        = bool
}

variable "allow_nested_items_to_be_public" {
  description = "Enable or disable nested items to be public"
  type        = bool
  default     = false
}

variable "cross_tenant_replication_enabled" {
  description = "Enable or disable replication accross Entra ID tenants"
  type        = bool
  default     = false
}

variable "allowed_ips" {
  description = "List of allowed IP addresses"
  type        = list(string)
  default     = null
}

variable "blob_subresource_names" {
  description = "Subresource names for the blob private endpoint connection"
  type        = list(string)
  default     = ["blob"]
}

variable "table_subresource_names" {
  description = "Subresource names for the table private endpoint connection"
  type        = list(string)
  default     = ["table"]
}

variable "queue_subresource_names" {
  description = "Subresource names for the queue private endpoint connection"
  type        = list(string)
  default     = ["queue"]
}

variable "file_subresource_names" {
  description = "Subresource names for the file private endpoint connection"
  type        = list(string)
  default     = ["file"]
}

variable "dfs_subresource_names" {
  description = "Subresource names for the Azure Data Lake File System Gen2 private endpoint connection"
  type        = list(string)
  default     = ["dfs"]
}

variable "dfs_private_dns_zone_ids" {
  description = "ID of the Azure Data Lake File System Gen2 private DNS zone"
  type        = list(string)
}

variable "web_subresource_names" {
  description = "Subresource names for the web private endpoint connection"
  type        = list(string)
  default     = ["web"]
}

variable "web_private_dns_zone_ids" {
  description = "ID of the web private DNS zone"
  type        = list(string)
}

variable "file_private_dns_zone_ids" {
  description = "ID of the file private DNS zone"
  type        = list(string)
}

variable "queue_private_dns_zone_ids" {
  description = "ID of the queue private DNS zone"
  type        = list(string)
}

variable "table_private_dns_zone_ids" {
  description = "ID of the table private DNS zone"
  type        = list(string)
}

variable "blob_private_dns_zone_ids" {
  description = "ID of the blob private DNS zone"
  type        = list(string)
}

variable "subnet_id" {
  description = "ID of the subnet where the private endpoint should be created"
  type        = string
}

variable "suffix" {
  description = "Suffix to append to the storage account name"
  type        = string
  default     = ""
}

variable "publish_microsoft_endpoint" {
  description = "Boolean indicating if the Microsoft endpoint should be published"
  type        = bool
  default     = false
}

variable "network_rules_default_action" {
  description = "Default action for the network ACLs"
  type        = string
  default     = "Deny"
}

variable "is_hns_enabled" {
  description = "Boolean indicating if Hierarchical Namespace is enabled"
  type        = bool
  default     = false
}

variable "sftp_enabled" {
  description = "Boolean indicating if SFTP is enabled"
  type        = bool
  default     = false
}

variable "blob_properties_versioning_enabled" {
  description = "Boolean indicating if blob versioning is enabled"
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Boolean indicating if public network access is enabled"
  type        = bool
  default     = true
}

variable "prevent_destroy" {
  description = "Boolean indicating if the resource should be destroyed"
  type        = bool
  default     = false
}