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

- Each attendee has **their own Azure subscription** with permission to create resource groups, storage accounts, and AKS clusters, **and** to assign Azure RBAC roles (e.g. `Owner` or `User Access Administrator` on the resource group or subscription).
- Each attendee creates their own resource group, storage account (for Terraform state), AKS cluster, and Kubernetes namespaces.
- The resource group and the state storage account are created with the Azure CLI and are **not** managed by Terraform. Only AKS, the namespace, and the KAITO workspace live in Terraform state.
- All access to the state storage account uses **Microsoft Entra ID** authentication — shared keys are disabled.
- Nothing is pre-provisioned. Attendees deploy live during the workshop.
- This workshop uses a **CPU-based** model (BLOOMZ-560m). GPU presets are out of scope.

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
- Permission to **assign Azure RBAC roles** on resources you create (e.g. `Owner` or `User Access Administrator` on the workshop resource group or subscription). Lab 1 grants you `Storage Blob Data Contributor` on the state storage account so the Terraform azurerm backend can read and write blobs with your Entra ID token.

### Local tools

| Tool | Minimum version | Install |
|------|-----------------|---------|
| Azure CLI (`az`) | 2.60+ | <https://learn.microsoft.com/cli/azure/install-azure-cli> |
| Terraform | 1.14.4+ | <https://developer.hashicorp.com/terraform/install> |
| `kubectl` | 1.34.2+ | <https://kubernetes.io/docs/tasks/tools/> |
| `curl` | any | usually pre-installed |
| Git | any | <https://git-scm.com/downloads> |

> **Shell support:** Commands in this workshop are shown for both **bash** (Linux, macOS, WSL, Git Bash) and **PowerShell 7+** (Windows, cross-platform). Pick whichever you prefer and use the matching block consistently. Where a single command works identically in both shells, it appears once under a `**Bash & PowerShell:**` heading.

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

**Bash & PowerShell:**

```bash
az login
az account set --subscription "<your-subscription-id-or-name>"
az account show --output table
```

**Expected output:**

```text
EnvironmentName    HomeTenantId                          IsDefault    Name              State    TenantId
-----------------  ------------------------------------  -----------  ----------------  -------  ------------------------------------
AzureCloud         <tenant-guid>                         True         <subscription>    Enabled  <tenant-guid>
```

### 1.2 Create the workshop resource group

This is where the AKS cluster will live. **The resource group is created with the Azure CLI and is intentionally NOT managed by Terraform** — that way `terraform destroy` can never accidentally remove the storage account that holds your state file (more on that in Lab 4).

The Terraform code defaults to `centralus` and exposes `location` as a Terraform variable (default: `centralus`). To deploy to a different region, set both the env var below and pass `-var "location=<region>"` to `terraform plan`/`apply`.

**bash:**

```bash
# Pick values you'll reuse throughout the workshop
RG_NAME="rg-kaito-workshop"
LOCATION="centralus"

az group create --name "$RG_NAME" --location "$LOCATION"
```

**PowerShell:**

```powershell
# Pick values you'll reuse throughout the workshop
$RG_NAME = "rg-kaito-workshop"
$LOCATION = "centralus"

az group create --name $RG_NAME --location $LOCATION
```

**Expected output (truncated):**

```json
{
  "id": "/subscriptions/<sub-id>/resourceGroups/rg-kaito-workshop",
  "location": "centralus",
  "name": "rg-kaito-workshop",
  "properties": { "provisioningState": "Succeeded" }
}
```

### 1.3 Create a storage account for Terraform state

Terraform needs somewhere to keep its state file. We'll use an Azure storage account container, accessed with **Microsoft Entra ID (Azure AD) authentication** — no shared keys anywhere. Like the resource group, the storage account is created with the Azure CLI and is **NOT managed by Terraform**.

**bash:**

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
  --min-tls-version TLS1_2 \
  --allow-shared-key-access false

echo "Storage account: $STORAGE_ACCOUNT"
```

**PowerShell:**

```powershell
# Storage account names must be globally unique, lowercase, 3-24 chars
$STORAGE_ACCOUNT = "stkaito$(Get-Random -Maximum 99999)"
$STATE_CONTAINER = "tfstate"

az storage account create `
  --name $STORAGE_ACCOUNT `
  --resource-group $RG_NAME `
  --location $LOCATION `
  --sku Standard_LRS `
  --encryption-services blob `
  --min-tls-version TLS1_2 `
  --allow-shared-key-access false

Write-Host "Storage account: $STORAGE_ACCOUNT"
```

