variable "tags" {
  type = map(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "base_name" {
  description = "Base name for the VNet"
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

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

variable "subnet_address_prefix_acr" {
  description = "Address space for the ACR subnet"
  type        = string
}

variable "subnet_address_prefix_aks_nodes" {
  description = "Address space for the AKS nodes subnet"
  type        = string
}

variable "subnet_address_prefix_aks_api_server" {
  description = "Address space for the AKS API server subnet"
  type        = string
}

variable "subnet_address_prefix_app_gateway" {
  description = "Address space for the App Gateway subnet"
  type        = string
}

variable "subnet_address_prefix_azure_sql" {
  description = "Address space for the Azure SQL subnet"
  type        = string
}

variable "subnet_address_prefix_key_vault" {
  description = "Address space for the Key Vault subnet"
  type        = string
}

variable "subnet_address_prefix_aks_pods" {
  description = "Address space for the AKS pods subnet"
  type        = string
}

variable "subnet_address_prefix_private_dns_resolver" {
  description = "Address space for the Private DNS Resolver subnet"
  type        = string
}

variable "subnet_address_prefix_storage_account" {
  description = "Address space for the Storage Account subnet"
  type        = string
}

variable "subnet_address_prefix_vpn_gateway" {
  description = "Address space for the VPN Gateway subnet"
  type        = string
}

variable "subnet_address_prefix_machine_learning" {
  description = "Address space for the Machine Learning subnet"
  type        = string
}

variable "subnet_address_prefix_azure_monitor" {
  description = "Address space for the Azure Monitor subnet"
  type        = string
}

variable "subnet_address_prefix_search" {
  description = "Address space for the Search subnet"
  type        = string
}

variable "subnet_address_prefix_web_apps" {
  description = "Address space for the Web Apps subnet"
  type        = string
}

variable "subnet_address_prefix_stream_analytics" {
  description = "Address space for the Stream Analytics subnet"
  type        = string
}

variable "subnet_address_prefix_azure_postgresql" {
  description = "Address space for the Azure PostgreSQL subnet"
  type        = string
}