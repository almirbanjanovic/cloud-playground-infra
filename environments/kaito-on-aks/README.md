# KAITO on AKS

This environment demonstrates running [KAITO (Kubernetes AI Toolchain Operator)](https://github.com/kaito-project/kaito) on AKS as a simple POC/MVP.

## Table of Contents

- [What is KAITO?](#what-is-kaito)
  - [KAITO vs Microsoft Foundry](#kaito-vs-microsoft-foundry)
  - [Architecture](#architecture)
- [KAITO Preset Models](#kaito-preset-models)
- [Custom Model Manifests](#custom-model-manifests)
- [Infrastructure Overview](#infrastructure-overview)
  - [POC Model Details](#poc-model-details)
  - [Architecture Diagram](#architecture-diagram)
- [Configure kubectl](#configure-kubectl)
- [Testing the Model](#testing-the-model)
  - [Testing with LoadBalancer](#testing-with-loadbalancer)
  - [Testing without LoadBalancer](#testing-without-loadbalancer)
- [Resources](#resources)

## What is KAITO?

[KAITO (Kubernetes AI Toolchain Operator)](https://github.com/kaito-project/kaito) is an operator that automates AI/ML model inference and tuning workloads in Kubernetes. It simplifies running AI/ML inference by:

- **Automatic node provisioning** - Spins up GPU/CPU nodes based on model requirements
- **Model lifecycle management** - Downloads weights, manages inference server lifecycle
- **Preset models** - Built-in support for popular models (Llama, Mistral, Falcon, Phi, etc.)
- **Custom models** - Deploy your own models from HuggingFace, Azure Blob Storage, Azure Files, or Azure ML Model Registry
- **OpenAI-compatible API** - Provides a standard interface for inference calls

### KAITO vs Microsoft Foundry

You might wonder: why use KAITO when [Microsoft Foundry](https://ai.azure.com) offers thousands of models for inference?

| Consideration | KAITO | Microsoft Foundry |
|---------------|-------|------------------|
| **Service model** | PaaS - you manage cluster and model deployments | PaaS - you consume models via APIs |
| **Model selection** | Full control - any model from HuggingFace, Azure Blob/Files, Azure ML Registry, or private registries | Curated catalog with regional availability limitations (not all models available in all regions) |
| **Compliance** | Easier to meet strict regulatory requirements (HIPAA, FedRAMP, etc.) | Depends on service compliance certifications |
| **Data sovereignty** | Models run in your cluster, data never leaves your network | Data sent to Microsoft-managed endpoints |
| **Cost model** | Pay for VM compute only, no per-token charges | Pay-per-token or provisioned throughput |
| **Customization** | Full control over inference parameters, batching, quantization | Limited to provider-exposed options |
| **Latency** | In-cluster inference, minimal network hops | Network round-trip to external endpoint |



**Use KAITO when**: You need data to stay in your environment, want predictable costs at scale, require custom model configurations, or have strict compliance requirements.

**Use Microsoft Foundry when**: You want managed infrastructure, need access to proprietary models (GPT-4, Claude), prefer pay-per-use pricing, or don't want to manage GPU infrastructure.

### Architecture

![KAITO Architecture](https://raw.githubusercontent.com/kaito-project/kaito/main/website/static/img/arch.png)

KAITO follows the classic Kubernetes CRD/controller pattern. Its major components are:

- **Workspace controller** - Reconciles the Workspace custom resource, triggers node provisioning via NodeClaim CRDs, and creates inference/tuning workloads based on model preset configurations
- **Node provisioner controller (gpu-provisioner)** - Uses Karpenter-core NodeClaim CRD to integrate with Azure Resource Manager APIs, automatically adding GPU nodes to AKS clusters

*Source: [KAITO GitHub](https://github.com/kaito-project/kaito)*

KAITO is enabled on this cluster via `ai_toolchain_operator_enabled = true` in Terraform.

## KAITO Preset Models

KAITO includes built-in support for popular open-source models that can be deployed with minimal configuration. Instead of defining a custom inference template, you simply specify the preset name in your workspace manifest.

**Note:** Preset models require GPU-enabled node pools. Ensure your Azure subscription has sufficient GPU quota.

| Model Family | Examples |
|--------------|----------|
| DeepSeek | deepseek-r1 |
| Falcon | falcon-7b, falcon-40b |
| Gemma 3 | gemma-3-4b, gemma-3-12b, gemma-3-27b |
| Llama 3 | llama-3-8b, llama-3-70b, llama-3.1-8b, llama-3.1-70b, llama-3.1-405b |
| Mistral | mistral-7b, mistral-nemo-12b, mistral-large-2-123b |
| Phi 3 | phi-3-mini, phi-3-medium |
| Phi 4 | phi-4 |
| Qwen | qwen-2.5-7b, qwen-2.5-72b, qwen-2.5-coder-32b |

See the full list: [KAITO Supported Models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models)

An example preset manifest is available at `assets/kubernetes/kaito_preset_model.yaml`.

## Custom Model Manifests

For more advanced deployments, see the example manifests in `assets/kubernetes/`:

| Manifest | Use Case |
|----------|----------|
| `kaito_custom_cpu_model.yaml` | Base template for public HuggingFace models |
| `kaito_option1_hf_private.yaml` | Private/gated HuggingFace models with HF_TOKEN |
| `kaito_option2_azure_volume.yaml` | Models pre-loaded on Azure Blob/Files storage |
| `kaito_option3_init_container_blob.yaml` | Download from Azure Blob at startup |
| `kaito_option4_azureml.yaml` | Download from Azure ML Model Registry |

## Infrastructure Overview

The Terraform configuration (`terraform/main.tf`) provisions:

- **AKS Cluster** - Kubernetes 1.31 with KAITO enabled
- **Kubernetes Namespace** - `kaito-custom-cpu-inference` for isolating KAITO workloads
- **KAITO Workspace** - Custom model deployment (bigscience/bloomz-560m) with `kaito.sh/enablelb: "True"` annotation for automatic LoadBalancer creation

> **Note:** The `kaito.sh/enablelb` annotation automatically creates a LoadBalancer service with a public IP. This is for **testing only** and is NOT recommended for production. For production, use an Ingress Controller to safely expose the service.

### POC Model Details

This POC uses [**bigscience/bloomz-560m**](https://huggingface.co/bigscience/bloomz-560m), a small multilingual instruction-tuned model (~2.2GB). It runs on CPU for simplicity (no GPU quota required).

| Setting | Value |
|---------|-------|
| Model | bigscience/bloomz-560m |
| VM Size | Standard_D16s_v5 (16 vCPU, 64GB RAM) |
| Precision | float32 (CPU) |
| Port | 5000 |

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              KAITO on AKS                                    │
└──────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────┐
  │   Client    │  curl -X POST http://<EXTERNAL-IP>/chat
  │  (External) │  -d '{"prompt": "What is cloud computing?"}'
  └──────┬──────┘
         │
         │ HTTP Request (port 80)
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  AKS Cluster (kaito-custom-cpu-inference namespace)                          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  bloomz-560m-workspace Service (LoadBalancer via kaito.sh/enablelb)  │  │
│    │  Creates Azure Load Balancer with Public IP                          │  │
│    │  Port: 80 -> 5000                                                    │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                   │                                                          │
│                   ▼                                                          │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  bloomz-560m-workspace Pod (KAITO Inference)                         │  │
│    │  ├─ Model: bigscience/bloomz-560m                                    │  │
│    │  ├─ Runtime: HuggingFace Accelerate + PyTorch                        │  │
│    │  └─ Endpoints: /chat, /health, /metrics                              │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Configure kubectl

After deployment, configure kubectl to connect to your AKS cluster:

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

Verify connection:

```bash
kubectl get nodes
```

## Testing the Model

### Testing with LoadBalancer

When the `kaito.sh/enablelb: "True"` annotation is enabled, you can test the inference endpoint directly from your machine using curl:

**1. Set the external IP:**

```bash
# Get the external IP (service name matches workspace name)
KAITO_IP=$(kubectl get svc bloomz-560m-workspace -n kaito-custom-cpu-inference -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "KAITO endpoint: http://$KAITO_IP"
```

**2. Check health:**

```bash
curl http://$KAITO_IP/health
```

**3. Check the API schema:**

```bash
curl -s http://$KAITO_IP/openapi.json | head
```

**4. Sample prompts:**

```bash
# Question answering
curl --max-time 60 -X POST http://$KAITO_IP/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What sport should I play in rainy weather?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'

# Factual question
curl --max-time 60 -X POST http://$KAITO_IP/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Is a tomato a fruit or a vegetable?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'

# Brief definition
curl --max-time 60 -X POST http://$KAITO_IP/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Answer briefly: What is cloud computing?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'
```

**Request Parameters:**

| Parameter | Description |
|-----------|-------------|
| `prompt` | The input text/question for the model |
| `return_full_text` | If `false`, returns only the generated text (not the prompt) |
| `generate_kwargs.max_new_tokens` | Maximum number of new tokens to generate |
| `generate_kwargs.do_sample` | If `false`, uses greedy decoding (deterministic). If `true`, uses sampling (more creative). |

### Testing Without LoadBalancer

If the `kaito.sh/enablelb` annotation is commented out in the manifest, you can still test by running a curl pod inside the cluster:

```bash
# Start an interactive curl pod
kubectl run curl-debug \
  -n kaito-custom-cpu-inference \
  -it --restart=Never \
  --image=curlimages/curl \
  -- sh

# Inside the pod, call the service using cluster DNS
curl http://bloomz-560m-workspace:80/health

curl -X POST http://bloomz-560m-workspace:80/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is cloud computing?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'

# Exit and delete the pod when done
exit
kubectl delete pod curl-debug -n kaito-custom-cpu-inference
```

## Resources

- [KAITO GitHub Repository](https://github.com/kaito-project/kaito)
- [KAITO Supported Models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models)
- [AKS AI/ML Documentation](https://learn.microsoft.com/azure/aks/ai-ml-overview)
