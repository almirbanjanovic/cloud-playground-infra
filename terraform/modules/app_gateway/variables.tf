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

variable "subnet_id" {
  description = "App Gateway subnet ID"
  type        = string
}

variable "pip_allocation_method" {
  description = "The public IP address allocation method"
  type        = string
}

variable "pip_sku" {
  description = "SKU for the public IP address"
  type        = string
}

variable "min_capacity" {
  description = "Minimum capacity for the App Gateway autoscaling"
  type        = number
}

variable "max_capacity" {
  description = "Maximum capacity for the App Gateway autoscaling"
  type        = number
}

variable "managed_rules_rule_set_type" {
  description = "The type of the App Gateway managed rules rule set"
  type        = string
}

variable "managed_rules_rule_set_version" {
  description = "The version of the App Gateway managed rules rule set"
  type        = string
}

variable "sku_name" {
  description = "The SKU name for the App Gateway"
  type        = string
}

variable "sku_tier" {
  description = "The SKU tier for the App Gateway"
  type        = string
}

variable "waf_policy_enabled" {
  description = "Whether the WAF policy is enabled"
  type        = bool
}

variable "waf_policy_mode" {
  description = "The WAF policy mode"
  type        = string
}