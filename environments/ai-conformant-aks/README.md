# AI Conformant AKS Cluster

This environment provisions an AI-conformant Azure Kubernetes Service (AKS) cluster using Terraform.

## What is Kubernetes AI Conformance?

The [Kubernetes AI Conformance Program](https://github.com/cncf/k8s-ai-conformance) defines a standard set of capabilities, APIs, and configurations that a Kubernetes cluster must offer to reliably and efficiently run AI and ML workloads. AKS is among the first platforms certified for Kubernetes AI Conformance.

**Why it matters**: AI workloads have unique challenges around GPU driver compatibility, distributed training scheduling, and inference endpoint scaling. AI Conformance establishes a verified baseline ensuring predictable scaling, hardware optimization, workload portability, and ecosystem compatibility.

## Key AI Conformance Capabilities

- **Dynamic Resource Allocation (DRA)**: Flexible GPU resource requests with device-specific characteristics
- **Gateway API**: Advanced traffic routing for AI inference (canary deployments, header-based routing)
- **Gang Scheduling**: All-or-nothing pod scheduling for distributed training jobs
- **GPU Autoscaling**: Intelligent cluster and pod autoscaling based on GPU metrics
- **Observability**: GPU performance metrics and Prometheus-compatible monitoring
- **AI Operators**: Support for Kubernetes operators managing training jobs and model servers

## Infrastructure

This environment's `terraform/main.tf` provisions the following capabilities that map to the Kubernetes AI Conformance spec:

### Core AKS Configuration

- **Kubernetes 1.34.2 AKS cluster** (AI Conformance requires Kubernetes 1.34+)
- **Gateway API enabled** (registers `ManagedGatewayAPIPreview` and enables `gatewayAPIEnabled` on the cluster)
- **Workload Identity enabled** for secure pod-to-Azure-service authentication
- **OIDC Issuer enabled** for federated identity scenarios
- **Prometheus-compatible observability** via Azure Monitor
  - Azure Monitor Workspace + Data Collection Endpoint (DCE)
  - Data Collection Rule (DCR) streaming `Microsoft-PrometheusMetrics`
  - DCR/DCE associations to the AKS cluster
  - Prometheus recording rule groups for **node** and **Kubernetes** metrics

**Note**: `main.tf` also creates a second node pool (`gpunp`) using a **D-series (CPU-only)** VM size. This is intentional for this **POC**, since GPU VM quota/availability can be hard to obtain in many subscriptions/regions. GPU-specific conformance items (GPU drivers/device plugins, DRA/GPU resource requests, and any gang-scheduling operators) are not installed by this Terraform.

### KAITO (Kubernetes AI Toolchain Operator)

[KAITO](https://github.com/kaito-project/kaito) is enabled via `ai_toolchain_operator_enabled = true`. KAITO simplifies running AI/ML inference workloads on Kubernetes.

- Automatically provisioning GPU nodes based on model requirements
- Managing model weights and inference server lifecycle
- Supporting popular open-source models (Llama, Mistral, Falcon, Phi, etc.)

See the [KAITO supported models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models) for available presets.

### Istio Service Mesh

The cluster includes an **Istio-based service mesh** (`asm-1-28` revision) with:

- **External Ingress Gateway enabled**: Managed Istio ingress for north-south traffic (external clients → cluster)
- **mTLS and traffic management**: East-west traffic between services benefits from automatic mTLS, retries, timeouts, and circuit breaking

### Node Pools

| Pool | Purpose | VM Size | Scaling | Notes |
|------|---------|---------|---------|-------|
| `default` | System workloads | Standard_D2s_v3 | 2-5 nodes | Critical addons only, HA across 3 zones |
| `gpunp` | GPU/AI workloads | Standard_D16s_v5 | 1-3 nodes | Tagged with `EnableManagedGPUExperience=true` |

**Note**: The GPU node pool uses a **D-series (CPU-only)** VM size for this POC since GPU VM quota/availability can be limited. For production AI workloads, replace with an actual GPU SKU (e.g., `Standard_NC6s_v3`, `Standard_NVads_A10_v5`).

### Gateway API

Gateway API is enabled via the `ManagedGatewayAPIPreview` feature registration. This provides:

- Advanced traffic routing for AI inference endpoints
- Canary deployments with weighted routing
- Header-based routing for A/B testing models

### Prometheus Observability

Full Prometheus-compatible monitoring stack:

- **Azure Monitor Workspace** for metric storage
- **Data Collection Endpoint (DCE)** and **Data Collection Rule (DCR)** streaming `Microsoft-PrometheusMetrics`
- **Prometheus recording rule groups** for node and Kubernetes metrics (CPU, memory, disk I/O, network)

## Prerequisites

- Azure subscription with sufficient quota for the selected VM sizes
- Terraform 1.x installed
- Azure CLI authenticated (`az login`)
- For GPU workloads: Register for GPU VM quota in your region

## Resources

- [AKS AI Conformance Blog Post](https://blog.aks.azure.com/2025/12/05/kubernetes-ai-conformance-aks)
- [CNCF AI Conformance Repository](https://github.com/cncf/k8s-ai-conformance)
- [AKS AI/ML Documentation](https://learn.microsoft.com/azure/aks/ai-ml-overview)
- [KAITO GitHub Repository](https://github.com/kaito-project/kaito)
- [KAITO Supported Models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models)
- [Istio on AKS Documentation](https://learn.microsoft.com/azure/aks/istio-about)