**Expected output (final line):**

```text
Storage account: stkaito12345
```

> `--allow-shared-key-access false` forces every caller (including Terraform) to authenticate with Entra ID. Subscription `Owner` does **not** automatically grant data-plane access to blobs, so we explicitly assign the `Storage Blob Data Contributor` role next.

### 1.4 Grant yourself data-plane access to the storage account

Assign the `Storage Blob Data Contributor` role on the storage account to your own Entra ID principal. This is what lets the next `az storage container create` and the Terraform azurerm backend read and write blobs using your `az login` token.

**bash:**

```bash
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id "$USER_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"
```

**PowerShell:**

```powershell
$USER_OBJECT_ID = az ad signed-in-user show --query id -o tsv
$STORAGE_ID = az storage account show `
  --name $STORAGE_ACCOUNT `
  --resource-group $RG_NAME `
  --query id -o tsv

az role assignment create `
  --assignee-object-id $USER_OBJECT_ID `
  --assignee-principal-type User `
  --role "Storage Blob Data Contributor" `
  --scope $STORAGE_ID
```

> Role assignments can take 30–60 seconds to propagate. If the next step fails with a 403, wait a minute and retry.

### 1.5 Create the state container (Entra auth)

**bash:**

```bash
az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login
```

**PowerShell:**

```powershell
az storage container create `
  --name $STATE_CONTAINER `
  --account-name $STORAGE_ACCOUNT `
  --auth-mode login
```

**Expected output:**

```json
{ "created": true }
```

### 1.6 Walk through the Terraform code

Before running Terraform, take a few minutes to read the files in [../terraform/](../terraform/). You don't need to change anything; just understand what will be created.

#### [../terraform/providers.tf](../terraform/providers.tf)

Declares four providers and the remote state backend:

- `azurerm` — creates Azure resources
- `azapi` — used for newer Azure APIs not yet in `azurerm`
- `kubernetes` — talks to the AKS API server
- `kubectl` (gavinbunney) — applies raw YAML manifests; we use it for the KAITO `Workspace` CRD because the `kubernetes` provider doesn't natively understand custom resources well

The `backend "azurerm" {}` block is intentionally empty — we'll pass the values at `init` time so the same code can be reused across subscriptions.

#### [../terraform/variables.tf](../terraform/variables.tf)

Two inputs:

- `resource_group_name` (required) — the RG you created in step 1.2. The RG itself is **not** managed by Terraform.
- `location` (optional, defaults to `centralus`) — the Azure region. Override at `plan`/`apply` time with `-var "location=<region>"` if you used a different region in step 1.2.

Everything else is hardcoded in the `locals` block in `main.tf` for simplicity (this is a demo, not a production module).

#### [../terraform/main.tf](../terraform/main.tf)

Three resources, deployed in order:

1. **`azurerm_kubernetes_cluster.this`** — an AKS cluster with:
   - Kubernetes 1.34.2
   - A 1–5 node autoscaling system pool on `Standard_D2s_v3`
   - OIDC issuer + workload identity enabled
   - **`ai_toolchain_operator_enabled = true`** — this is the KAITO add-on
2. **`kubectl_manifest.custom_cpu_inference_namespace`** — a `kaito-custom-cpu-inference` namespace
3. **`kubectl_manifest.bloomz_560m`** — the KAITO `Workspace`, rendered from [../assets/kubernetes/kaito_custom_cpu_model.yaml](../assets/kubernetes/kaito_custom_cpu_model.yaml) via `templatefile()`

Note that the **resource group and the state storage account are not Terraform resources** — they're created and destroyed with the Azure CLI. This guarantees `terraform destroy` cannot wipe the storage account that holds your state.

#### [../terraform/outputs.tf](../terraform/outputs.tf)

Outputs the resource group name, the cluster name, the `az aks get-credentials` command, the namespace, the workspace/service name, and a one-liner to fetch the LoadBalancer IP.

#### [../assets/kubernetes/kaito_custom_cpu_model.yaml](../assets/kubernetes/kaito_custom_cpu_model.yaml)

The KAITO `Workspace` custom resource. Key points to discuss with the group:

