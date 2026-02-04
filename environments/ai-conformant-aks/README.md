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

### KAITO Custom CPU Model Manifest

The `assets/kubernetes/kaito_custom_cpu_model.yaml` manifest deploys a custom KAITO Workspace for CPU-based inference. This is a template file that gets populated via Terraform's `templatefile()` function.

#### Template Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `${name}` | Workspace name | `bloomz-workspace` |
| `${namespace}` | Kubernetes namespace | `bloomz` |
| `${instanceType}` | Azure VM size for the node | `Standard_D4ds_v6` |

#### Resource Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `instanceType` | `Standard_D4ds_v6` | Intel Emerald Rapids with local NVMe, 4 vCPUs, 16GB RAM |
| `labelSelector` | `apps: bloomz-560m` | Label for node affinity matching |

#### Container Resources

| Resource | Request | Limit | Notes |
|----------|---------|-------|-------|
| Memory | 8Gi | 16Gi | Model ~2.2GB + overhead for inference |
| CPU | 2 | 4 | 4 cores for parallel tensor operations |

#### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `OMP_NUM_THREADS` | `4` | OpenMP thread count - matches CPU limit to prevent thread over-subscription. Without this, OpenMP spawns threads based on node CPU count, causing contention. |
| `TOKENIZERS_PARALLELISM` | `false` | Disables HuggingFace tokenizer multi-threading to prevent deadlocks when combined with PyTorch multiprocessing. Safe for inference. |

#### Health Probes

| Probe | Initial Delay | Period | Timeout | Failure Threshold |
|-------|---------------|--------|---------|-------------------|
| Liveness | 300s | 30s | 5s | 3 |
| Readiness | 60s | 10s | 5s | 3 |

> **Note**: Liveness probe has a 300s initial delay because CPU model loading is slower than GPU.

#### Command & Arguments

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

#### Shared Memory Volume

| Mount Path | Type | Purpose |
|------------|------|---------|
| `/dev/shm` | `emptyDir` (Memory-backed) | PyTorch uses `/dev/shm` for inter-process communication. Docker's default is only 64MB, which causes errors with large tensors. RAM-backed emptyDir provides unlimited shared memory. |

#### Inference Flow

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

#### Testing the Model

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

### Istio Service Mesh

The cluster includes an **Istio-based service mesh** (`asm-1-28` revision) with:

- **External Ingress Gateway enabled**: Managed Istio ingress for north-south traffic (external clients → cluster)
- **mTLS and traffic management**: East-west traffic between services benefits from automatic mTLS, retries, timeouts, and circuit breaking

### Node Pools

| Pool | Purpose | VM Size | Scaling | Notes |
|------|---------|---------|---------|-------|
| `default` | System workloads | Standard_D2s_v3 | 2-5 nodes | Critical addons only, HA across 3 zones |
| `gpunp` | GPU/AI workloads | Standard_D16s_v5 | 0-3 nodes | Tagged with `EnableManagedGPUExperience=true` |

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
