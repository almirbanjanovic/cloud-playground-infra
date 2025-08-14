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

variable "container_registry_id" {
  description = "ID of the container registry"
  type        = string
}

variable "suffix" {
  description = "Suffix for storage account"
  type        = string
  default     = "mlw"
}

variable "machine_learning_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}


variable "machine_learning_subresource_names" {
  description = "Names of the subresources"
  type        = list(string)
  default     = ["amlworkspace"]
}

variable "blob_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "file_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "table_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "queue_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "web_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
}

variable "dfs_private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  type        = list(string)
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
  description = "Minimum TLS version for storage account"
  type        = string
}

variable "storage_account_enable_https_traffic_only" {
  description = "Enable HTTPS traffic only for storage account"
  type        = bool
}

variable "kv_sku" {
  description = "SKU for the Key Vault"
  type        = string
}

variable "kv_tenant_id" {
  description = "Tenant ID for the Key Vault"
  type        = string
}

variable "kv_enable_rbac_authorization" {
  description = "Enable RBAC authorization for the Key Vault"
  type        = bool
}

variable "kv_enabled_for_template_deployment" {
  description = "Enable for template deployment for the Key Vault"
  type        = bool
}

variable "kv_network_acls_bypass" {
  description = "Network ACLs bypass for the Key Vault"
  type        = string
}

variable "kv_network_acls_default_action" {
  description = "Network ACLs default action for the Key Vault"
  type        = string
}

variable "kv_soft_delete_retention_days" {
  description = "Soft delete retention days for the Key Vault"
  type        = number
}

variable "kv_purge_protection_enabled" {
  description = "Purge protection enabled for the Key Vault"
  type        = bool
}

variable "kv_private_dns_zone_ids" {
  description = "The IDs of the Key Vault private DNS zones."
  type        = list(string)
}

variable "kv_allowed_ips" {
  description = "Allowed IPs for the Key Vault"
  type        = list(string)
}

variable "application_insights_id" {
  description = "ID of the Application Insights"
  type        = string
}

variable "aks_id" {
  description = "ID of the AKS cluster in the SafeTower Shared Multi-Tenant Environment"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster in the SafeTower Shared Multi-Tenant Environment"
  type        = string
}

variable "machine_learning_cluster_purpose" {
  description = "Purpose of the Machine Learning cluster"
  type        = string
}

variable "machine_learning_friendly_name" {
  description = "Friendly name for the Machine Learning workspace"
  type        = string
}

variable "machine_learning_public_network_access_enabled" {
  description = "Enable public network access for the Machine Learning workspace"
  type        = bool
}

variable "storage_account_network_rules_default_action" {
  description = "Default action for the network ACLs"
  type        = string
}

variable "aks_namespace_name" {
  description = "Name of the tenant namespace for model deployment"
  type        = string
}

variable "python_connection_string" {
  description = "Connection string for the Python application"
  type        = string
}

variable "openai_api_key" {
  description = "Api key for openai deployment"
  type        = string
}

variable "enable_external_data" {
  type    = bool
  default = true
}

variable "alert_failed_jobs_enabled" {
  type    = bool
  default = true
}

variable "alert_failed_jobs_metric_namespace" {
  description = "Name of the metric namespace for ML alerts (e.g. Microsoft.MachineLearningServices/workspaces)"
  type        = string
  default     = "Microsoft.MachineLearningServices/workspaces"
}

variable "alert_failed_jobs_email_receivers" {
  description = "A list of email receivers for the action group."
  type        = string
  default     = "[]"
}