- `kind: Workspace` is a CRD installed by the KAITO add-on
- `kaito.sh/enablelb: "True"` annotation tells KAITO to also create a `LoadBalancer` Service with a public IP. Convenient for testing; **never do this in production** — there's no auth in front of the model.
- `resource.instanceType: Standard_D16s_v5` — KAITO will spin up a node of this size and schedule the workload there
- `inference.template.spec.containers[0].image: mcr.microsoft.com/aks/kaito/kaito-base:0.0.8` — KAITO's inference base image
- The `args:` list configures `accelerate launch` to serve `bigscience/bloomz-560m` via HuggingFace Transformers on port 5000
- `--trust_remote_code` — note this for the security-aware: it executes Python from the model repo at load time. Fine for `bigscience/bloomz-560m`; review carefully for other models

### 1.7 Initialize Terraform

The `-backend-config="use_azuread_auth=true"` flag tells the azurerm backend to authenticate with your `az login` token (the same Entra ID identity you granted in step 1.4) instead of storage account keys.

**bash:**

```bash
cd ../terraform

terraform init \
  -backend-config="resource_group_name=$RG_NAME" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=kaito-on-aks.tfstate" \
  -backend-config="use_azuread_auth=true"
```

**PowerShell:**

```powershell
cd ../terraform

terraform init `
  -backend-config="resource_group_name=$RG_NAME" `
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" `
  -backend-config="container_name=$STATE_CONTAINER" `
  -backend-config="key=kaito-on-aks.tfstate" `
  -backend-config="use_azuread_auth=true"
```

**Expected output (truncated):**

```text
Initializing the backend...
Successfully configured the backend "azurerm"!

Initializing provider plugins...
- Installing hashicorp/azurerm v4.58.x...
- Installing gavinbunney/kubectl v1.18.x...
- Installing hashicorp/kubernetes v3.0.x...
- Installing azure/azapi v2.8.x...

Terraform has been successfully initialized!
```

Confirm the backend is the Azure storage container you just created (not local). Both shells produce the same file, just use the matching reader:

**bash:**

```bash
grep -E '"type"|"storage_account_name"' .terraform/terraform.tfstate
```

**PowerShell:**

```powershell
Get-Content .terraform/terraform.tfstate | Select-String '"type"|"storage_account_name"'
```

You should see `"type": "azurerm"` and your storage account name.

### 1.8 Plan and apply

To guarantee the next `plan` / `apply` reads and writes state in your Azure storage container (and not a local `terraform.tfstate` left over from a previous run, a different folder, or a teammate's machine), **re-run `terraform init -reconfigure` with the same backend-config flags from step 1.7 immediately before `plan`**. The `-reconfigure` flag forces Terraform to drop any cached backend state and re-attach to the remote backend exactly as you specify; if anything is wrong (wrong storage account, missing RBAC, expired token), it fails here instead of silently writing state to disk.

> **Why no `-out tfplan`?** Terraform plan files are *always* a local on-disk artifact — there is no built-in way to save them to a remote backend. To avoid the misleading impression that anything other than the state file is being persisted remotely, this workshop runs `plan` for review only and lets `apply` re-plan against the same remote state and prompt for confirmation. Every command below reads and writes state directly to/from your azurerm backend with no local plan artifact left behind.

If you stuck with the default `centralus` region you can omit `-var "location=..."`. If you used a different region in step 1.2, add it to both `plan` and the `destroy` in Lab 4.

**bash:**

```bash
terraform init -reconfigure \
  -backend-config="resource_group_name=$RG_NAME" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=kaito-on-aks.tfstate" \
  -backend-config="use_azuread_auth=true"

terraform plan -var "resource_group_name=$RG_NAME"
```

**PowerShell:**

```powershell
terraform init -reconfigure `
  -backend-config="resource_group_name=$RG_NAME" `
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" `
  -backend-config="container_name=$STATE_CONTAINER" `
  -backend-config="key=kaito-on-aks.tfstate" `
  -backend-config="use_azuread_auth=true"

terraform plan -var "resource_group_name=$RG_NAME"
```

The `init` output must end with `Successfully configured the backend "azurerm"!`. If you see anything else (e.g. `Initializing the backend... (no backend)` or a local-state warning), **stop and fix it before applying** — do not proceed with `apply`.

Review the plan output. You should see roughly 3 resources to add (cluster, namespace, workspace) — and **zero** for the resource group and storage account, since those are not Terraform-managed.

**Expected output (final line):**

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

Now apply. Terraform will re-plan against the same remote state, show the diff again, and prompt for `yes` before making any changes — there is no local plan file involved.

**Bash & PowerShell:**

```bash
terraform apply -var "resource_group_name=$RG_NAME"
```

**Expected output (final line):**

```text
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

