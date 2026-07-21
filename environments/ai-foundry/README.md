# AI Foundry Private Networking Lab

Foundry Agent Service with a **BYO stateful stack** — Storage, Cosmos DB, and AI Search stay in your subscription, wired to Foundry via managed-identity connections + capability hosts, over a fully-private VNet.

Two implementations of the same architecture, side-by-side:

- **Terraform** in [`base/terraform/`](base/terraform/) + [`workload/terraform/`](workload/terraform/) — uses a remote `azurerm` backend (state stored in an Azure Storage account with a Private Endpoint that Terraform itself manages).
- **Bicep** in [`base/bicep/`](base/bicep/) + [`workload/bicep/`](workload/bicep/) — no state to manage; ARM tracks deployment history natively.

Pick one path or the other — they are drop-in equivalents. **Do not run both against the same RG.**

## Architecture

![AI Foundry BYO stateful stack — architecture & deployment](assets/architecture.png)

Source: [`assets/architecture.drawio`](assets/architecture.drawio) &nbsp; · &nbsp; PNG: [`assets/architecture.png`](assets/architecture.png)

**Base stack (both flavours)** creates:
- 1 VNet (`10.0.0.0/16`) + 5 subnets: 4 private-endpoint subnets + 1 agent subnet delegated to `Microsoft.App/environments`
- 11 private DNS zones (3 Cognitive + 6 Storage + Cosmos + Search) linked to the VNet

**Base stack (Terraform ONLY)** additionally creates:
- A **Terraform-state storage account** (`sttfs<hash>`) with a blob Private Endpoint, holding a `tfstate` container that both stacks use as their remote-state backend.
- Bicep users don't need this — ARM tracks its own deployment history.

**Workload stack (both flavours)** creates:
- Foundry account (`AIServices` kind, `project_management_enabled`, agent-subnet network injection) + Private Endpoint
- BYO Storage account (6 PEs: blob/file/queue/table/dfs/web), Cosmos DB (SQL API + 1 PE), AI Search (basic + 1 PE)
- Foundry project + 3 Entra-ID connections + all Phase-3 / Phase-5 RBAC + account & project capability hosts
- All 4 data-plane services default to `public_network_access_enabled = true` with **default-deny** firewall + deployer-IP allowlist

Every private-endpoint-bearing service in the workload stack uses the same posture: local (shared-key/API-key) auth **disabled**, SystemAssigned MI, private endpoint from the VNet, public endpoint restricted to the deployer's IP (which you can strip in the [hardening step](#part-c--harden-remove-deployer-ip-and-close-public-endpoints)).

---

## Prerequisites

