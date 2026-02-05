variable "resource_group_name" {
  description = "Name of the resource group where resources will be deployed"
  type        = string
}

variable "first_run" {
  description = "Set to true on first deployment (creates AKS only), then false to deploy Kubernetes resources"
  type        = bool
  default     = false
}