variable "resource_group_name" {
  description = "Name of the resource group where resources will be deployed. The resource group itself is NOT managed by Terraform; create it ahead of time with the Azure CLI."
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed. Must match the region of the pre-existing resource group."
  type        = string
  default     = "centralus"
}