#### Verify the state file is actually in the remote container

`apply` exiting cleanly is **not** by itself proof that state landed in Azure — Terraform would happily fall back to writing `terraform.tfstate` next to your code if the backend silently degraded. Run all three of these checks after every apply:

**1) No local state file should exist in the working directory.** With a remote backend, the only on-disk artifact is `.terraform/terraform.tfstate`, which is just a *pointer* to the remote backend (you already inspected it in step 1.7). A real `terraform.tfstate` (or `terraform.tfstate.backup`) at the repo root means state is being written locally.

**bash:**

```bash
ls -la terraform.tfstate terraform.tfstate.backup 2>/dev/null \
  && echo "WARNING: local state file found - backend is NOT remote" \
  || echo "OK: no local state file"
```

**PowerShell:**

```powershell
if (Test-Path terraform.tfstate) {
  Write-Host "WARNING: local state file found - backend is NOT remote"
} else {
  Write-Host "OK: no local state file"
}
```

**2) The state blob should be visible in your Azure storage container.** This is the definitive proof — if `kaito-on-aks.tfstate` is listed here, Terraform really did write to the remote backend.

**bash:**

```bash
az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$STATE_CONTAINER" \
  --auth-mode login \
  --query "[].{name:name, size:properties.contentLength, lastModified:properties.lastModified}" \
  --output table
```

**PowerShell:**

```powershell
az storage blob list `
  --account-name $STORAGE_ACCOUNT `
  --container-name $STATE_CONTAINER `
  --auth-mode login `
  --query "[].{name:name, size:properties.contentLength, lastModified:properties.lastModified}" `
  --output table
```

**Expected output:**

```text
Name                  Size    LastModified
--------------------  ------  -------------------------
kaito-on-aks.tfstate  12345   2026-05-04T17:42:10+00:00
```

The `LastModified` timestamp should be within the last few minutes (when `apply` finished). If the blob is missing, your `apply` did not write to the remote backend — re-run the `terraform init -reconfigure` block and apply again.

**3) `terraform state list` reads from whatever backend Terraform currently thinks is active.** Getting your three resources back here proves Terraform is round-tripping state through the azurerm backend, not a stale local copy.

**Bash & PowerShell:**

```bash
terraform state list
```

**Expected output:**

```text
azurerm_kubernetes_cluster.this
kubectl_manifest.bloomz_560m
kubectl_manifest.custom_cpu_inference_namespace
```

> **Heads-up:** AKS provisioning takes ~5–10 minutes, and after that the KAITO controller still needs to provision a node and pull the model. **The `apply` may take 15–25 minutes total before everything is ready.** Use the time to read the [What is KAITO?](../README.md#what-is-kaito) section of the demo README.
>
> **Troubleshooting — `KubernetesVersionNotSupported`:** This workshop pins `kubernetes_version = "1.34.2"`. If that version is no longer offered in your region, run `az aks get-versions --location $LOCATION --output table`, pick a supported one, and update `cluster_version` in [../terraform/main.tf](../terraform/main.tf) `locals` block before re-running `terraform plan`.

### 1.9 Verify the cluster exists

**bash:**

```bash
az aks list --resource-group "$RG_NAME" --output table
```

**PowerShell:**

```powershell
az aks list --resource-group $RG_NAME --output table
```

**Expected output:**

```text
Name                       Location    ResourceGroup       KubernetesVersion    ProvisioningState
-------------------------  ----------  ------------------  -------------------  -----------------
aks-kaito-dev-centralus    centralus   rg-kaito-workshop   1.34.2               Succeeded
```

---

## Lab 2 — Connect and inspect

**Goal:** Connect `kubectl` to the new cluster and walk through everything KAITO created.

**Estimated time:** 15–20 minutes.

### 2.1 Get cluster credentials

Use the command Terraform printed (also in `outputs.tf`):

**bash:**

```bash
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$(terraform output -raw cluster_name)"
```

**PowerShell:**

```powershell
az aks get-credentials `
  --resource-group $RG_NAME `
  --name (terraform output -raw cluster_name)
```

**Expected output:**

```text
Merged "aks-kaito-dev-centralus" as current context in /home/<user>/.kube/config
```

### 2.2 Look at the cluster

```bash
kubectl get nodes
kubectl get namespaces
```

**Expected output (after the KAITO node has been provisioned):**

```text
NAME                                STATUS   ROLES    AGE   VERSION
aks-system-12345678-vmss000000      Ready    <none>   25m   v1.34.2
aks-bloomz-560m-87654321-vmss0000   Ready    <none>   8m    v1.34.2

