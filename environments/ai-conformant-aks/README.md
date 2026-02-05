# KAITO on AI-Conformant AKS

This environment demonstrates running [KAITO (Kubernetes AI Toolchain Operator)](https://github.com/kaito-project/kaito) on an AI-conformant AKS cluster.

## What is AI Conformance?

The [Kubernetes AI Conformance Program](https://github.com/cncf/k8s-ai-conformance) defines a standard set of capabilities that Kubernetes clusters need to reliably run AI/ML workloads. This includes GPU resource allocation, gang scheduling for distributed training, and observability for AI metrics. AKS is among the first platforms certified for AI Conformance.

For this POC, we use the AI-conformant cluster as the foundation for running KAITO workloads.

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

## Preset Model Manifests

KAITO offers preset models - pre-configured Workspace definitions for popular open-source models like Llama, Mistral, Falcon, and Phi. See [kaito_preset_model.yaml](assets/kubernetes/kaito_preset_model.yaml) for an example.

Full list of supported presets: [KAITO Supported Models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models)

## Custom Model Manifests

This environment includes several KAITO Workspace manifests for deploying custom models:

| Manifest | Use Case |
|----------|----------|
| [kaito_custom_cpu_model.yaml](assets/kubernetes/kaito_custom_cpu_model.yaml) | Base template for public HuggingFace models |
| [kaito_option1_hf_private.yaml](assets/kubernetes/kaito_option1_hf_private.yaml) | Private/gated HuggingFace models with HF_TOKEN |
| [kaito_option2_azure_volume.yaml](assets/kubernetes/kaito_option2_azure_volume.yaml) | Models pre-loaded on Azure Blob/Files storage |
| [kaito_option3_init_container_blob.yaml](assets/kubernetes/kaito_option3_init_container_blob.yaml) | Download from Azure Blob at startup (workload identity) |
| [kaito_option4_azureml.yaml](assets/kubernetes/kaito_option4_azureml.yaml) | Download from Azure ML Model Registry |

## Base Manifest Reference

The base manifest (`kaito_custom_cpu_model.yaml`) is a template populated via Terraform's `templatefile()`.

### Template Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `${name}` | Workspace name | `bloomz-workspace` |
| `${namespace}` | Kubernetes namespace | `bloomz` |
| `${instanceType}` | Azure VM size for the node | `Standard_D16s_v5` |

### Resource Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `instanceType` | `Standard_D16s_v5` | Intel Ice Lake, 16 vCPUs, 64GB RAM |
| `labelSelector` | `apps: bloomz-560m` | Label for node affinity matching |

### Container Resources

| Resource | Request | Limit | Notes |
|----------|---------|-------|-------|
| Memory | 8Gi | 16Gi | Model ~2.2GB + overhead for inference |
| CPU | 2 | 4 | 4 cores for parallel tensor operations |

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `OMP_NUM_THREADS` | `4` | OpenMP thread count - matches CPU limit to prevent thread over-subscription. Without this, OpenMP spawns threads based on node CPU count, causing contention. |
| `TOKENIZERS_PARALLELISM` | `false` | Disables HuggingFace tokenizer multi-threading to prevent deadlocks when combined with PyTorch multiprocessing. Safe for inference. |

### Health Probes

| Probe | Initial Delay | Period | Timeout | Failure Threshold |
|-------|---------------|--------|---------|-------------------|
| Liveness | 300s | 30s | 5s | 3 |
| Readiness | 60s | 10s | 5s | 3 |

> **Note**: Liveness probe has a 300s initial delay because CPU model loading is slower than GPU.

### Command & Arguments

The container uses [HuggingFace Accelerate](https://huggingface.co/docs/accelerate) to launch the inference server.

**Command**: `accelerate`

| Argument | Value | Purpose |
|----------|-------|---------|
| `launch` | - | Subcommand to launch a script with distributed configuration |
| `--num_processes` | `1` | Number of Python processes. Use 1 for CPU inference - parallelization happens via threads (OMP_NUM_THREADS), not processes. |
| `--num_machines` | `1` | Number of nodes in cluster. Use 1 for single-node deployment. |
| `tfs/inference_api.py` | - | KAITO's Transformer Serving API. Starts HTTP server on port 5000 with `/health` and `/generate` endpoints. |
| `--pipeline` | `text-generation` | HuggingFace pipeline type. Options: `text-generation` (GPT-style), `text2text-generation` (T5/FLAN), `fill-mask` (BERT) |
| `--trust_remote_code` | - | Allows executing custom Python code from model repo. Required for some models (Phi, Qwen, Falcon). |
| `--allow_remote_files` | - | Permits downloading model weights from HuggingFace Hub. Models cached in `~/.cache/huggingface/` after download. |
| `--pretrained_model_name_or_path` | `bigscience/bloomz-560m` | HuggingFace model ID. BLOOMZ 560M is a multilingual instruction-tuned model (~2.2GB in float32). |
| `--torch_dtype` | `float32` | Tensor precision. CPU requires `float32` (no native float16 support). Use `float16`/`bfloat16` for GPU. |

### Shared Memory Volume

| Mount Path | Type | Purpose |
|------------|------|---------|
| `/dev/shm` | `emptyDir` (Memory-backed) | PyTorch uses `/dev/shm` for inter-process communication. Docker's default is only 64MB, which causes errors with large tensors. RAM-backed emptyDir provides unlimited shared memory. |

### Inference Flow

```
accelerate launch
    └── Configures distributed runtime (1 process, 1 machine)
         └── Runs tfs/inference_api.py
              └── Loads bigscience/bloomz-560m in float32
                   └── Starts HTTP server on port 5000
                        ├── GET  /health       → Health check for probes
                        ├── GET  /metrics      → JSON system metrics (CPU/GPU info, memory usage)
                        ├── POST /chat         → Text generation endpoint
                        └── GET  /openapi.json → OpenAPI specification
```

> **Tip**: View the full API specification with:
> ```bash
> curl -s http://cpu-only-workspace:80/openapi.json | head
> ```

## Testing the Model

Once the workspace is deployed and ready, you can test the inference endpoint using a curl pod.

**1. Create a debug pod in the same namespace:**

```bash
kubectl run curl-debug \
  -n bloomz \
  -it --restart=Never \
  --image=curlimages/curl \
  -- sh
```

**2. Check the API schema:**

```bash
curl -s http://cpu-only-workspace:80/openapi.json | head
```

**3. Sample prompts:**

```bash
# Question answering
curl --max-time 60 -X POST http://cpu-only-workspace/chat \
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
curl --max-time 60 -X POST http://cpu-only-workspace/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Is a tomato a fruit or a vegetable?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_length": 64,
      "do_sample": false
    }
  }'

# List generation
curl --max-time 60 -X POST http://cpu-only-workspace/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Name three indoor activities suitable for rainy weather.",
    "return_full_text": false,
    "generate_kwargs": {
      "max_length": 64,
      "do_sample": false
    }
  }'

# Explanation request
curl --max-time 60 -X POST http://cpu-only-workspace/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Can electric cars reduce air pollution? Explain briefly.",
    "return_full_text": false,
    "generate_kwargs": {
      "max_length": 64,
      "do_sample": false
    }
  }'

# Brief definition
curl --max-time 60 -X POST http://cpu-only-workspace/chat \
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

**4. Exit the debug pod:**

```bash
exit
kubectl delete pod curl-debug -n bloomz
```

## Infrastructure Overview

The Terraform configuration (`terraform/main.tf`) provisions:

- **AKS Cluster** - Kubernetes 1.34.2 with AI Conformance features
- **KAITO** - Enabled via `ai_toolchain_operator_enabled = true`
- **Workload Identity** - For secure pod-to-Azure authentication
- **Istio Service Mesh** - mTLS and traffic management
- **Gateway API** - Advanced routing for inference endpoints
- **Prometheus Monitoring** - Azure Monitor with recording rules

### Gateway API + Istio Traffic Flow

This cluster uses **Gateway API** (the Kubernetes standard for AI Conformance) with **Istio** as the implementation. See [terraform/main.tf](terraform/main.tf) for the full configuration.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     GATEWAY API WITH ISTIO IMPLEMENTATION                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                            CONTROL PLANE                               │  │
│  │                                                                        │  │
│  │   You Create (Gateway API CRDs)            Istio Control Plane         │  │
│  │   ┌───────────────────────────┐           ┌───────────────────────┐    │  │
│  │   │ Gateway CR                │           │ istiod                │    │  │
│  │   │ (Kubernetes standard)     │---------->│ - Watches Gateway     │    │  │
│  │   │                           │           │ - Creates Envoy pods  │    │  │
│  │   │ HTTPRoute CR              │           │ - Configures routing  │    │  │
│  │   │ (Kubernetes standard)     │           └───────────────────────┘    │  │
│  │   └───────────────────────────┘                     │                  │  │
│  │                                                     │                  │  │
│  │   gatewayClassName: istio  ◄────────────────────────┘                  │  │
│  │   (tells K8s to use Istio as the implementation)                       │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                          │                                   │
│                                          │ Istio auto-creates                │
│                                          ▼                                   │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                             DATA PLANE                                 │  │
│  │                                                                        │  │
│  │   External Traffic                                                     │  │
│  │        │                                                               │  │
│  │        ▼                                                               │  │
│  │   ┌───────────────────────────────────┐  (Auto-created by Istio)       │  │
│  │   │ inference-gateway-istio           │                                │  │
│  │   │ ├─ Deployment (Envoy proxy)       │                                │  │
│  │   │ ├─ Service (LoadBalancer)         │  ◄── Gets external IP          │  │
│  │   │ ├─ HPA (2-5 replicas)             │                                │  │
│  │   │ └─ PDB (minAvailable: 1)          │                                │  │
│  │   └───────────────────────────────────┘                                │  │
│  │                    │                                                   │  │
│  │                    │ Routes: /  →  cpu-only-workspace:80               │  │
│  │                    ▼                                                   │  │
│  │   ┌───────────────────────────────────┐                                │  │
│  │   │ cpu-only-workspace Service        │  (bloomz namespace)            │  │
│  │   │ KAITO inference endpoint          │                                │  │
│  │   └───────────────────────────────────┘                                │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

**How it works:**
1. **Gateway API** provides the Kubernetes-standard CRDs (`Gateway`, `HTTPRoute`)
2. **Istio** is the implementation that watches these CRDs
3. When you create a `Gateway` with `gatewayClassName: istio`, Istio automatically creates Envoy proxy pods
4. `HTTPRoute` defines routing rules that Istio configures into the Envoy proxies

**Why this approach?**
- ✅ **AI Conformance** - Uses Kubernetes-standard Gateway API
- ✅ **Portable** - Gateway/HTTPRoute specs work with any Gateway API implementation
- ✅ **Istio features** - Still get mTLS, observability, and traffic management

*Docs: [AKS Istio Gateway API](https://learn.microsoft.com/en-us/azure/aks/istio-gateway-api)*

### End-to-End Inference Flow

This diagram shows the complete request flow from an external client to the KAITO model and back:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         END-TO-END INFERENCE FLOW                            │
└──────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────┐
  │   Client    │  curl -X POST http://<EXTERNAL-IP>/chat
  │  (External) │  -d '{"prompt": "What is cloud computing?"}'
  └──────┬──────┘
         │
         │ 1. HTTP Request
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  Azure Load Balancer                                                         │
│  (Public IP: <EXTERNAL-IP>)                                                  │
└──────────────────────────────────────────────────────────────────────────────┘
         │
         │ 2. Routes to NodePort
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  AKS Cluster (bloomz namespace)                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  inference-gateway-istio Service (LoadBalancer)                      │  │
│    │  Port: 80                                                            │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                   │                                                          │
│                   │ 3. Forward to Envoy pods                                 │
│                   ▼                                                          │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  inference-gateway-istio Pods (Envoy Proxy)                          │  │
│    │  ├─ Receives HTTP request                                            │  │
│    │  ├─ Matches HTTPRoute rule: PathPrefix "/"                           │  │
│    │  ├─ Applies timeout: 120s                                            │  │
│    │  └─ Routes to backend: cpu-only-workspace:80                         │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                   │                                                          │
│                   │ 4. Proxy to KAITO service                                │
│                   ▼                                                          │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  cpu-only-workspace Service (ClusterIP)                              │  │
│    │  Port: 80 -> 5000                                                    │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                   │                                                          │
│                   │ 5. Forward to inference pod                              │
│                   ▼                                                          │
│    ┌──────────────────────────────────────────────────────────────────────┐  │
│    │  cpu-only-workspace-0 Pod (KAITO Inference)                          │  │
│    │  ├─ Container: inference-api (port 5000)                             │  │
│    │  ├─ Model: bigscience/bloomz-560m                                    │  │
│    │  ├─ Runtime: HuggingFace Accelerate + PyTorch                        │  │
│    │  └─ Endpoint: POST /chat                                             │  │
│    │                                                                      │  │
│    │  ┌────────────────────────────────────────────────────────────────┐  │  │
│    │  │  6. Model Inference                                            │  │  │
│    │  │  ├─ Tokenize input prompt                                      │  │  │
│    │  │  ├─ Forward pass through BLOOMZ-560M                           │  │  │
│    │  │  ├─ Generate tokens (max_length: 64)                           │  │  │
│    │  │  └─ Decode tokens to text                                      │  │  │
│    │  └────────────────────────────────────────────────────────────────┘  │  │
│    │                                                                      │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│                   │                                                          │
│                   │ 7. Response bubbles back up                              │
│                   ▼                                                          │
└──────────────────────────────────────────────────────────────────────────────┘
         │
         │ 8. HTTP Response
         ▼
  ┌─────────────┐
  │   Client    │  {"Result": "Cloud computing is a model for enabling..."}
  │  (External) │
  └─────────────┘
```

**Request path:** Client → Load Balancer → Gateway Service → Envoy Pods → KAITO Service → Inference Pod

**Key components:**
| Component                      | Type         | Purpose                                    |
|--------------------------------|--------------|--------------------------------------------|
| inference-gateway-istio        | Service (LB) | External entry point with public IP        |
| inference-gateway-istio pods   | Envoy Proxy  | HTTP routing, timeouts, load balancing     |
| cpu-only-workspace             | Service (CI) | Internal service discovery for KAITO       |
| cpu-only-workspace-0           | Pod          | Runs the actual model inference            |

### Node Pools

| Pool | Purpose | VM Size | Scaling | Notes |
|------|---------|---------|---------|-------|
| `default` | System workloads | Standard_D2s_v3 | 2-5 nodes | Critical addons only |
| `gpunp` | AI workloads | Standard_D16s_v5 | 0-3 nodes | CPU-only for this POC |

> **Note**: The "GPU" node pool uses D-series (CPU-only) VMs for this POC since GPU quota can be limited. For production, use actual GPU SKUs (e.g., `Standard_NC6s_v3`).

## Prerequisites

- Azure subscription with sufficient VM quota
- Terraform 1.x installed
- Azure CLI authenticated (`az login`)

## Resources

- [KAITO GitHub Repository](https://github.com/kaito-project/kaito)
- [KAITO Supported Models](https://github.com/kaito-project/kaito/tree/main/presets/workspace/models)
- [AKS AI/ML Documentation](https://learn.microsoft.com/azure/aks/ai-ml-overview)
- [CNCF AI Conformance Repository](https://github.com/cncf/k8s-ai-conformance)
