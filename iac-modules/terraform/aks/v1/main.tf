#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {
  name = "aks-${var.base_name}-${var.environment}-${var.location}"
}

#------------------------------------------------------------------------------------------------------------------------------
# Azure Kubernetes Service (AKS) Cluster
#------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "this" {
  name                = "identity-${local.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_kubernetes_cluster" "this" {
  name                    = local.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  kubernetes_version      = var.aks_version
  azure_policy_enabled    = var.azure_policy_enabled
  sku_tier                = var.sku_tier
  node_os_upgrade_channel = var.node_os_upgrade_channel

  dns_prefix = local.name

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = var.azure_active_directory_role_based_access_control_azure_rbac_enabled
  }

  role_based_access_control_enabled = var.role_based_access_control_enabled

  default_node_pool {
    name                        = var.default_node_pool_name
    temporary_name_for_rotation = var.default_node_pool_temp_name
    vm_size                     = var.default_node_pool_vm_size
    vnet_subnet_id              = var.aks_node_subnet_id
    pod_subnet_id               = var.aks_pod_subnet_id
    auto_scaling_enabled        = var.default_node_pool_enable_auto_scaling
    min_count                   = var.default_node_pool_min_count
    max_count                   = var.default_node_pool_max_count
    type                        = var.default_node_pool_type
    zones                       = var.default_node_pool_zones
    orchestrator_version        = var.aks_version

    # Enabling this option will taint default node pool with "CriticalAddonsOnly=true:NoSchedule". 
    # This will designate this as a system node pool and prevent user application pods from running on it.
    # See this for more info: https://learn.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli#system-and-user-node-pools
    only_critical_addons_enabled = true

    upgrade_settings {
      drain_timeout_in_minutes      = var.default_node_pool_upgrade_settings_drain_timeout_in_minutes
      max_surge                     = var.default_node_pool_upgrade_settings_max_surge
      node_soak_duration_in_minutes = var.default_node_pool_upgrade_settings_node_soak_duration_in_minutes
    }

    tags = var.tags
  }

  identity {
    type = var.identity_type
    identity_ids = [
      azurerm_user_assigned_identity.this.id
    ]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.this.client_id
    object_id                 = azurerm_user_assigned_identity.this.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  }

  network_profile {
    network_plugin = var.network_profile_network_plugin
    network_policy = var.network_profile_network_policy
    service_cidr   = var.network_profile_service_cidr
    dns_service_ip = var.network_profile_dns_service_ip
    outbound_type  = var.network_profile_outbound_type
  }

  monitor_metrics {
    labels_allowed      = var.monitor_metrics_labels_allowed
    annotations_allowed = var.monitor_metrics_annotations_allowed
  }

  maintenance_window_node_os {
    frequency   = var.maintenance_window_node_os_frequency
    day_of_week = var.maintenance_window_node_os_day_of_week
    start_time  = var.maintenance_window_node_os_start_time
    utc_offset  = var.maintenance_window_node_os_utc_offset
    interval    = var.maintenance_window_node_os_interval
    duration    = var.maintenance_window_node_os_duration

  }

  tags = var.tags

  depends_on = [
    azurerm_user_assigned_identity.this,
    azurerm_role_assignment.uami_managed_identity_operator,
    azurerm_role_assignment.aks_api_server_subnet,
    azurerm_role_assignment.aks_node_subnet,
    azurerm_role_assignment.aks_pod_subnet,
    azurerm_role_assignment.aks_private_dns_zone
  ]
}


resource "azurerm_kubernetes_cluster_node_pool" "application" {
  name                        = var.application_node_pool_name
  temporary_name_for_rotation = "apptemp"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.this.id
  vm_size                     = var.application_node_pool_vm_size
  vnet_subnet_id              = var.aks_node_subnet_id
  pod_subnet_id               = var.aks_pod_subnet_id
  auto_scaling_enabled        = var.application_node_pool_enable_auto_scaling
  min_count                   = var.application_node_pool_min_count
  max_count                   = var.application_node_pool_max_count
  mode                        = var.application_node_pool_mode
  zones                       = var.application_node_pool_zones
  orchestrator_version        = var.aks_version

  upgrade_settings {
    max_surge = var.application_node_pool_upgrade_settings_max_surge
  }

  tags = var.tags
}

#------------------------------------------------------------------------------------------------------------------------------
# Role assignments
#------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "uami_managed_identity_operator" {
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = "Managed Identity Operator"
  scope                = azurerm_user_assigned_identity.this.id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = var.role_assignment_acr_pull
  scope                = var.acr_id

  depends_on = [azurerm_kubernetes_cluster.this]
}


# resource "azurerm_role_assignment" "aks_acr_pull" {
#   principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
#   role_definition_name = var.role_assignment_acr_pull
#   scope                = var.acr_id

#   depends_on = [azurerm_kubernetes_cluster.this]
# }


# resource "azurerm_role_assignment" "aks_key_vault_read" {
#   #principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
#   principal_id         = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
#   role_definition_name = var.role_assignment_key_vault_reader
#   scope                = var.key_vault_id

#   depends_on = [azurerm_kubernetes_cluster.this]
# }

resource "azurerm_role_assignment" "aks_node_subnet" {
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = var.role_assignment_network_contributor
  scope                = var.aks_node_subnet_id
}

resource "azurerm_role_assignment" "aks_pod_subnet" {
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = var.role_assignment_network_contributor
  scope                = var.aks_pod_subnet_id
}

resource "azurerm_role_assignment" "aks_virtual_network_contributor" {
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  role_definition_name = var.role_assignment_network_contributor
  scope                = var.virtual_network_id

  depends_on = [azurerm_kubernetes_cluster.this]
}