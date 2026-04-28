## What is KAITO?

[KAITO (Kubernetes AI Toolchain Operator)](https://github.com/kaito-project/kaito) is an operator that automates AI/ML model inference and tuning workloads on Kubernetes. On AKS, it ships as a managed add-on you turn on with a single flag.

KAITO handles the parts of "run a model on Kubernetes" that are otherwise tedious:

- **Node provisioning** — given an instance type, KAITO adds nodes to the cluster on demand via Karpenter-style `NodeClaim` CRDs.
- **Model lifecycle** — downloads weights, runs the inference server, exposes a standard HTTP API.
- **Preset models** — built-in support for popular open-source models (Llama, Mistral, Phi, Qwen, etc.) via a single field in a CRD.
- **Custom models** — bring your own from HuggingFace, Azure Blob, Azure Files, or Azure ML.

## When to use KAITO vs Microsoft Foundry

| Consideration | KAITO | Microsoft Foundry |
|---------------|-------|------------------|
| Service model | You manage the cluster, KAITO manages the workload | Fully managed inference endpoints |
| Model selection | Anything from HuggingFace or your own storage | Curated catalog with regional limits |
| Data sovereignty | Stays in your cluster/network | Sent to Microsoft-managed endpoints |
| Cost model | Pay for VM compute | Pay-per-token or provisioned throughput |
| Compliance | Easier for strict regulatory regimes | Depends on service certifications |

**Use KAITO when** you need data isolation, full control over the model and runtime, or predictable compute-based pricing.

**Use Microsoft Foundry when** you want zero infrastructure to manage, need access to proprietary models like GPT-4o, or prefer pay-per-token billing.

## What you'll do in this workshop

In your own Azure subscription, you will:

1. Bootstrap a resource group and a storage account for Terraform state.
2. Use Terraform to deploy an AKS cluster with the KAITO add-on enabled, plus a `Workspace` custom resource that runs the small **`bigscience/bloomz-560m`** model on a CPU node.
3. Inspect the resulting cluster, pod, logs, and the auto-created LoadBalancer.
4. Call the model's HTTP inference API.
5. Tear everything back down.

The workshop uses a **CPU model on purpose** — no GPU quota required, so anyone with a fresh Azure subscription can complete it.
