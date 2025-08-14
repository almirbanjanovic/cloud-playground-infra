variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which the resources will be created."
}

variable "vnet_id" {
  type        = string
  description = "The ID of the virtual network in which the private DNS zones will be created."
}

variable "vnet_name" {
  type        = string
  description = "The name of the virtual network in which the private DNS zones will be created."
}

variable "tags" {
  type        = map(string)
  description = "Value of the tags"
}

variable "dns_zone_blob" {
  type        = string
  description = "The name of the private DNS zone for Blob storage."
}

variable "dns_zone_file" {
  type        = string
  description = "The name of the private DNS zone for File storage."
}

variable "dns_zone_table" {
  type        = string
  description = "The name of the private DNS zone for Table storage."
}

variable "dns_zone_queue" {
  type        = string
  description = "The name of the private DNS zone for Queue storage."
}

variable "dns_zone_web" {
  type        = string
  description = "The name of the private DNS zone for Web storage."
}

variable "dns_zone_dfs" {
  type        = string
  description = "The name of the private DNS zone for Data Lake Storage Gen2."
}

variable "dns_zone_afs" {
  type        = string
  description = "The name of the private DNS zone for Azure File Share."
}

variable "dns_zone_acr" {
  type        = string
  description = "The name of the private DNS zone for Azure Container Registry."
}

variable "dns_zone_acr_data" {
  type        = string
  description = "The name of the private DNS zone for Azure Container Registry Data."
}

variable "dns_zone_aks" {
  type        = string
  description = "The name of the private DNS zone for Azure Kubernetes Service."
}

variable "dns_zone_kv" {
  type        = string
  description = "The name of the private DNS zone for Key Vault."
}

variable "dns_zone_ai_services_cognitive_services" {
  type        = string
  description = "The name of the private DNS zone for Azure Cognitive Services."
}

variable "dns_zone_ai_services_open_ai" {
  type        = string
  description = "The name of the private DNS zone for Azure Cognitive Services Open AI."
}

variable "dns_zone_ml" {
  type        = string
  description = "The name of the private DNS zone for Azure Machine Learning."
}

variable "dns_zone_ml_notebooks" {
  type        = string
  description = "The name of the private DNS zone for Azure Machine Learning Notebooks."
}

variable "dns_zone_azure_search" {
  type        = string
  description = "The name of the private DNS zone for Azure Search."
}

variable "dns_zone_azure_sql_database" {
  type        = string
  description = "The name of the private DNS zone for Azure SQL Database."
}

variable "dns_zone_azure_monitor" {
  type        = string
  description = "The name of the private DNS zone for Azure Monitor."
}

variable "dns_zone_oms_opinsights" {
  type        = string
  description = "The name of the private DNS zone for Azure Monitor Log Analytics."
}

variable "dns_zone_ods_opinsights" {
  type        = string
  description = "The name of the private DNS zone for Azure Monitor Log Analytics."
}

variable "dns_zone_agentsvc_automation" {
  type        = string
  description = "The name of the private DNS zone for Azure Automation."
}

variable "dns_zone_prometheus" {
  type        = string
  description = "The name of the private DNS zone for Prometheus."
}

variable "dns_zone_grafana" {
  type        = string
  description = "The name of the private DNS zone for Grafana."
}

variable "dns_zone_web_apps" {
  type        = string
  description = "The name of the private DNS zone for Web Apps."
}

variable "dns_zone_web_apps_scm" {
  type        = string
  description = "The name of the private DNS zone for Web Apps SCM."
}

variable "dns_zone_azure_postgresql_database" {
  type        = string
  description = "The name of the private DNS zone for Azure PostgreSQL Database."
}