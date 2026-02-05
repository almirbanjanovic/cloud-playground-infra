#------------------------------------------------------------------------------------------------------------------------------
# Configuration
# All naming follows Microsoft Cloud Adoption Framework conventions:
# https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
#------------------------------------------------------------------------------------------------------------------------------
locals {
  # Base identifiers
  workload = "kaito"
  env      = "dev"
  location = "centralus"

  # Azure resource names (CAF abbreviations)
  # https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
  cluster_name = "aks-${local.workload}-${local.env}-${local.location}"

  # AKS configuration
  cluster_version        = "1.34.2"
  default_nodepool_name  = "system"
  default_nodepool_vm    = "Standard_D2s_v3"
  kaito_nodepool_vm      = "Standard_D16s_v5"

  # Kubernetes resource names
  kaito_namespace    = "kaito"
  kaito_workspace    = "bloomz-workspace"
  kaito_service      = "bloomz-external"
  kaito_app_label    = "bloomz-560m"

  # Common tags
  common_tags = {
    Environment = local.env
    Workload    = local.workload
    ManagedBy   = "Terraform"
  }
}

data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------------------------------------------------------
# Step 1: Create AKS Cluster with KAITO enabled
#------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = local.location
  resource_group_name = var.resource_group_name
  dns_prefix          = local.cluster_name
  kubernetes_version  = local.cluster_version

  local_account_disabled    = false
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = local.default_nodepool_name
    temporary_name_for_rotation  = "systemtemp"
    vm_size                      = local.default_nodepool_vm
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 5
    only_critical_addons_enabled = true

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }

    tags = local.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable KAITO
  # See here for supported models: https://github.com/kaito-project/kaito/tree/main/presets/workspace/models
  ai_toolchain_operator_enabled = true

  tags = local.common_tags
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 2: Create namespace for KAITO workloads
#------------------------------------------------------------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "kaito" {
  metadata {
    name = local.kaito_namespace
  }

  depends_on = [azurerm_kubernetes_cluster.this]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 3: Deploy KAITO custom model workspace
#------------------------------------------------------------------------------------------------------------------------------
resource "kubernetes_manifest" "kaito_workspace" {
  manifest = yamldecode(
    templatefile(
      "${path.module}/../assets/kubernetes/kaito_custom_cpu_model.yaml",
      {
        name         = local.kaito_workspace
        namespace    = kubernetes_namespace_v1.kaito.metadata[0].name
        instanceType = local.kaito_nodepool_vm
        appLabel     = local.kaito_app_label
      }
    )
  )

  depends_on = [kubernetes_namespace_v1.kaito]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 4: Create LoadBalancer service for external access (no curl-pod needed)
#------------------------------------------------------------------------------------------------------------------------------
resource "kubernetes_manifest" "kaito_external" {
  manifest = yamldecode(
    templatefile(
      "${path.module}/../assets/kubernetes/kaito_external_service.yaml",
      {
        name       = local.kaito_service
        namespace  = kubernetes_namespace_v1.kaito.metadata[0].name
        appLabel   = local.kaito_app_label
        port       = 80
        targetPort = 5000
      }
    )
  )

  depends_on = [kubernetes_manifest.kaito_workspace]
}
