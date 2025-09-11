# variable "base_name" {
#   description = "Application/Solution name which will be used to derive names for all of your resources"
#   type        = string
# }

# variable "location" {
#   description = "Location in which resources will be created"
#   type        = string
# }

# variable "apim_sku" {
#   description = "The edition of Azure API Management to use. This must be an edition that supports VNET Integration. This selection can have a significant impact on consumption cost and 'Developer' is recommended for non-production use."
#   type = string
# }

# variable "apim_capacity" {
#   description = "The number of Azure API Management capacity units to provision. For Developer edition, this must equal 1."
#   type = string
#   default = "1"
# }

# variable "app_gateway_capacity" {
#   description = "The number of Azure Application Gateway capacity units to provision. This setting has a direct impact on consumption cost and is recommended to be left at the default value of 1"
#   type        = number
#   default     = 1
# }

# variable "vnet_address_prefix" {
#   description = "The address space (in CIDR notation) to use for the VNET to be deployed in this solution. If integrating with other networked components, there should be no overlap in address space."
#   type        = string
#   default     = "10.0.0.0/16"
# }

# variable "app_gateway_subnet_prefix" {
#   description = "The address space (in CIDR notation) to use for the subnet to be used by Azure Application Gateway. Must be contained in the VNET address space."
#   type        = string
#   default     = "10.0.0.0/24"
# }

# variable "apim_subnet_prefix" {
#   description = "The address space (in CIDR notation) to use for the subnet to be used by Azure API Management. Must be contained in the VNET address space."
#   type        = string
#   default     = "10.0.1.0/24"
# }

# variable "apim_publisher_name" {
#   description = "Descriptive name for publisher to be used in the portal"
#   type        = string
#   default     = "Contoso"
# }

# variable "apim_publisher_email" {
#   description = "Email address associated with publisher"
#   type        = string
#   default     = "api@contoso.com"
# }

# variable "public_ip_sku" {
#   description = "Public IP SKU"
#   type = object({
#     name = string
#     tier = string
#   })
#   default = {
#     name = "Standard"
#     tier = "Regional"
#   }
# }

# variable "functionSku" {
#   description = "Function app SKU"
#   type        = string
#   default     = "EP1"
# }

# variable "base_name" {
#   description = "Base name used for resource naming"
#   type        = string
# }

# variable "storageAccountName" {
#   description = "Storage account name"
#   type        = string
#   default     = lower("stor${var.base_name}")
# }

# variable "functionRuntime" {
#   description = "Function runtime"
#   type        = string
#   default     = "dotnet"
# }

# variable "appServicePlanName" {
#   description = "App Service plan name"
#   type        = string
#   default     = lower("asp-${var.base_name}")
# }

# variable "jumpboxVmUsername" {
#   description = "Jumphost virtual machine username"
#   type        = string
#   default     = "svradmin"
# }

# variable "jumpboxVmPassword" {
#   description = "Jumphost virtual machine password"
#   type        = string
#   sensitive   = true
#   validation {
#     condition     = length(var.jumpboxVmPassword) >= 8
#     error_message = "Password must be at least 8 characters long."
#   }
# }



variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}