NAME                          STATUS   AGE
default                       Active   30m
kaito-custom-cpu-inference    Active   28m
kube-node-lease               Active   30m
kube-public                   Active   30m
kube-system                   Active   30m
```

### 2.3 Inspect the KAITO Workspace

```bash
kubectl get workspace -n kaito-custom-cpu-inference
kubectl describe workspace bloomz-560m-workspace -n kaito-custom-cpu-inference
```

**Expected output (`get workspace`):**

```text
NAME                    INSTANCE              RESOURCEREADY   INFERENCEREADY   WORKSPACEREADY   AGE
bloomz-560m-workspace   Standard_D16s_v5      True            True             True             20m
```

Walk through the `Status` block in the `describe` output. KAITO reports:

- `ResourceReady` — the underlying VM/node is up
- `InferenceReady` — the inference pod is healthy
- `WorkspaceReady` — the whole thing is good to go

### 2.4 Watch the inference pod

```bash
kubectl get pods -n kaito-custom-cpu-inference -w
```

**Expected output (states it transitions through):**

```text
NAME                      READY   STATUS              RESTARTS   AGE
bloomz-560m-workspace-0   0/1     Init:0/0            0          5s
bloomz-560m-workspace-0   0/1     ContainerCreating   0          15s
bloomz-560m-workspace-0   0/1     Running             0          45s
bloomz-560m-workspace-0   1/1     Running             0          7m
```

Press `Ctrl+C` once the pod shows `Running` with `Ready 1/1`. On CPU this can take several minutes — the container has to download ~2.2 GB of model weights from HuggingFace before the readiness probe passes.

### 2.5 Tail the logs

**bash:**

```bash
POD=$(kubectl get pods -n kaito-custom-cpu-inference -l app=bloomz-560m -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kaito-custom-cpu-inference "$POD" --tail=100
```

**PowerShell:**

```powershell
$POD = kubectl get pods -n kaito-custom-cpu-inference -l app=bloomz-560m -o jsonpath='{.items[0].metadata.name}'
kubectl logs -n kaito-custom-cpu-inference $POD --tail=100
```

**Expected output (key lines, abridged):**

```text
Downloading config.json: 100%|##########| 715/715
Downloading tokenizer.json: 100%|##########| 14.5M/14.5M
Downloading pytorch_model.bin: 100%|##########| 2.24G/2.24G
[INFO] accelerate.commands.launch: Running on 1 process(es), 1 machine(s)
[INFO] tfs.inference_api: Loading pipeline (text-generation)
[INFO] tfs.inference_api: Model loaded in 142.3s
[INFO] uvicorn: Application startup complete.
[INFO] uvicorn: Uvicorn running on http://0.0.0.0:5000 (Press CTRL+C to quit)
```

### 2.6 Inspect the auto-created LoadBalancer

```bash
kubectl get svc bloomz-560m-workspace -n kaito-custom-cpu-inference
```

**Expected output (once the public IP is assigned):**

```text
NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
bloomz-560m-workspace   LoadBalancer   10.0.123.45    20.123.45.67     80:31234/TCP   18m
```

The `EXTERNAL-IP` column will say `<pending>` for a minute or two while Azure provisions the public IP, then show a real IP. This service was created automatically because of the `kaito.sh/enablelb: "True"` annotation on the `Workspace`.

---

## Lab 3 — Call the model

**Goal:** Send inference requests to the model via the public LoadBalancer endpoint, then optionally from inside the cluster.

**Estimated time:** 15–20 minutes.

### 3.1 Capture the external IP

**bash:**

```bash
KAITO_IP=$(kubectl get svc bloomz-560m-workspace \
  -n kaito-custom-cpu-inference \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "KAITO endpoint: http://$KAITO_IP"
```

**PowerShell:**

```powershell
$KAITO_IP = kubectl get svc bloomz-560m-workspace `
  -n kaito-custom-cpu-inference `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "KAITO endpoint: http://$KAITO_IP"
```

**Expected output:**

```text
KAITO endpoint: http://20.123.45.67
```

### 3.2 Health check

**bash:**

```bash
curl http://$KAITO_IP/health
```

**PowerShell:**

```powershell
curl.exe http://$KAITO_IP/health
```

> **PowerShell tip:** use `curl.exe` (not the `curl` alias) so you get real `curl` and not `Invoke-WebRequest`. Same goes for the POST examples below.

**Expected output:**

```text
Healthy
```

### 3.3 Inspect the API schema

**bash:**

```bash
curl -s http://$KAITO_IP/openapi.json | head
```

**PowerShell:**

```powershell
curl.exe -s http://$KAITO_IP/openapi.json | Select-Object -First 1
```

**Expected output (truncated):**

```json
{"openapi":"3.1.0","info":{"title":"FastAPI","version":"0.1.0"},"paths":{"/health":{"get":{...
```

KAITO exposes a standard OpenAPI-compatible inference API.

### 3.4 Sample prompts

These match the demo in [../README.md](../README.md#testing-with-loadbalancer).

Each response has the same shape: a JSON object with a `Result` field containing the generated text. The exact text varies between runs and model versions — BLOOMZ-560m is small, so don't expect Claude/GPT-quality answers.

```json
{ "Result": "<generated text from the model>" }
```

> **PowerShell:** swap `curl` for `curl.exe` in every example below, otherwise PowerShell's `Invoke-WebRequest` alias will reject the bash-style flags. The flags and JSON body are identical in both shells.

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

---

## Lab 4 — Cleanup

**Goal:** Remove everything created during the workshop so nothing keeps charging your subscription.

**Estimated time:** 10–15 minutes.

> **Order matters.** The state file lives in the storage account inside the workshop resource group. If you delete the RG before `terraform destroy` finishes, you lose the state and Terraform can no longer manage what it created. Always run 4.1 first, confirm success, then move on.

### 4.1 Destroy the Terraform-managed resources

This removes the AKS cluster, the namespace, and the KAITO workspace — the **only** three things Terraform owns. The resource group and the state storage account are not in Terraform state, so they are untouched here.

Like `plan`/`apply`, prefix `destroy` with `terraform init -reconfigure` so it explicitly re-attaches to the remote azurerm backend before touching anything. If your shell session is brand new and the env vars from Lab 1 are gone, re-export `RG_NAME`, `STORAGE_ACCOUNT`, and `STATE_CONTAINER` first.

If you used a non-default region in step 1.2, append `-var "location=<region>"` so Terraform's plan matches the apply.

**bash:**

```bash
terraform init -reconfigure \
  -backend-config="resource_group_name=$RG_NAME" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=kaito-on-aks.tfstate" \
  -backend-config="use_azuread_auth=true"

terraform destroy -var "resource_group_name=$RG_NAME" -auto-approve
```

**PowerShell:**

```powershell
terraform init -reconfigure `
  -backend-config="resource_group_name=$RG_NAME" `
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" `
  -backend-config="container_name=$STATE_CONTAINER" `
  -backend-config="key=kaito-on-aks.tfstate" `
  -backend-config="use_azuread_auth=true"

terraform destroy -var "resource_group_name=$RG_NAME" -auto-approve
```

**Expected output (final line):**

```text
Destroy complete! Resources: 3 destroyed.
```

> **Stop here if destroy failed.** Re-run `terraform destroy` until it reports success before continuing. If you delete the RG with state still active, you'll have orphaned Azure resources you'll need to clean up by hand.

### 4.2 Verify the AKS-managed resource group is gone

When AKS is created, Azure provisions a "node" resource group (typically named `MC_<rg>_<cluster>_<region>`) that holds the VMs, NICs, disks, and load balancer. It should be deleted automatically when the cluster is destroyed — verify:

**Bash & PowerShell:**

```bash
az group list --query "[?starts_with(name, 'MC_${RG_NAME}_')]" --output table
```

**Expected output (when properly cleaned up):**

```text
```

(empty — nothing to list)

If anything is still listed, delete it manually:

**Bash & PowerShell:**

```bash
az group delete --name "<MC_...>" --yes --no-wait
```

### 4.3 Delete the workshop resource group

The RG holds the storage account (and the Terraform state file). Now that step 4.1 succeeded, it's safe to remove:

**bash:**

```bash
az group delete --name "$RG_NAME" --yes --no-wait
```

**PowerShell:**

```powershell
az group delete --name $RG_NAME --yes --no-wait
```

### 4.4 Confirm

**bash:**

```bash
az group show --name "$RG_NAME" 2>&1 | grep -i "could not be found"
```

**PowerShell:**

```powershell
az group show --name $RG_NAME 2>&1 | Select-String "could not be found"
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
