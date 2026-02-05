# KAITO on AKS

This environment demonstrates running [KAITO (Kubernetes AI Toolchain Operator)](https://github.com/kaito-project/kaito) on AKS as a simple POC/MVP.

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
| **Data sovereignty** | Models run in your cluster, data never leaves your network | Data sent to Microsoft-managed endpoints |
| **Cost model** | Pay for VM compute only, no per-token charges | Pay-per-token or provisioned throughput |
| **Customization** | Full control over inference parameters, batching, quantization | Limited to provider-exposed options |
| **Latency** | In-cluster inference, minimal network hops | Network round-trip to external endpoint |
| **Compliance** | Easier to meet strict regulatory requirements (HIPAA, FedRAMP, etc.) | Depends on service compliance certifications |
| **Model selection** | Any HuggingFace or custom model | Curated catalog of supported models |

**Use KAITO when**: You need data to stay in your environment, want predictable costs at scale, require custom model configurations, or have strict compliance requirements.

**Use Microsoft Foundry when**: You want managed infrastructure, need access to proprietary models (GPT-4, Claude), prefer pay-per-use pricing, or don't want to manage GPU infrastructure.

### Architecture

![KAITO Architecture](https://raw.githubusercontent.com/kaito-project/kaito/main/website/static/img/arch.png)

KAITO follows the classic Kubernetes CRD/controller pattern. Its major components are:

- **Workspace controller** - Reconciles the Workspace custom resource, triggers node provisioning via NodeClaim CRDs, and creates inference/tuning workloads based on model preset configurations
- **Node provisioner controller (gpu-provisioner)** - Uses Karpenter-core NodeClaim CRD to integrate with Azure Resource Manager APIs, automatically adding GPU nodes to AKS clusters

*Source: [KAITO GitHub](https://github.com/kaito-project/kaito)*

KAITO is enabled on this cluster via `ai_toolchain_operator_enabled = true` in Terraform.

## Infrastructure Overview

The Terraform configuration (`terraform/main.tf`) provisions:

- **AKS Cluster** - Kubernetes 1.31 with KAITO enabled
- **KAITO Workspace** - Custom model deployment (bigscience/bloomz-560m)
- **LoadBalancer Service** - External access to the inference endpoint

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
         │ HTTP Request
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  Azure Load Balancer (Public IP)                                             │
└──────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  AKS Cluster (kaito namespace)                                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  kaito-external Service (LoadBalancer)                               │  │
│    │  Port: 80 -> 5000                                                    │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                   │                                                          │
│                   ▼                                                          │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  bloomz-workspace Pod (KAITO Inference)                              │  │
│    │  ├─ Model: bigscience/bloomz-560m                                    │  │
│    │  ├─ Runtime: HuggingFace Accelerate + PyTorch                        │  │
│    │  └─ Endpoints: /chat, /health, /metrics                              │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Deployment

### Prerequisites

- Azure subscription with sufficient VM quota
- Terraform 1.x installed
- Azure CLI authenticated (`az login`)

### Deploy

```bash
cd environments/kaito-on-aks/terraform
terraform init
terraform apply
```

### Get External IP

After deployment, get the LoadBalancer external IP:

```bash
kubectl get svc bloomz-external -n kaito -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Or via Terraform output:

```bash
terraform output get_external_ip_command
```

## Testing the Model

Once deployed, you can test the inference endpoint directly from your machine using curl:

**1. Set the external IP:**

```bash
# Get the external IP
KAITO_IP=$(kubectl get svc bloomz-external -n kaito -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
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
      "max_length": 64,
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
      "max_length": 64,
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
      "max_length": 64,
      "do_sample": false
    }
  }'
```

**Request Parameters:**

| Parameter | Description |
|-----------|-------------|
| `prompt` | The input text/question for the model |
| `return_full_text` | If `false`, returns only the generated text (not the prompt) |
| `generate_kwargs.max_length` | Maximum number of tokens to generate |
| `generate_kwargs.do_sample` | If `false`, uses greedy decoding (deterministic). If `true`, uses sampling (more creative). |

## Model Details

This POC uses **bigscience/bloomz-560m**, a small multilingual instruction-tuned model (~2.2GB). It runs on CPU for simplicity (no GPU quota required).

| Setting | Value |
|---------|-------|
| Model | bigscience/bloomz-560m |
| VM Size | Standard_D4s_v3 (4 vCPU, 16GB RAM) |
| Precision | float32 (CPU) |
| Port | 5000 |

## Custom Model Manifests

For more advanced deployments, see the example manifests in `assets/kubernetes/`:

| Manifest | Use Case |
|----------|----------|
| `kaito_custom_cpu_model.yaml` | Base template for public HuggingFace models |
| `kaito_option1_hf_private.yaml` | Private/gated HuggingFace models with HF_TOKEN |
| `kaito_option2_azure_volume.yaml` | Models pre-loaded on Azure Blob/Files storage |
| `kaito_option3_init_container_blob.yaml` | Download from Azure Blob at startup |
| `kaito_option4_azureml.yaml` | Download from Azure ML Model Registry |

## Resources

- [KAITO GitHub Repository](https://github.com/kaito-project/kaito)
- [KAITO Supported Models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models)
- [AKS AI/ML Documentation](https://learn.microsoft.com/azure/aks/ai-ml-overview)
