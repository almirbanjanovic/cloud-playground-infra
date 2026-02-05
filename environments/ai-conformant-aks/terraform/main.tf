#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {

  prefix = "aks-ai-conformant-dev"

  location = "centralus"

  cluster_name                     = "${local.prefix}-${local.location}"
  cluster_version                  = "1.34.2"
  cluster_default_nodepool_vm_size = "Standard_Ds_v3"
  gpu_nodepool                     = "gpunp"
  gpu_nodepool_vm_size             = "Standard_D16s_v5" 
  kaito_vm_size                    = "Standard_D16s_v5" # Intel Emerald Rapids with local NVMe
  default_nodepool                 = "default"
  azure_monitor_workspace_name     = "amw-${local.prefix}-${local.location}"
  aks_dce_name                     = "aks-dce-${local.prefix}-${local.location}"
  amdcr_name                       = "amdcr-prometheus-${local.prefix}-${local.location}"
  amdca_name                       = "amdca-${local.prefix}-${local.location}"

  # Common tags
  common_tags = {
    ManagedBy = "Terraform"
    Purpose   = "AI-Conformant-AKS"
  }
}

data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------------------------------------------------------
# Step 1: Register the ManagedGPUExperiencePreview feature, Subscription Feature Registration (SFR)
# Equivalent to running: az feature register --namespace Microsoft.ContainerService --name ManagedGPUExperiencePreview
#
# Required for: AI Conformance (GPU workloads)
# Optional for: KAITO (only needed if using GPU-based models; CPU-only models don't require this)
#------------------------------------------------------------------------------------------------------------------------------

resource "azapi_resource_action" "managed_gpu_experience_preview_sfr" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGPUExperiencePreview"
  method                 = "PUT"
  body                   = {}
  response_export_values = ["*"]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 2: Register the ManagedGatewayAPIPreview feature
# Equivalent to running: az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
#
# Required for: AI Conformance (advanced traffic routing for inference endpoints)
# Optional for: KAITO (not required, but useful for canary deployments and A/B testing models)
#------------------------------------------------------------------------------------------------------------------------------

