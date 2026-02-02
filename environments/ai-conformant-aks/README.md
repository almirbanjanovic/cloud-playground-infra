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

This environment’s `terraform/main.tf` provisions the following capabilities that map to the Kubernetes AI Conformance spec:

- **Kubernetes 1.34.2 AKS cluster** (AI Conformance requires Kubernetes 1.34+)
- **Gateway API enabled** (registers `ManagedGatewayAPIPreview` and enables `gatewayAPIEnabled` on the cluster)
- **Prometheus-compatible observability** via Azure Monitor
	- Azure Monitor Workspace + Data Collection Endpoint (DCE)
	- Data Collection Rule (DCR) streaming `Microsoft-PrometheusMetrics`
	- DCR/DCE associations to the AKS cluster
	- Prometheus recording rule groups for **node** and **Kubernetes** metrics

![Note](https://img.shields.io/badge/Note-red)

`main.tf` also creates a second node pool (`gpunp`) using a **D-series (CPU-only)** VM size. This is intentional for this **POC**, since GPU VM quota/availability can be hard to obtain in many subscriptions/regions. GPU-specific conformance items (GPU drivers/device plugins, DRA/GPU resource requests, and any gang-scheduling operators) are not installed by this Terraform.

## Resources

- [AKS AI Conformance Blog Post](https://blog.aks.azure.com/2025/12/05/kubernetes-ai-conformance-aks)
- [CNCF AI Conformance Repository](https://github.com/cncf/k8s-ai-conformance)
- [AKS AI/ML Documentation](https://learn.microsoft.com/azure/aks/ai-ml-overview)
