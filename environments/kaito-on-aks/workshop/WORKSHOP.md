# KAITO on AKS — Customer Workshop

A self-paced, hands-on workshop that turns the [KAITO on AKS demo](../README.md) into a guided learning experience. Attendees deploy an AKS cluster with the KAITO (Kubernetes AI Toolchain Operator) add-on, deploy a small CPU-based language model, and call it from inside and outside the cluster.

## Audience

Cloud architects, platform engineers, and developers who want to understand how to run open-source AI/ML inference workloads on Azure Kubernetes Service using KAITO.

## Duration

Approximately **2 to 3 hours**, depending on AKS provisioning time and how much exploration attendees do between steps.

## What you will learn

- What KAITO is and how it differs from Microsoft Foundry
- How to enable the KAITO add-on on AKS via Terraform
- How a KAITO `Workspace` custom resource describes an inference workload
- How to inspect the workload (nodes, pods, services, logs)
- How to call the model's OpenAI-compatible inference API
- How to clean up everything safely

## Workshop assumptions

- Each attendee has **their own Azure subscription** with permission to create resource groups, storage accounts, and AKS clusters.
- Each attendee creates their own resource group, storage account (for Terraform state), AKS cluster, and Kubernetes namespaces.
- Nothing is pre-provisioned. Attendees deploy live during the workshop.
- This workshop uses a **CPU-based** model (BLOOMZ-560m). GPU presets are out of scope.

## Workshop format

This workshop ships in two formats — pick whichever fits your delivery:

| Format | Location | Best for |
|--------|----------|----------|
| Markdown (this file) | [workshop/WORKSHOP.md](WORKSHOP.md) | Self-paced, GitHub reading, in-person delivery |
| MS Learn / Reactor module | [workshop/index.yml](index.yml) | Microsoft Reactor events, Learn-style hosted delivery |

Both formats cover the same material and reference the same Terraform and Kubernetes manifests in the parent [environments/kaito-on-aks](../) folder.

---

## Table of contents