resource "azapi_resource_action" "managed_gateway_api_preview_sfr" {
  type                   = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.ContainerService/subscriptionFeatureRegistrations/ManagedGatewayAPIPreview"
  method                 = "PUT"
  body                   = {}
  response_export_values = ["*"]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 3: Wait for feature registration to propagate (using time_sleep as a simple approach)
#
# Required for: Both (ensures feature flags are active before cluster creation)
#------------------------------------------------------------------------------------------------------------------------------

resource "time_sleep" "wait_for_features" {
  depends_on = [
    azapi_resource_action.managed_gpu_experience_preview_sfr,
    azapi_resource_action.managed_gateway_api_preview_sfr
  ]
  create_duration = "60s"
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 4: Create AKS Cluster with Kubernetes 1.34
#
# Required for: Both
#   - AI Conformance: Requires Kubernetes 1.34+ for DRA, Gang Scheduling, and GPU features
#   - KAITO: Enabled via ai_toolchain_operator_enabled = true
#   - Istio: Optional, enables service mesh for mTLS and traffic management
#   - Workload Identity: Optional, enables secure pod-to-Azure authentication (used by KAITO custom model options)
#------------------------------------------------------------------------------------------------------------------------------


resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = local.location
  resource_group_name = var.resource_group_name
  dns_prefix          = local.cluster_name
  kubernetes_version  = local.cluster_version

  # Enable local admin account for kube_admin_config
  local_account_disabled = false

  # AKS cannot disable OIDC issuer once enabled; keep it explicitly on to avoid drift.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = local.default_nodepool
    temporary_name_for_rotation = "defaulttemp"
    vm_size                     = "Standard_D2s_v3"
    auto_scaling_enabled        = "true"
    min_count                   = 1
    max_count                   = 5
    type                        = "VirtualMachineScaleSets"
    zones                       = ["1", "2", "3"] # Keep this for HA
    orchestrator_version        = local.cluster_version

    # Enabling this option will taint default node pool with "CriticalAddonsOnly=true:NoSchedule". 
    # This will designate this as a system node pool and prevent user application pods from running on it.
    # See this for more info: https://learn.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli#system-and-user-node-pools
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

  monitor_metrics {
    labels_allowed      = "true"  # Enable to collect labels for filtering. Useful for filtering by app, nodepool, etc.
    annotations_allowed = "false" # Disable, not needed at this time.
  }

  service_mesh_profile {
    mode      = "Istio"
    revisions = ["asm-1-28"] # Specify the ASM revision to use (https://learn.microsoft.com/en-us/azure/aks/istio-about)

    # Pre-provisioned ingress gateways are NOT needed when using Gateway API.
    # Gateway API with gatewayClassName: istio uses "automated deployment" - Istio creates
    # new gateway pods dynamically when you apply a Gateway CR.
    #
    # Only enable these if you need Istio-native Gateway/VirtualService CRDs instead of Gateway API.
    internal_ingress_gateway_enabled = false
    external_ingress_gateway_enabled = false
  }

  # Enable KAITO
  # See here for supported models: https://github.com/kaito-project/kaito/tree/main/presets/workspace/models
  ai_toolchain_operator_enabled = true

  tags = local.common_tags

  depends_on = [
    time_sleep.wait_for_features
  ]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 5: Gateway API Gateway - Configures the ingress gateway to accept traffic
# Uses Kubernetes-standard Gateway API (required for AI Conformance) instead of Istio-native CRDs.
#
# IMPORTANT: With gatewayClassName: istio, Istio's "automated deployment" model creates NEW gateway
# pods dynamically (named <gateway-name>-istio). This is DIFFERENT from the AKS-managed ingress
# gateways (aks-istio-ingressgateway-external) which are used with Istio-native Gateway CRDs.
#
# The automated model creates: Deployment, Service (LoadBalancer), HPA, and PDB for the gateway.
#
# Required for: AI Conformance (Gateway API is part of the conformance spec)
# Optional for: KAITO (provides external access to inference endpoints)
#
# Docs: https://learn.microsoft.com/en-us/azure/aks/istio-gateway-api
#------------------------------------------------------------------------------------------------------------------------------
resource "kubernetes_manifest" "gateway_api_gateway" {
  manifest = yamldecode(
    templatefile(
      "${path.module}/../assets/kubernetes/gateway_api_gateway.yaml",
      {
        name      = "inference-gateway"
        namespace = kubernetes_namespace_v1.custom_cpu_model.metadata[0].name
        port      = 80
      }
    )
  )

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azapi_update_resource.gateway_api,
    kubernetes_namespace_v1.custom_cpu_model
  ]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 6: Add GPU Node Pool
#
# Required for: AI Conformance (GPU workloads, DRA, GPU autoscaling)
# Optional for: KAITO (required for GPU models, not needed for CPU-only inference like this POC)
# Note: This POC uses D-series (CPU-only) VMs. For production GPU workloads, use NC/ND-series SKUs.
#------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                        = local.gpu_nodepool
  temporary_name_for_rotation = "gpunptemp"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.aks.id
  vm_size                     = local.gpu_nodepool_vm_size
  node_count                  = 1

  auto_scaling_enabled = true
  min_count            = 0
  max_count            = 3

  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }

  tags = merge(
    local.common_tags,
    {
      EnableManagedGPUExperience = "true"
    }
  )

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 7: Enable Prometheus metrics
#
# Required for: AI Conformance (observability requirement for GPU and cluster metrics)
# Optional for: KAITO (useful for monitoring inference workloads, but not required)
#------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_monitor_workspace" "this" {
  name                = local.azure_monitor_workspace_name
  location            = local.location
  resource_group_name = var.resource_group_name

  tags = local.common_tags
}

