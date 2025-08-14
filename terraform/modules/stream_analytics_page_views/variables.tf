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

variable "resource_group_id" {
  description = "Resource group id"
  type        = string
}

variable "stream_analytics_subnet_id" {
  description = "Stream Analytics subnet id"
  type        = string
}

variable "storage_account_subnet_id" {
  description = "Storage account subnet id"
  type        = string
}

variable "app_insights_id" {
  description = "Application Insights id"
  type        = string
}

variable "sql_server_id" {
  description = "SQL server id"
  type        = string
}

variable "sql_server_name" {
  description = "SQL server name"
  type        = string
}

variable "sql_db_name" {
  description = "SQL database name"
  type        = string
}

variable "sql_db_table_name" {
  description = "SQL database table name"
  type        = string
  default     = "PageViewsTable" # The table name is predefined in the table schema and is not configurable.
}

variable "sql_admin_user" {
  description = "SQL admin user"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password"
  type        = string
}

variable "app_insights_name" {
  description = "Application Insights name"
  type        = string
}

variable "suffix" {
  description = "Suffix for resources"
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
  description = "Storage account minimum TLS version"
  type        = string
}

variable "storage_account_enable_https_traffic_only" {
  description = "Storage account enable HTTPS traffic only"
  type        = bool
}

variable "blob_private_dns_zone_ids" {
  description = "Blob private DNS zone ids"
  type        = list(string)
}

variable "table_private_dns_zone_ids" {
  description = "Table private DNS zone ids"
  type        = list(string)
}

variable "queue_private_dns_zone_ids" {
  description = "Queue private DNS zone ids"
  type        = list(string)
}

variable "file_private_dns_zone_ids" {
  description = "File private DNS zone ids"
  type        = list(string)
}

variable "web_private_dns_zone_ids" {
  description = "Web private DNS zone ids"
  type        = list(string)
}

variable "dfs_private_dns_zone_ids" {
  description = "DFS private DNS zone ids"
  type        = list(string)
}

variable "stream_analytics_job_start_time" {
  description = "Stream Analytics job start time"
  type        = string
}

variable "stream_analytics_input_alias" {
  description = "Stream Analytics input alias"
  type        = string
  default     = "appPageViewsInput"
}

variable "stream_analytics_output_alias" {
  description = "Stream Analytics output alias"
  type        = string
  default     = "appPageViewsOutput"
}

variable "stream_analytics_sku_capacity" {
  description = "Stream Analytics SKU capacity"
  type        = number
  default     = 10 # 10 SU is the minimum required for StandardV2 for Virtual Network integration
}

variable "stream_analytics_sku_name" {
  description = "Stream Analytics SKU name"
  type        = string
  default     = "StandardV2" # StandardV2 is required for Virtual Network integration
}

variable "stream_analytics_authentication_mode" {
  description = "Stream Analytics authentication mode"
  type        = string
  default     = "Msi" # Managed Identity is required for Virtual Network integration
}

variable "stream_analytics_datasource_storage_container_name" {
  description = "Stream Analytics datasource storage container name"
  type        = string
  default     = "insights-logs-apppageviews" # This name for page views logs container is dictated by Microsoft Azure and is not configurable
}

variable "stream_analytics_datasource_date_format" {
  description = "Stream Analytics datasource date format"
  type        = string
  default     = "yyyy/MM/dd" # This is the default format for the date field in the page views logs
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace id"
  type        = string
}