- **Windows PowerShell 7+** (all commands below are pwsh).
- **Azure CLI** ≥ 2.60 ([install](https://learn.microsoft.com/cli/azure/install-azure-cli)).
- **`az login`** as a user with subscription-scope **Owner** for the FIRST deploy — you need `roleAssignments/write` (Owner, User Access Administrator, or Role Based Access Administrator) for the workload's Phase-3 / Phase-5 RBAC assignments, PLUS RP registration.
- **Terraform** ≥ 1.7.5 ([install](https://developer.hashicorp.com/terraform/install)) — Path B only.
- **Bicep CLI** ≥ 0.30 (bundled with recent `az`; run `az bicep upgrade` if needed) — Path A only.
- Outbound HTTPS to `https://api.ipify.org` from your laptop (both paths use it to discover your public IP).

Both paths default to region `eastus2` and RG name `rg-ai-foundry-dev`.

---

## Path A — Bicep

### Step 1. Sign in, create the RG, register Resource Providers (~3 min)

```powershell
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>

$RG  = "rg-ai-foundry-dev"
$LOC = "eastus2"

az group create -n $RG -l $LOC --tags environment=dev workload=ai-foundry

foreach ($rp in @(
    'Microsoft.App',
    'Microsoft.CognitiveServices',
    'Microsoft.ContainerInstance',     # backs deploymentScripts (workload's RBAC-propagation sleep)
    'Microsoft.ContainerService',
    'Microsoft.DocumentDB',
    'Microsoft.KeyVault',
    'Microsoft.MachineLearningServices',
    'Microsoft.Network',
    'Microsoft.Search',
    'Microsoft.Storage'
)) { az provider register --namespace $rp --wait }
```

### Step 2. Deploy the base stack (~4 min)

```powershell
$env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()

az deployment group create `
    -g $RG `
    -f environments/ai-foundry/base/bicep/main.bicep `
    -p environments/ai-foundry/base/bicep/main.bicepparam
```

Base doesn't create any firewalled service, but `main.bicepparam` still expects `DEPLOYER_IP` in the environment so both stacks share the same parameterisation pattern.

### Step 3. Deploy the workload stack (~15–20 min)

```powershell
az deployment group create `
    -g $RG `
    -f environments/ai-foundry/workload/bicep/main.bicep `
    -p environments/ai-foundry/workload/bicep/main.bicepparam
```

Your IP (from `$env:DEPLOYER_IP` set in Step 2) is pinned into the firewall on all 4 workload services (Storage, Cosmos, AI Search, Foundry account). This is required because Bicep's ARM engine performs data-plane calls during apply (Cosmos SQL RBAC, Foundry connection provisioning, capability host creation) that go through those firewalls.

### Step 4. Verify

```powershell
az resource list -g $RG --query "[].{name:name, type:type}" -o table
```

You should see: 1 VNet, 5 subnets (child), 11 privateDnsZones, **9 privateEndpoints**, 1 Cognitive account + 1 project, 1 Storage, 1 Cosmos, 1 Search.

---

## Path B — Terraform

Terraform needs somewhere to store state before `terraform apply` can create anything. Since Terraform can't atomically create its own backing store, we **bootstrap the state storage account with `az`** first, then `terraform import` it and let Terraform manage it (including adding its Private Endpoint) from there on.

### Step 1. Sign in, create the RG, grant self blob data access (~2 min)

```powershell
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>

$RG  = "rg-ai-foundry-dev"
$LOC = "eastus2"
$SUB = (az account show --query id -o tsv)
$ME  = (az ad signed-in-user show --query id -o tsv)

az group create -n $RG -l $LOC --tags environment=dev workload=ai-foundry

# Storage Blob Data Contributor at RG scope so `az storage container create --auth-mode login`
# and Terraform's azurerm backend can both authenticate via Entra ID (shared-key access is disabled).
az role assignment create `
    --assignee-object-id $ME `
    --assignee-principal-type User `
    --role "Storage Blob Data Contributor" `
    --scope "/subscriptions/$SUB/resourceGroups/$RG"

# Wait for the role assignment to propagate before using it.
Start-Sleep -Seconds 60
```

### Step 2. Bootstrap the Terraform-state storage account (~2 min)

The state SA name matches what base's `main.tf` will expect: `sttfs<md5(RG + base_name + environment + location)>` truncated to 12 hex chars.

```powershell
$DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()

$hashInput = "${RG}playgrounddev${LOC}"
$md5       = [System.Security.Cryptography.MD5]::Create()
$hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
$HASH      = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
$STATE_SA  = "sttfs" + $HASH.Substring(0, 12)

az storage account create `
    -g $RG -n $STATE_SA -l $LOC `
    --sku Standard_LRS `
    --kind StorageV2 `
    --min-tls-version TLS1_2 `
    --https-only true `
    --allow-blob-public-access false `
    --allow-shared-key-access false `
    --default-action Deny `
    --public-network-access Enabled `
    --bypass AzureServices `
    --ip-address $DEPLOYER_IP

az storage container create `
    --auth-mode login `
    --account-name $STATE_SA `
    -n tfstate
```

### Step 3. Init base with the remote backend + import the bootstrapped SA (~2 min)

```powershell
cd environments/ai-foundry/base/terraform

terraform init `
    -backend-config="resource_group_name=$RG" `
    -backend-config="storage_account_name=$STATE_SA"

terraform import "module.tfstate_storage.azurerm_storage_account.this" `
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STATE_SA"

terraform import "azurerm_storage_container.tfstate" `
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STATE_SA/blobServices/default/containers/tfstate"
```

### Step 4. Apply base (~5 min)

```powershell
terraform apply
```

Terraform adds the blob Private Endpoint on the imported state SA, reconciles blob-service properties (soft-delete, versioning, last-access tracking) to match the module's config, then creates the VNet + 5 subnets + 11 DNS zones with VNet links.

### Step 5. Init workload with remote backend + apply (~15–20 min)

```powershell
cd ../../workload/terraform

terraform init `
    -backend-config="resource_group_name=$RG" `
    -backend-config="storage_account_name=$STATE_SA"

terraform apply
```

The workload's `data.http.myip` auto-detects your IP and pins it into all 4 service firewalls. The Cosmos SQL role assignment + Foundry capability host provisioning both go through the data planes of those services, so they need your IP allowlisted at deploy time.

### Step 6. Verify

```powershell
cd ../..
az resource list -g $RG --query "[].{name:name, type:type}" -o table
```

You should see: 1 VNet, 5 subnets (child), 11 privateDnsZones, **10 privateEndpoints** (Bicep would have 9; Terraform's extra one is on the state SA), 1 Cognitive account + 1 project, 2 Storage (state SA + workload SA), 1 Cosmos, 1 Search.

---

## Redeploy (idempotent)

Both paths are idempotent — rerun the same commands to pick up any change (config edit, code change, or your IP moved because you reconnected the VPN). The IaC reconciles the firewall allowlists automatically.

### Path A — Bicep

```powershell
$env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()

az deployment group create `
    -g $RG `
    -f environments/ai-foundry/workload/bicep/main.bicep `
    -p environments/ai-foundry/workload/bicep/main.bicepparam
```

### Path B — Terraform

If your IP changed, refresh the state SA's firewall allowlist before Terraform can read state (control plane is always reachable regardless of the storage account firewall):

```powershell
$DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
az storage account network-rule add -g $RG -n $STATE_SA --ip-address $DEPLOYER_IP

cd environments/ai-foundry/workload/terraform
terraform apply
```

The ad-hoc `network-rule add` stays as drift on the state SA until the next `base` apply, at which point `data.http.myip` reconciles the full allowlist canonically.

---

## Part C — Harden: remove deployer IP and close public endpoints

Once you've finished a deploy session and want to lock the workload data planes down.

### Path A — Bicep

```powershell
az deployment group create `
    -g $RG `
    -f environments/ai-foundry/workload/bicep/main.bicep `
    -p environments/ai-foundry/workload/bicep/main.bicepparam `
    -p enablePublicNetworkAccess=false `
    -p deployerIp=""
```

All 4 workload data-plane services flip to `publicNetworkAccess = Disabled`. Private endpoints stay wired for the agent runtime.

### Path B — Terraform

```powershell
cd environments/ai-foundry/workload/terraform
terraform apply -var 'enable_public_network_access=false' -var 'deployer_ip='
```

Same result. The state SA stays reachable because base's `enable_public_network_access` is unchanged.

### Un-harden (before your next deploy)

**Path A — Bicep**: rerun Step 3 of Path A (`az deployment group create` with just the bicepparam file — `enablePublicNetworkAccess` and `deployerIp` snap back to their defaults).

**Path B — Terraform**: rerun `terraform apply` in workload with no `-var` flags. Both flags default back to `true` / auto-detect.

---

## Tear down

### Path A — Bicep

```powershell
az group delete -n $RG --yes --no-wait
```

### Path B — Terraform

Remove the state SA + container from Terraform's tracking BEFORE destroying, so `terraform destroy` doesn't try to delete the backend it's currently reading:

```powershell
cd environments/ai-foundry/workload/terraform
terraform destroy

cd ../../base/terraform
terraform state rm 'module.tfstate_storage.azurerm_storage_account.this'
terraform state rm 'azurerm_storage_container.tfstate'
terraform destroy

az group delete -n $RG --yes --no-wait
```

Workload destroy runs first (its resources reference base). Base destroy only removes the VNet + DNS zones because we untracked the tfstate SA + container. The final `az group delete` cleans up the (now orphaned from Terraform, but still in Azure) tfstate SA.

---

## RBAC roster (workload)

The workload's `foundry_project` module grants these to the Foundry project's SystemAssigned MI:

| Phase | Role | Scope | Why |
|---|---|---|---|
| 3 | Cosmos DB Operator | Cosmos account | Foundry creates `enterprise_memory` DB + containers |
| 3 | Storage Account Contributor | Storage account | Foundry creates agent blob containers |
| 5 | Search Index Data Contributor | AI Search | Agents read/write vector indexes |
| 5 | Search Service Contributor | AI Search | Agents create indexes on demand |
| 5 | Storage Blob Data Owner | Storage account | Agents read/write files in the auto-created containers |
| 5 | Cosmos DB Built-in Data Contributor | Cosmos account (SQL role) | Agents read/write threads in `enterprise_memory` |

Terraform waits 60 s (`time_sleep`) between assignments and capability-host provisioning; Bicep waits 60 s via `Microsoft.Resources/deploymentScripts` for the same reason.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `terraform apply` returns `AuthorizationFailed` on the tfstate blob | Your IP changed and isn't allowlisted on the state SA | `az storage account network-rule add -g $RG -n $STATE_SA --ip-address $((Invoke-RestMethod https://api.ipify.org).Trim())` then retry |
| Bicep or Terraform deploy fails on `Microsoft.CognitiveServices/accounts/capabilityHosts` with 403 | RBAC propagation lag (Entra ID replication) | Rerun the deployment; the sleep re-fires and the role assignments are eventually consistent |
| `Microsoft.Storage/storageAccounts` 409 `StorageAccountAlreadyTaken` on the state SA | Your `sttfs<hash>` name collides globally with someone else's account | Override the SA name: `terraform apply -var 'tfstate_storage_account_name=<your-unique-name>'` — pass the same name to `terraform init -backend-config=storage_account_name=...` AND to the manual `az storage account create` in Step 2 |
| First `terraform apply` for base wants to *create* the storage account instead of updating it | You skipped the `terraform import` in Step 3 | Cancel the apply, run the two `terraform import` commands, then rerun `terraform apply` |
| Workload deploys OK but `curl` to a workload endpoint returns 403 | Your IP wasn't the one currently allowlisted, or you hardened | Rerun the workload deploy from the current network; if hardened, use un-harden step above |
| `az storage container create --auth-mode login` returns 403 | RBAC propagation lag on the `Storage Blob Data Contributor` assignment | Wait 30-60 s and retry (Step 1 already includes a `Start-Sleep 60`) |

---

## References

- [Foundry Standard Agent Setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup)
- [Foundry private networking guide](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/virtual-networks)
- [Foundry supported regions for private networking](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions)
- [Terraform azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Bicep language reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