resource "azurerm_monitor_data_collection_endpoint" "aks_dce" {
  name                = local.aks_dce_name
  resource_group_name = var.resource_group_name
  location            = local.location
  kind                = "Linux"

  tags = local.common_tags
}

resource "azurerm_monitor_data_collection_rule" "this" {
  name                        = local.amdcr_name
  resource_group_name         = var.resource_group_name
  location                    = local.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks_dce.id

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.this.id
      name               = azurerm_monitor_workspace.this.name
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = [azurerm_monitor_workspace.this.name]
  }

  tags = local.common_tags

  depends_on = [azurerm_monitor_data_collection_endpoint.aks_dce]
}

# Associate to Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "amdcr_to_aks" {
  name                    = local.amdca_name
  target_resource_id      = azurerm_kubernetes_cluster.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.this.id

  depends_on = [azurerm_monitor_data_collection_rule.this]
}

# Associate to Data Collection Endpoint
resource "azurerm_monitor_data_collection_rule_association" "aks_dce_to_aks" {
  target_resource_id          = azurerm_kubernetes_cluster.aks.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks_dce.id

  depends_on = [azurerm_kubernetes_cluster.aks]
}
# Create Prometheus Rule Groups for Node and Kubernetes metrics
resource "azurerm_monitor_alert_prometheus_rule_group" "node" {
  name                = "NodeRecordingRulesRuleGroup-${local.cluster_name}"
  resource_group_name = var.resource_group_name
  location            = local.location
  cluster_name        = local.cluster_name
  description         = "Node Recording Rules Rule Group"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.this.id, azurerm_kubernetes_cluster.aks.id]

  rule {
    enabled    = true
    record     = "instance:node_num_cpu:sum"
    expression = <<EOF
count without (cpu, mode) (  node_cpu_seconds_total{job="node",mode="idle"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_cpu_utilisation:rate5m"
    expression = <<EOF
1 - avg without (cpu) (  sum without (mode) (rate(node_cpu_seconds_total{job="node", mode=~"idle|iowait|steal"}[5m])))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_load1_per_cpu:ratio"
    expression = <<EOF
(  node_load1{job="node"}/  instance:node_num_cpu:sum{job="node"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_memory_utilisation:ratio"
    expression = <<EOF
1 - (  (    node_memory_MemAvailable_bytes{job="node"}    or    (      node_memory_Buffers_bytes{job="node"}      +      node_memory_Cached_bytes{job="node"}      +      node_memory_MemFree_bytes{job="node"}      +      node_memory_Slab_bytes{job="node"}    )  )/  node_memory_MemTotal_bytes{job="node"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_vmstat_pgmajfault:rate5m"
    expression = <<EOF
rate(node_vmstat_pgmajfault{job="node"}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_seconds:rate5m"
    expression = <<EOF
rate(node_disk_io_time_seconds_total{job="node", device!=""}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_weighted_seconds:rate5m"
    expression = <<EOF
rate(node_disk_io_time_weighted_seconds_total{job="node", device!=""}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_receive_bytes_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_receive_bytes_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_transmit_bytes_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_transmit_bytes_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_receive_drop_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_transmit_drop_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (  rate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))
EOF
  }

  tags = local.common_tags

  depends_on = [azurerm_monitor_workspace.this]
}

resource "azurerm_monitor_alert_prometheus_rule_group" "k8s" {
  name                = "KubernetesRecordingRulesRuleGroup-${local.cluster_name}"
  resource_group_name = var.resource_group_name
  location            = local.location
  cluster_name        = local.cluster_name
  description         = "Kubernetes Recording Rules Rule Group"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.this.id, azurerm_kubernetes_cluster.aks.id]

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate"
    expression = <<EOF
sum by (cluster, namespace, pod, container) (  irate(container_cpu_usage_seconds_total{job="cadvisor", image!=""}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (  1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_working_set_bytes"
    expression = <<EOF
container_memory_working_set_bytes{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_rss"
    expression = <<EOF
container_memory_rss{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_cache"
    expression = <<EOF
container_memory_cache{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_swap"
    expression = <<EOF
container_memory_swap{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_requests"
    expression = <<EOF
kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_requests:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests"
    expression = <<EOF
kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_requests:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_limits"
    expression = <<EOF
kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_limits:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits"
    expression = <<EOF
kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~"Pending|Running"} == 1) )
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_limits:sum"
    expression = <<EOF
sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    label_replace(      kube_pod_owner{job="kube-state-metrics", owner_kind="ReplicaSet"},      "replicaset", "$1", "owner_name", "(.*)"    ) * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (      1, max by (replicaset, namespace, owner_name) (        kube_replicaset_owner{job="kube-state-metrics"}      )    ),    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "deployment"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="DaemonSet"},    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "daemonset"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="StatefulSet"},    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "statefulset"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="Job"},    "workload", "$1", "owner_name", "(.*)"  ))
EOF
    labels = {
      workload_type = "job"
    }
  }
  rule {
    enabled    = true
    record     = ":node_memory_MemAvailable_bytes:sum"
    expression = <<EOF
sum(  node_memory_MemAvailable_bytes{job="node"} or  (    node_memory_Buffers_bytes{job="node"} +    node_memory_Cached_bytes{job="node"} +    node_memory_MemFree_bytes{job="node"} +    node_memory_Slab_bytes{job="node"}  )) by (cluster)
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:node_cpu:ratio_rate5m"
    expression = <<EOF
sum(rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job="node"}) by (cluster, instance, cpu)) by (cluster)
EOF
  }

  tags = local.common_tags

  depends_on = [azurerm_monitor_workspace.this]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 8: Enable Gateway API
#
# Required for: AI Conformance (advanced traffic routing for AI inference endpoints)
# Optional for: KAITO (not required, but enables canary deployments and header-based routing)
#------------------------------------------------------------------------------------------------------------------------------

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
    azurerm_kubernetes_cluster.aks
  ]
}

#------------------------------------------------------------------------------------------------------------------------------
# Step 9: Deploy KAITO models via Terraform Kubernetes Provider
#
# Required for: KAITO
# Optional for: AI Conformance (KAITO is one of many AI operators supported by AI Conformance)
#------------------------------------------------------------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "custom_cpu_model" {
  metadata {
    name = "bloomz"
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

#------------------------------------------------------------------------------------------------------------------------------
# Gateway API HTTPRoute - Routes traffic from the Gateway to the KAITO service
# Uses Kubernetes-standard HTTPRoute (required for AI Conformance) instead of Istio VirtualService.
#
# Required for: AI Conformance (Gateway API routing is part of the conformance spec)
# Optional for: KAITO (provides external HTTP access to inference endpoint)
#------------------------------------------------------------------------------------------------------------------------------
resource "kubernetes_manifest" "gateway_api_httproute" {
  manifest = yamldecode(
    templatefile(
      "${path.module}/../assets/kubernetes/gateway_api_httproute.yaml",
      {
        name           = "kaito-httproute"
        namespace      = kubernetes_namespace_v1.custom_cpu_model.metadata[0].name
        gatewayName    = "inference-gateway"
        pathPrefix     = "/"
        backendService = "cpu-only-workspace"
        backendPort    = 80
        requestTimeout = "120s"
      }
    )
  )

  depends_on = [
    kubernetes_manifest.gateway_api_gateway,
    kubernetes_manifest.custom_model
  ]
}

resource "kubernetes_manifest" "custom_model" {
  manifest = yamldecode(
    templatefile(
      "${path.module}/../assets/kubernetes/kaito_custom_cpu_model.yaml",
      {
        name         = "cpu-only-workspace"
        namespace    = kubernetes_namespace_v1.custom_cpu_model.metadata[0].name
        instanceType = local.kaito_vm_size
        appLabel     = "bloomz-560m"
      }
    )
  )

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    kubernetes_namespace_v1.custom_cpu_model
  ]
}