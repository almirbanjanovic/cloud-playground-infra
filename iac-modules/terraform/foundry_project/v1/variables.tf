variable "tags" {
  type        = map(string)
  description = "Tags applied to the project."
}

variable "base_name" {
  type        = string
  description = "Base name for naming (proj-{base_name}-{environment}-{location})."
}

variable "environment" {
  type        = string
  description = "Environment (dev, prod, ...)."
}

variable "location" {
  type        = string
  description = "Azure region for the project."
}

variable "cognitive_account_id" {
  type        = string
  description = "The ID of the parent AIServices Cognitive account. It must have project_management_enabled = true and a system-assigned managed identity."
}

variable "name" {
  type        = string
  description = "Explicit project name. Defaults to proj-{base_name}-{environment}-{location}."
  default     = null
}

variable "description" {
  type        = string
  description = "Optional description shown in the Foundry portal."
  default     = null
}

variable "display_name" {
  type        = string
  description = "Optional display name shown in the Foundry portal. Defaults to the generated project name."
  default     = null
}

#--------------------------------------------------------------------------------------------------------------------------------
# BYO stateful stack — leave any of these null to skip that connection.
#--------------------------------------------------------------------------------------------------------------------------------

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the BYO Storage account for Foundry agent files. Null to skip the storage connection."
  default     = null
}

variable "storage_blob_endpoint" {
  type        = string
  description = "Blob endpoint URL of the Storage account, e.g. https://<name>.blob.core.windows.net/. Required when storage_account_id is set."
  default     = null
}

variable "cosmos_db_account_id" {
  type        = string
  description = "Resource ID of the BYO Cosmos DB account for Foundry agent thread state. Null to skip."
  default     = null
}

variable "cosmos_db_document_endpoint" {
  type        = string
  description = "Cosmos DB account endpoint (documentEndpoint). Required when cosmos_db_account_id is set."
  default     = null
}

variable "ai_search_id" {
  type        = string
  description = "Resource ID of the BYO AI Search service for Foundry agent vector data. Null to skip."
  default     = null
}

variable "ai_search_endpoint" {
  type        = string
  description = "AI Search endpoint URL, e.g. https://<name>.search.windows.net. Required when ai_search_id is set."
  default     = null
}

variable "enable_capability_host" {
  type        = bool
  description = "Whether to create the Agent Service capability host that binds the three BYO connections to the project. Set to false to only create the connections."
  default     = true
}
