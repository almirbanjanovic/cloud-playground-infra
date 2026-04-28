## Goal

Create the Azure scaffolding (resource group + Terraform state storage), then use Terraform to deploy an AKS cluster with KAITO enabled and a small CPU model workspace.

> Most of the time spent in this lab is waiting for AKS to provision and the model image to load. Plan for 30–45 minutes.

## 1. Sign in and pick a subscription

```bash
az login
az account set --subscription "<your-subscription-id-or-name>"
az account show --output table
```

## 2. Create the workshop resource group

```bash
RG_NAME="rg-kaito-workshop"
LOCATION="centralus"

az group create --name "$RG_NAME" --location "$LOCATION"
```

> The Terraform code defaults to `centralus`. If you change `LOCATION`, also change the `location` value in the `locals` block of [terraform/main.tf](../../terraform/main.tf), or just stick with `centralus`.

## 3. Create a storage account for Terraform state

```bash
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

## 4. Walk through the Terraform code

Open the files in [terraform/](../../terraform/) and read them before running anything.

### `providers.tf`

Declares four providers and the remote state backend:

- `azurerm` — creates Azure resources
- `azapi` — newer Azure APIs not yet in `azurerm`
- `kubernetes` — talks to the AKS API server
- `kubectl` (gavinbunney) — applies raw YAML manifests; needed because the `kubernetes` provider doesn't natively understand the KAITO `Workspace` CRD

The `backend "azurerm" {}` block is intentionally empty — values are passed at `init` time.

### `variables.tf`

A single input: `resource_group_name`. Everything else is hardcoded in the `locals` block in `main.tf` (this is a demo, not a production module).

### `main.tf`

Three resources, deployed in order:

1. **`azurerm_kubernetes_cluster.this`** — AKS with:
   - Kubernetes 1.34.2
   - 1–5 node autoscaling system pool on `Standard_D2s_v3`
   - OIDC issuer + workload identity enabled
   - **`ai_toolchain_operator_enabled = true`** — the KAITO add-on
2. **`kubectl_manifest.custom_cpu_inference_namespace`** — the `kaito-custom-cpu-inference` namespace
3. **`kubectl_manifest.bloomz_560m`** — the KAITO `Workspace`, rendered from the manifest template via `templatefile()`

### `outputs.tf`

Outputs the cluster name, the `az aks get-credentials` command, the namespace, the workspace/service name, and a one-liner to fetch the LoadBalancer IP.

### `kaito_custom_cpu_model.yaml`

The KAITO `Workspace` custom resource. Key things to notice:

- `kind: Workspace` is a CRD installed by the KAITO add-on.
- `kaito.sh/enablelb: "True"` annotation tells KAITO to create a public `LoadBalancer` Service. Convenient for testing; **never do this in production** — there is no auth in front of the model.
- `resource.instanceType: Standard_D16s_v5` — KAITO will spin up a node of this size and schedule the workload there.
- The `args:` list configures `accelerate launch` to serve `bigscience/bloomz-560m` on port 5000.
- `--trust_remote_code` — note for security: this executes Python from the model repo at load time. Fine for `bigscience/bloomz-560m`; review carefully for other models.

## 5. Initialize Terraform

```bash
cd terraform

terraform init \
  -backend-config="resource_group_name=$RG_NAME" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=kaito-on-aks.tfstate"
```

## 6. Plan and apply

```bash
terraform plan -var "resource_group_name=$RG_NAME"
terraform apply -var "resource_group_name=$RG_NAME" -auto-approve
```

> AKS provisioning takes ~5–10 minutes, then the KAITO controller still needs to provision a node and pull the model. **Total `apply` time can be 15–25 minutes.**

## 7. Verify

```bash
az aks list --resource-group "$RG_NAME" --output table
```

When the cluster shows `Succeeded`, move on to the next unit.
