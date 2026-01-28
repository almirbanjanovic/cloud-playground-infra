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

This Terraform configuration provisions:

- Kubernetes 1.34+ (required for AI conformance)
- GPU-enabled node pools with managed GPU experience
- Azure Monitor integration for metrics and observability
- Cluster autoscaling for cost-effective GPU management

## Resources

- [AKS AI Conformance Blog Post](https://blog.aks.azure.com/2025/12/05/kubernetes-ai-conformance-aks)
- [CNCF AI Conformance Repository](https://github.com/cncf/k8s-ai-conformance)
- [AKS AI/ML Documentation](https://learn.microsoft.com/azure/aks/ai-ml-overview)
