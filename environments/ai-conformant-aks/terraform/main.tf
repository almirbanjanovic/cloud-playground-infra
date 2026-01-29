#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {
  # Naming convention
  prefix = "aks-ai-conformant-dev"
  
  # Hard-coded values
  location = "centralus"
  
  # Resource names
  cluster_name     = "${local.prefix}-${local.location}"
  gpu_nodepool     = "gpunp"
  default_nodepool = "default"
  
  # Common tags
  common_tags = {
    ManagedBy = "Terraform"
    Purpose   = "AI-Conformant-AKS"
  }
}

data "azurerm_client_config" "current" {}

# Step 1: Register the ManagedGPUExperiencePreview feature, Subscription Feature Registration (SFR)
resource "azapi_resource_action" "managed_gpu_experience_preview_sfr" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGPUExperiencePreview"
  method                 = "PUT"
  body = {}
  response_export_values = ["*"]
}

# Step 2: Register the ManagedGatewayAPIPreview feature
resource "azapi_resource_action" "managed_gateway_api_preview_sfr" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGatewayAPIPreview"
  method                 = "PUT"
  body                   = {}
  response_export_values = ["*"]
}

# Step 3: Wait for feature registration to propagate (using time_sleep as a simple approach)
resource "time_sleep" "wait_for_features" {
  depends_on = [
    azapi_resource_action.managed_gpu_experience_preview_sfr,
    azapi_resource_action.managed_gateway_api_preview_sfr
  ]
  create_duration = "60s"
}

# Step 4: Create AKS Cluster with Kubernetes 1.34
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = local.location
  resource_group_name = var.resource_group_name
  dns_prefix          = local.cluster_name
  kubernetes_version  = "1.34.0"

  default_node_pool {
    name                        = local.default_nodepool
    temporary_name_for_rotation = "temp"
    vm_size                     = "Standard_D2s_v3"
    auto_scaling_enabled        = "true"
    min_count                   = 2
    max_count                   = 5
    type                        = "VirtualMachineScaleSets"
    zones                       = ["1", "2", "3"]  # Keep this for HA
    orchestrator_version        = "1.34.0"

    # Enabling this option will taint default node pool with "CriticalAddonsOnly=true:NoSchedule". 
    # This will designate this as a system node pool and prevent user application pods from running on it.
    # See this for more info: https://learn.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli#system-and-user-node-pools
    only_critical_addons_enabled = true

    tags = local.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
    labels_allowed      = "true" # Enable to collect labels for filtering. Useful for filtering by app, nodepool, etc.
    annotations_allowed = "false" # Disable, not needed at this time.
  }

  tags = local.common_tags

  depends_on = [
    time_sleep.wait_for_features
    ]
}

# Step 6: Enable Istio Service Mesh
resource "azapi_update_resource" "istio" {
  type        = "Microsoft.ContainerService/managedClusters@2024-02-01"
  resource_id = azurerm_kubernetes_cluster.aks.id

  body = {
    properties = {
      serviceMeshProfile = {
        mode = "Istio"
        istio = {
          components = {
            ingressGateways = [
              {
                enabled = true
                mode    = "External"
              }
            ]
          }
        }
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

# Step 7: Enable Gateway API
resource "azapi_update_resource" "gateway_api" {
  type        = "Microsoft.ContainerService/managedClusters@2024-02-01"
  resource_id = azurerm_kubernetes_cluster.aks.id

  body = {
    properties = {
      networkProfile = {
        gatewayAPIEnabled = true
      }
    }
  }

  depends_on = [
    azapi_update_resource.istio
  ]
}