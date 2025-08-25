variable "tags" {
  type = map(string)
}

variable "base_name" {
  description = "Base name for resource group"
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