- [Pre-requisites](#pre-requisites)
- [Lab 1 — Bootstrap and deploy](#lab-1--bootstrap-and-deploy)
- [Lab 2 — Connect and inspect](#lab-2--connect-and-inspect)
- [Lab 3 — Call the model](#lab-3--call-the-model)
- [Lab 4 — Cleanup](#lab-4--cleanup)

---

## Pre-requisites

Before starting Lab 1, make sure each attendee has the following.

### Azure

- An Azure subscription where you can create:
  - Resource groups
  - Storage accounts
  - AKS clusters
  - Public IPs (for the auto-created LoadBalancer)
- The ability to assign roles, OR you'll be the only principal touching the resources.

### Local tools

| Tool | Minimum version | Install |
|------|-----------------|---------|
| Azure CLI (`az`) | 2.60+ | <https://learn.microsoft.com/cli/azure/install-azure-cli> |
| Terraform | 1.14.4+ | <https://developer.hashicorp.com/terraform/install> |
| `kubectl` | 1.30+ | <https://kubernetes.io/docs/tasks/tools/> |
| `curl` | any | usually pre-installed |
| Git | any | <https://git-scm.com/downloads> |

> **Windows attendees:** PowerShell 7+ recommended. The `bash`-style commands below also work in WSL or Git Bash.

### Background knowledge

You should be comfortable with:

- Basic Azure concepts (subscriptions, resource groups)
- Basic Kubernetes concepts (pods, services, namespaces)
- Running CLI commands and editing YAML

If KAITO is new to you, skim the [What is KAITO?](../README.md#what-is-kaito) section of the demo README before starting.

### Repository

Clone or fork this repository:

```bash
git clone https://github.com/almirbanjanovic/cloud-playground-infra.git
cd cloud-playground-infra/environments/kaito-on-aks
```

All commands in this workshop assume your working directory is `environments/kaito-on-aks` (the parent of this `workshop/` folder).

---

## Lab 1 — Bootstrap and deploy

**Goal:** Create the Azure scaffolding (resource group + Terraform state storage), then use Terraform to deploy an AKS cluster with KAITO enabled and a small CPU model workspace.

**Estimated time:** 30–45 minutes (most of it waiting for AKS to provision and the model image to load).

### 1.1 Sign in and pick a subscription

```bash
az login
az account set --subscription "<your-subscription-id-or-name>"
az account show --output table
```

### 1.2 Create the workshop resource group

This is where the AKS cluster and supporting resources will live.

```bash
# Pick values you'll reuse throughout the workshop
RG_NAME="rg-kaito-workshop"
LOCATION="centralus"

az group create --name "$RG_NAME" --location "$LOCATION"
```

> The Terraform code defaults to `centralus`. If you change `LOCATION`, also change the `location` value in [../terraform/main.tf](../terraform/main.tf) `locals` block (or just stick with `centralus` to keep it simple).

### 1.3 Create a storage account for Terraform state

Terraform needs somewhere to keep its state file. We'll use an Azure storage account container.

```bash
# Storage account names must be globally unique, lowercase, 3-24 chars
STORAGE_ACCOUNT="stkaito$RANDOM"
STATE_CONTAINER="tfstate"

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2

az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login

echo "Storage account: $STORAGE_ACCOUNT"
```

### 1.4 Walk through the Terraform code

Before running Terraform, take a few minutes to read the files in [../terraform/](../terraform/). You don't need to change anything; just understand what will be created.

#### [../terraform/providers.tf](../terraform/providers.tf)

Declares four providers and the remote state backend:

- `azurerm` — creates Azure resources
- `azapi` — used for newer Azure APIs not yet in `azurerm`
- `kubernetes` — talks to the AKS API server
- `kubectl` (gavinbunney) — applies raw YAML manifests; we use it for the KAITO `Workspace` CRD because the `kubernetes` provider doesn't natively understand custom resources well

The `backend "azurerm" {}` block is intentionally empty — we'll pass the values at `init` time so the same code can be reused across subscriptions.

#### [../terraform/variables.tf](../terraform/variables.tf)

A single input: `resource_group_name`. Everything else is hardcoded in the `locals` block in `main.tf` for simplicity (this is a demo, not a production module).

#### [../terraform/main.tf](../terraform/main.tf)

Three resources, deployed in order:

1. **`azurerm_kubernetes_cluster.this`** — an AKS cluster with:
   - Kubernetes 1.34.2
   - A 1–5 node autoscaling system pool on `Standard_D2s_v3`
   - OIDC issuer + workload identity enabled
   - **`ai_toolchain_operator_enabled = true`** — this is the KAITO add-on
2. **`kubectl_manifest.custom_cpu_inference_namespace`** — a `kaito-custom-cpu-inference` namespace
3. **`kubectl_manifest.bloomz_560m`** — the KAITO `Workspace`, rendered from [../assets/kubernetes/kaito_custom_cpu_model.yaml](../assets/kubernetes/kaito_custom_cpu_model.yaml) via `templatefile()`

#### [../terraform/outputs.tf](../terraform/outputs.tf)

Outputs the cluster name, the `az aks get-credentials` command, the namespace, the workspace/service name, and a one-liner to fetch the LoadBalancer IP.

#### [../assets/kubernetes/kaito_custom_cpu_model.yaml](../assets/kubernetes/kaito_custom_cpu_model.yaml)

The KAITO `Workspace` custom resource. Key points to discuss with the group:

- `kind: Workspace` is a CRD installed by the KAITO add-on
- `kaito.sh/enablelb: "True"` annotation tells KAITO to also create a `LoadBalancer` Service with a public IP. Convenient for testing; **never do this in production** — there's no auth in front of the model.
- `resource.instanceType: Standard_D16s_v5` — KAITO will spin up a node of this size and schedule the workload there
- `inference.template.spec.containers[0].image: mcr.microsoft.com/aks/kaito/kaito-base:0.0.8` — KAITO's inference base image
- The `args:` list configures `accelerate launch` to serve `bigscience/bloomz-560m` via HuggingFace Transformers on port 5000
- `--trust_remote_code` — note this for the security-aware: it executes Python from the model repo at load time. Fine for `bigscience/bloomz-560m`; review carefully for other models

### 1.5 Initialize Terraform

```bash
cd ../terraform

terraform init \
  -backend-config="resource_group_name=$RG_NAME" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=kaito-on-aks.tfstate"
```

You should see `Terraform has been successfully initialized!`

### 1.6 Plan and apply

```bash
terraform plan -var "resource_group_name=$RG_NAME"
```

Review the plan output. You should see roughly 3 resources to add (cluster, namespace, workspace).

```bash
terraform apply -var "resource_group_name=$RG_NAME" -auto-approve
```

> **Heads-up:** AKS provisioning takes ~5–10 minutes, and after that the KAITO controller still needs to provision a node and pull the model. **The `apply` may take 15–25 minutes total before everything is ready.** Use the time to read the [What is KAITO?](../README.md#what-is-kaito) section of the demo README.

### 1.7 Verify the cluster exists

```bash
az aks list --resource-group "$RG_NAME" --output table
```

Move on to Lab 2 once the cluster shows `Succeeded`.

---

## Lab 2 — Connect and inspect

**Goal:** Connect `kubectl` to the new cluster and walk through everything KAITO created.

**Estimated time:** 15–20 minutes.

### 2.1 Get cluster credentials

Use the command Terraform printed (also in `outputs.tf`):

```bash
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$(terraform output -raw cluster_name)"
```

### 2.2 Look at the cluster

```bash
kubectl get nodes
kubectl get namespaces
```

You should see the system node pool plus, eventually, a KAITO-provisioned node tagged for the workspace.

### 2.3 Inspect the KAITO Workspace

```bash
kubectl get workspace -n kaito-custom-cpu-inference
kubectl describe workspace bloomz-560m-workspace -n kaito-custom-cpu-inference
```

Walk through the `Status` block. KAITO reports:

- `ResourceReady` — the underlying VM/node is up
- `InferenceReady` — the inference pod is healthy
- `WorkspaceReady` — the whole thing is good to go

### 2.4 Watch the inference pod

```bash
kubectl get pods -n kaito-custom-cpu-inference -w
```

Press `Ctrl+C` once the pod shows `Running` with `Ready 1/1`. On CPU this can take several minutes — the container has to download ~2.2 GB of model weights from HuggingFace before the readiness probe passes.

### 2.5 Tail the logs

```bash
POD=$(kubectl get pods -n kaito-custom-cpu-inference -l app=bloomz-560m -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kaito-custom-cpu-inference "$POD" --tail=100
```

You should see HuggingFace `transformers` downloading config + tokenizer + weights, then `accelerate` launching the inference server on port 5000.

### 2.6 Inspect the auto-created LoadBalancer

```bash
kubectl get svc bloomz-560m-workspace -n kaito-custom-cpu-inference
```

The `EXTERNAL-IP` column will say `<pending>` for a minute or two while Azure provisions the public IP, then show a real IP. This service was created automatically because of the `kaito.sh/enablelb: "True"` annotation on the `Workspace`.

---

## Lab 3 — Call the model

**Goal:** Send inference requests to the model via the public LoadBalancer endpoint, then optionally from inside the cluster.

**Estimated time:** 15–20 minutes.

### 3.1 Capture the external IP

```bash
KAITO_IP=$(kubectl get svc bloomz-560m-workspace \
  -n kaito-custom-cpu-inference \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "KAITO endpoint: http://$KAITO_IP"
```

### 3.2 Health check

```bash
curl http://$KAITO_IP/health
```

Expect `{"status":"Healthy"}` (or similar).

### 3.3 Inspect the API schema

```bash
curl -s http://$KAITO_IP/openapi.json | head
```

KAITO exposes a standard OpenAPI-compatible inference API.

### 3.4 Sample prompts

These match the demo in [../README.md](../README.md#testing-with-loadbalancer).

**Question answering:**

```bash
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
```

**Factual question:**

```bash
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
```

**Brief definition:**

```bash
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

### 3.5 Discuss the request shape

| Field | Meaning |
|-------|---------|
| `prompt` | The input text the model continues from |
| `return_full_text` | `false` returns only the newly generated tokens (not the prompt itself) |
| `generate_kwargs.max_new_tokens` | Hard cap on generated length |
| `generate_kwargs.do_sample` | `false` = greedy (deterministic), `true` = sampling (more varied) |

### 3.6 Optional — call from inside the cluster

This shows the more production-realistic path: an in-cluster client hitting a `ClusterIP` service via DNS, with no public IP involved.

```bash
kubectl run curl-debug \
  -n kaito-custom-cpu-inference \
  -it --restart=Never \
  --image=curlimages/curl \
  -- sh
```

Inside the pod:

```sh
curl http://bloomz-560m-workspace/health

curl -X POST http://bloomz-560m-workspace/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is cloud computing?",
    "return_full_text": false,
    "generate_kwargs": { "max_new_tokens": 256, "do_sample": false }
  }'

exit
```

```bash
kubectl delete pod curl-debug -n kaito-custom-cpu-inference
```

---

## Lab 4 — Cleanup

**Goal:** Remove everything created during the workshop so nothing keeps charging your subscription.

**Estimated time:** 10–15 minutes.

### 4.1 Destroy the Terraform-managed resources

```bash
terraform destroy -var "resource_group_name=$RG_NAME" -auto-approve
```

This removes the AKS cluster, the namespace, and the KAITO workspace.

### 4.2 Verify the AKS-managed resource group is gone

When AKS is created, Azure provisions a "node" resource group (typically named `MC_<rg>_<cluster>_<region>`) that holds the VMs, NICs, disks, and load balancer. It should be deleted automatically when the cluster is destroyed — verify:

```bash
az group list --query "[?starts_with(name, 'MC_${RG_NAME}_')]" --output table
```

If anything is still listed, delete it manually:

```bash
az group delete --name "<MC_...>" --yes --no-wait
```

### 4.3 Delete the workshop resource group

This removes the storage account holding Terraform state and anything else left behind:

```bash
az group delete --name "$RG_NAME" --yes --no-wait
```

### 4.4 Confirm

```bash
az group show --name "$RG_NAME" 2>&1 | grep -i "could not be found"
```

Done. You're back to a clean subscription.

---

## What you learned

- KAITO is a Kubernetes operator that manages model lifecycle on AKS — it provisions nodes, downloads model weights, and runs an inference server, all driven by a single `Workspace` custom resource.
- Enabling KAITO on AKS is one Terraform flag: `ai_toolchain_operator_enabled = true`.
- A KAITO `Workspace` ties together: an instance type, a label selector, and an inference template (or a preset name).
- The `kaito.sh/enablelb` annotation is convenient for testing but unsuitable for production — there's no authentication on the inference endpoint.
- The model exposes a standard OpenAPI-style `/chat` endpoint, callable from anywhere with HTTP access.

## Next steps

- Try a different custom model by editing [../assets/kubernetes/kaito_custom_cpu_model.yaml](../assets/kubernetes/kaito_custom_cpu_model.yaml) and re-applying.
- Explore the other manifest templates in [../assets/kubernetes/](../assets/kubernetes/) — private HuggingFace, Azure storage, Azure ML, and KAITO presets.
- Read the [KAITO docs](https://github.com/kaito-project/kaito) for fine-tuning and GPU presets.
- For production, replace the LoadBalancer annotation with an Ingress controller, add authentication, and consider AAD-integrated RBAC on the cluster.
