variable "tags" {
  type = map(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "base_name" {
  description = "Base name"
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

variable "virtual_network_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "aks_node_subnet_id" {
  description = "ID of the subnet where the AKS nodes will be deployed"
  type        = string
}

variable "aks_pod_subnet_id" {
  description = "ID of the subnet where the AKS pods will be deployed"
  type        = string
}

variable "app_gateway_id" {
  description = "ID of the Application Gateway"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}

variable "aks_api_server_subnet_id" {
  description = "ID of the subnet where the AKS API server will be deployed"
  type        = string
}

variable "dns_zone_aks_id" {
  description = "ID of the DNS zone for the AKS cluster"
  type        = string
}

variable "aks_version" {
  description = "AKS cluster version"
  type        = string
}

variable "azure_policy_enabled" {
  description = "Flag to enable Azure Policy"
  type        = bool
}

variable "private_cluster_enabled" {
  description = "Flag to enable private cluster setting"
  type        = bool
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Flag to enable private cluster public FQDN"
  type        = bool
}

variable "api_server_vnet_integration_enabled" {
  description = "Flag to enable VNet integration for the AKS API server"
  type        = bool
}

variable "role_based_access_control_enabled" {
  description = "Flag to enable role-based access control"
  type        = bool
}

variable "azure_active_directory_role_based_access_control_managed" {
  description = "Flag to enable managed Azure Active Directory / Entra ID role-based access control"
  type        = bool
}

variable "azure_active_directory_role_based_access_control_azure_rbac_enabled" {
  description = "Flag to enable Azure RBAC for Azure Active Directory / Entra ID role-based access control"
  type        = bool
}

variable "local_account_disabled" {
  description = "Flag to enable or disable local account"
  type        = bool
}

variable "default_node_pool_name" {
  description = "Name of the default node pool"
  type        = string
}

variable "default_node_pool_temp_name" {
  description = "Temporary name of the default node pool"
  type        = string
}

variable "default_node_pool_vm_size" {
  description = "VM size of the default node pool"
  type        = string
}

variable "default_node_pool_enable_auto_scaling" {
  description = "Flag to enable auto-scaling for the default node pool"
  type        = bool
}

variable "default_node_pool_min_count" {
  description = "Minimum number of nodes for the default node pool"
  type        = number
}

variable "default_node_pool_max_count" {
  description = "Maximum number of nodes for the default node pool"
  type        = number
}

variable "default_node_pool_type" {
  description = "Type of the default node pool"
  type        = string
}

variable "default_node_pool_zones" {
  description = "Zones of the default node pool"
  type        = list(string)
}

variable "default_node_pool_upgrade_settings_drain_timeout_in_minutes" {
  description = "Drain timeout in minutes for the default node pool"
  type        = number
}

variable "default_node_pool_upgrade_settings_max_surge" {
  description = "Max surge for the default node pool"
  type        = string
}

variable "default_node_pool_upgrade_settings_node_soak_duration_in_minutes" {
  description = "Node soak duration in minutes for the default node pool"
  type        = number
}

variable "identity_type" {
  description = "Type of the identity for the AKS cluster"
  type        = string
}

variable "key_vault_secrets_provider_secret_rotation_enabled" {
  description = "Flag to enable secret rotation for the Key Vault"
  type        = bool
}

variable "key_vault_secrets_provider_secret_rotation_interval" {
  description = "Interval for secret rotation for the Key Vault"
  type        = string
}

variable "network_profile_network_plugin" {
  description = "Network plugin for the network profile"
  type        = string
}

variable "network_profile_service_cidr" {
  description = "Service CIDR for the network profile"
  type        = string
}

variable "network_profile_dns_service_ip" {
  description = "DNS service IP for the network profile"
  type        = string
}

variable "network_profile_outbound_type" {
  description = "Outbound type for the network profile"
  type        = string
}

variable "network_profile_network_policy" {
  description = "Network policy for the network profile"
  type        = string
}

variable "monitor_metrics_labels_allowed" {
  description = "Labels allowed for Prometheus monitoring metrics"
  type        = string
}

variable "monitor_metrics_annotations_allowed" {
  description = "Annotations allowed for Prometheus monitoring metrics"
  type        = string
}

variable "application_node_pool_name" {
  description = "Name of the application node pool"
  type        = string
}

variable "application_node_pool_vm_size" {
  description = "VM size of the application node pool"
  type        = string
}

variable "application_node_pool_enable_auto_scaling" {
  description = "Flag to enable auto-scaling for the application node pool"
  type        = bool
}

variable "application_node_pool_min_count" {
  description = "Minimum number of nodes for the application node pool"
  type        = number
}

variable "application_node_pool_max_count" {
  description = "Maximum number of nodes for the application node pool"
  type        = number
}

variable "application_node_pool_mode" {
  description = "Mode of the application node pool"
  type        = string
}

variable "application_node_pool_zones" {
  description = "Zones of the application node pool"
  type        = list(string)
}

variable "application_node_pool_upgrade_settings_max_surge" {
  description = "Max surge for the application node pool"
  type        = number
}

variable "training_node_pool_name" {
  description = "Name of the training node pool"
  type        = string
}

variable "training_node_pool_vm_size" {
  description = "VM size of the training node pool"
  type        = string
}

variable "training_node_pool_enable_auto_scaling" {
  description = "Flag to enable auto-scaling for the training node pool"
  type        = bool
}

variable "training_node_pool_min_count" {
  description = "Minimum number of nodes for the training node pool"
  type        = number
}

variable "training_node_pool_max_count" {
  description = "Maximum number of nodes for the training node pool"
  type        = number
}

variable "training_node_pool_mode" {
  description = "Mode of the training node pool"
  type        = string
}

variable "training_node_pool_zones" {
  description = "Zones of the training node pool"
  type        = list(string)
}

variable "training_node_pool_upgrade_settings_max_surge" {
  description = "Max surge for the training node pool"
  type        = number
}

variable "role_assignment_acr_pull" {
  description = "Role assignment for ACR pull"
  type        = string
}

variable "role_assignment_key_vault_reader" {
  description = "Role assignment for Key Vault reader"
  type        = string
}

variable "role_assignment_network_contributor" {
  description = "Role assignment for Network Contributor"
  type        = string
}

variable "role_assignment_private_dns_zone_contributor" {
  description = "Role assignment for Private DNS Zone Contributor"
  type        = string
}

variable "ml_extension_type" {
  description = "Type name of the machine learning extension"
  type        = string
}

variable "tenant_id" {
  description = "Tenant ID for Microsoft Entra for SafeTower"
  type        = string
}

variable "sku_tier" {
  description = "SKU tier for this Kubernetes Cluster"
  type        = string
  default     = "Free"
}

variable "node_os_upgrade_channel" {
  description = "The upgrade channel for this Kubernetes Cluster Nodes' OS Image"
  type        = string
  default     = "NodeImage"
}

variable "maintenance_window_node_os_frequency" {
  description = "The frequency of the maintenance window for this Kubernetes Cluster Nodes' OS Image"
  type        = string
  default     = "Weekly"
}

variable "maintenance_window_node_os_day_of_week" {
  description = "The day of the week for the maintenance window for this Kubernetes Cluster Nodes' OS Image"
  type        = string
  default     = "Saturday"
}

variable "maintenance_window_node_os_start_time" {
  description = "The start time for the maintenance window for this Kubernetes Cluster Nodes' OS Image"
  type        = string
  default     = "01:00"
}

variable "maintenance_window_node_os_utc_offset" {
  description = "The UTC offset for the maintenance window for this Kubernetes Cluster Nodes' OS Image"
  type        = string
  default     = "-05:00"
}

variable "maintenance_window_node_os_interval" {
  description = "The interval for the maintenance window for this Kubernetes Cluster Nodes' OS Image"
  type        = number
  default     = 1
}

variable "maintenance_window_node_os_duration" {
  description = "The duration for the maintenance window for this Kubernetes Cluster Nodes' OS Image"
  type        = number
  default     = 4
}