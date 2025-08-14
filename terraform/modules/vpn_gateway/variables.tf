variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Base name for the VPN gateway"
  type        = string
}

variable "environment" {
  description = "Environment name for the VPN gateway"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "gateway_type" {
  description = "The type of the gateway"
  type        = string
}

variable "vpn_type" {
  description = "The VPN type of the gateway"
  type        = string
}

variable "sku" {
  description = "The SKU of the VPN gateway"
  type        = string
}

variable "enable_bgp" {
  description = "Enable BGP"
  type        = bool
  default     = false
}

variable "active_active" {
  description = "Enable active-active mode"
  type        = bool
  default     = false
}

variable "private_ip_address_allocation" {
  description = "The private IP address allocation method"
  type        = string
  default     = "Dynamic"
}

variable "vpn_client_address_space" {
  description = "Address space used for VPN clients"
  type        = string
}

variable "pip_allocation_method" {
  description = "The public IP address allocation method"
  type        = string
  default     = "Static"
}

variable "pip_sku" {
  description = "SKU for the public IP address"
  type        = string
  default     = "Standard"
}

variable "vpn_auth_types" {
  description = "Authentication types for the VPN client configuration"
  type        = list(string)
}

variable "vpn_client_protocols" {
  description = "VPN Client Protocol"
  type        = list(string)
}

variable "aad_tenant" {
  description = "Entra ID Tenant ID URL. Tenant ID prefixed with https://login.microsoftonline.com/"
  type        = string
}

variable "aad_issuer" {
  description = "URL of the Azure Active Directory (AAD) Secure Token Service (STS) endpoint for Microsoft Entra ID (formerly Azure AD) authentication with the Microsoft-registered App ID."
  type        = string
}

variable "aad_audience" {
  description = "# Microsoft Entra ID (formerly Azure AD) authentication with the Microsoft-registered App ID."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for the VPN gateway"
  type        = string
}