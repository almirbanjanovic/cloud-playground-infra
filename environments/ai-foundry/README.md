# AI Foundry Private Networking Lab

Foundry Agent Service with a **BYO stateful stack** — Storage, Cosmos DB, and AI Search stay in your subscription, wired to Foundry via managed-identity connections + capability hosts, over a fully-private VNet.

Two implementations of the same architecture, side-by-side:

- **Path A — Bicep** in [`base/bicep/`](base/bicep/) + [`workload/bicep/`](workload/bicep/). No state to manage; ARM tracks deployment history natively.
- **Path B — Terraform** in [`base/terraform/`](base/terraform/) + [`workload/terraform/`](workload/terraform/). Uses a remote `azurerm` backend; the state Storage account itself is bootstrapped with `az`, then imported so Terraform manages it (including adding its Private Endpoint) from there.

Pick one path. **Do not run both against the same RG** — they'd fight over the same names.

## Architecture

![AI Foundry BYO stateful stack — architecture & deployment](assets/architecture.png)

Source: [`assets/architecture.drawio`](assets/architecture.drawio) &nbsp; · &nbsp; PNG: [`assets/architecture.png`](assets/architecture.png)

The diagram shows the runtime architecture that both paths provision. Path B additionally bootstraps a Terraform-state Storage account with a blob Private Endpoint — a Terraform mechanism, not part of the deployed application — described in Path B Step 2 but intentionally omitted from the diagram.

**Base stack (both paths)** creates:
- 1 VNet (`10.0.0.0/16`) + 5 subnets: 4 private-endpoint subnets + 1 agent subnet delegated to `Microsoft.App/environments`
- 11 private DNS zones (3 Cognitive + 6 Storage + Cosmos + Search) linked to the VNet

**Base stack (Path B only)** additionally bootstraps:
- A **Terraform-state Storage account** (`sttfs<hash>`) with a blob Private Endpoint, holding a `tfstate` container that both stacks use as their remote-state backend. Path A doesn't need this — ARM tracks its own deployment history.

**Workload stack (both paths)** creates:
- Foundry account (`AIServices` kind, project management enabled, agent-subnet network injection) + Private Endpoint
- BYO Storage account (6 PEs: blob/file/queue/table/dfs/web), Cosmos DB (SQL API + 1 PE), AI Search (basic + 1 PE)
- Foundry project + 3 Entra-ID connections + all Phase-3 / Phase-5 RBAC + account & project capability hosts
- All 4 data-plane services default to **public network access enabled** with a **default-deny** firewall + deployer-IP allowlist

Every private-endpoint-bearing service uses the same posture: local (shared-key/API-key) auth **disabled**, SystemAssigned MI, private endpoint from the VNet, public endpoint restricted to the deployer's IP (which you can strip in the [hardening step](#part-c--harden-remove-deployer-ip-and-close-public-endpoints)).

---

## Prerequisites

- **Windows PowerShell 7+** — all commands below are pwsh. **Keep one session open for the whole deploy** so shell variables persist. If you close and reopen, re-run Step 1 (both paths) and Step 2 (Path B) before continuing.
- **Azure CLI** ≥ 2.60 ([install](https://learn.microsoft.com/cli/azure/install-azure-cli)).
- **`az login`** — for the FIRST deploy you need a role with `roleAssignments/write` at the target scope (**Owner**, **User Access Administrator**, or **Role Based Access Control Administrator**) for the workload's Phase-3 / Phase-5 RBAC assignments. RP registration by itself only needs `*/register/action` (**Contributor** is sufficient), so a returning deployer with existing role assignments can drop to Contributor.
- **Terraform** ≥ 1.7.5 ([install](https://developer.hashicorp.com/terraform/install)) — Path B only.
- **Bicep CLI** ≥ 0.30 (bundled with recent `az`; run `az bicep upgrade` if needed) — Path A only.
- Outbound HTTPS to `https://api.ipify.org` from your laptop.

Each deploy step below **starts with a `Set-Location` (`cd`) into the specific stack directory** — `environments/ai-foundry/base/bicep`, `environments/ai-foundry/base/terraform`, `environments/ai-foundry/workload/bicep`, or `environments/ai-foundry/workload/terraform` — and all Bicep / Terraform commands in that step use short relative paths (`main.bicep`, `.`) from there. If a command errors with `Could not find ...\main.bicep` or Terraform picks up the wrong module, check `Get-Location` — you're in the wrong directory. Sign-in / variable-setup steps and `az` verification commands don't depend on your working directory, so you can run them from anywhere.

Both paths default to region `eastus2` and RG name `rg-ai-foundry-dev-eastus2`.

---

## Path A — Bicep

### Step 1. Sign in, create the RG, register Resource Providers (~3 min)

These are all `az` commands — no working-directory dependency. Run them from anywhere.

Sign in and pin the subscription:

```powershell
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>
az account show --query "{Subscription:name, Id:id, Tenant:tenantId}" -o table
```

Set naming variables and echo:

```powershell
$LOC = "eastus2"
$RG  = "rg-ai-foundry-dev-$LOC"
Write-Host "LOC = $LOC"
Write-Host "RG  = $RG"
```

Create the RG:

```powershell
az group create -n $RG -l $LOC --tags environment=dev workload=ai-foundry
az group show -n $RG --query "{Name:name, Location:location, State:properties.provisioningState}" -o table
```

Expected: `Succeeded` in the `State` column.

Register Resource Providers, then show the state for all of them in one query:

```powershell
$rps = @(
    'Microsoft.App',
    'Microsoft.CognitiveServices',
    'Microsoft.ContainerInstance',        # backs deploymentScripts (workload's RBAC-propagation sleep)
    'Microsoft.ContainerService',         # AKS API backing Microsoft.App environments
    'Microsoft.DocumentDB',
    'Microsoft.KeyVault',
    'Microsoft.MachineLearningServices',
    'Microsoft.Network',
    'Microsoft.Search',
    'Microsoft.Storage'
)
foreach ($rp in $rps) { az provider register --namespace $rp --wait }

$rpList = "'" + ($rps -join "','") + "'"
az provider list --query "[?contains([$rpList], namespace)].{Namespace:namespace, State:registrationState}" -o table
```

Expected: every row shows `Registered`.

### Step 2. Deploy the base stack (~4 min)

Base creates the VNet + 5 subnets + 11 private DNS zones with VNet links. No IP allowlisting needed — none of these are firewalled services.

`cd` into the base Bicep directory:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/base/bicep
Get-Location   # expect: ...\environments\ai-foundry\base\bicep
```

Deploy:

```powershell
az deployment group create `
    -g $RG `
    -n base-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam
```

Verify:

```powershell
az resource list -g $RG --query "[?type=='Microsoft.Network/virtualNetworks' || type=='Microsoft.Network/privateDnsZones'].{Name:name, Type:type}" -o table
```

Expected: 1 VNet (`vnet-ai-foundry-dev-eastus2`) + 11 privateDnsZones.

### Step 3. Deploy the workload stack (~15–20 min)

`cd` into the workload Bicep directory:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/bicep
Get-Location   # expect: ...\environments\ai-foundry\workload\bicep
```

Set your public IP as an environment variable (Bicep's `main.bicepparam` reads it via `readEnvironmentVariable('DEPLOYER_IP', '')`):

```powershell
$env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
Write-Host "DEPLOYER_IP = $env:DEPLOYER_IP"
```

Deploy:

```powershell
az deployment group create `
    -g $RG `
    -n workload-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam
```

Verify the 4 data-plane services and the 9 workload PEs:

```powershell
az resource list -g $RG --query "[?type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.Storage/storageAccounts' || type=='Microsoft.DocumentDB/databaseAccounts' || type=='Microsoft.Search/searchServices'].{Name:name, Type:type}" -o table
az resource list -g $RG --resource-type Microsoft.Network/privateEndpoints --query "length(@)" -o tsv
```

Expected: 1 Cognitive account + 1 Storage + 1 Cosmos + 1 Search; PE count = **9** (1 Foundry + 6 Storage sub-resources + 1 Cosmos + 1 Search).

Why the IP is required *at deploy time*: the workload deployment performs data-plane calls from your laptop's `az` session (Cosmos SQL role provisioning, Foundry connection creation, capability-host creation), and those calls hit each service's firewall directly — the RP orchestrating the deploy does the control-plane resource creation, but the data-plane side-effects go through your laptop.

### Step 4. Full inventory

```powershell
az resource list -g $RG --query "sort_by([], &type)[].{Name:name, Type:type}" -o table
```

Expected: 1 VNet, 5 subnets, 11 privateDnsZones, 9 privateEndpoints, 1 Cognitive account + 1 project, 1 Storage, 1 Cosmos, 1 Search.

---

## Path B — Terraform

Terraform can't atomically create its own backing store, so the flow has one extra step at the top: **bootstrap the state storage account with `az`**, then `terraform import` it and let Terraform manage it (including adding its Private Endpoint) from there.

### Step 1. Sign in, create the RG, register Resource Providers, grant blob data access (~3 min)

These are all `az` commands — no working-directory dependency. Run them from anywhere.

Sign in and set variables:

```powershell
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>

$LOC = "eastus2"
$RG  = "rg-ai-foundry-dev-$LOC"
$SUB = (az account show --query id -o tsv)
$ME  = (az ad signed-in-user show --query id -o tsv)

Write-Host "LOC = $LOC"
Write-Host "RG  = $RG"
Write-Host "SUB = $SUB"
Write-Host "ME  = $ME"
```

Expected: all four echoes non-empty; `SUB` looks like a GUID, `ME` looks like a GUID.

Create the RG:

```powershell
az group create -n $RG -l $LOC --tags environment=dev workload=ai-foundry
az group show -n $RG --query "{Name:name, Location:location, State:properties.provisioningState}" -o table
```

Register Resource Providers (Terraform's `resource_provider_registrations = "none"` means Terraform will NOT auto-register, so this is required):

```powershell
$rps = @(
    'Microsoft.App',
    'Microsoft.CognitiveServices',
    'Microsoft.ContainerInstance',
    'Microsoft.ContainerService',
    'Microsoft.DocumentDB',
    'Microsoft.KeyVault',
    'Microsoft.MachineLearningServices',
    'Microsoft.Network',
    'Microsoft.Search',
    'Microsoft.Storage'
)
foreach ($rp in $rps) { az provider register --namespace $rp --wait }

$rpList = "'" + ($rps -join "','") + "'"
az provider list --query "[?contains([$rpList], namespace)].{Namespace:namespace, State:registrationState}" -o table
```

Expected: every row shows `Registered`.

Grant yourself `Storage Blob Data Contributor` at RG scope so `az storage container create --auth-mode login` and Terraform's `azurerm` backend can both authenticate via Entra ID (shared-key access is disabled on the state SA):

```powershell
az role assignment create `
    --assignee-object-id $ME `
    --assignee-principal-type User `
    --role "Storage Blob Data Contributor" `
    --scope "/subscriptions/$SUB/resourceGroups/$RG"

# Wait for the role assignment to propagate before using it.
Start-Sleep -Seconds 60

az role assignment list --assignee $ME --scope "/subscriptions/$SUB/resourceGroups/$RG" --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{Role:roleDefinitionName, Scope:scope}" -o table
```

Expected: one row with `Storage Blob Data Contributor` at the RG scope.

### Step 2. Bootstrap the Terraform-state Storage account (~2 min)

Detect your IP and derive the state SA name (`sttfs<md5(RG + base_name + environment + location)>` truncated to 12 hex chars — must match what base's `main.tf` will compute):

```powershell
$DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
$BASE_NAME   = "ai-foundry"        # must match base_name default in variables.tf
$ENVIRONMENT = "dev"               # must match environment default in variables.tf

$hashInput = "${RG}${BASE_NAME}${ENVIRONMENT}${LOC}"
$md5       = [System.Security.Cryptography.MD5]::Create()
$hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
$HASH      = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
$STATE_SA  = "sttfs" + $HASH.Substring(0, 12)

Write-Host "DEPLOYER_IP = $DEPLOYER_IP"
Write-Host "STATE_SA    = $STATE_SA"
```

Expected: `DEPLOYER_IP` is a public IPv4; `STATE_SA` is 17 chars starting with `sttfs`.

Create the storage account:

```powershell
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

az storage account show -g $RG -n $STATE_SA --query "{Name:name, SKU:sku.name, PublicNetwork:publicNetworkAccess, TLS:minimumTlsVersion, SharedKey:allowSharedKeyAccess}" -o table
```

Expected: `SKU = Standard_LRS`, `TLS = TLS1_2`, `SharedKey = False`.

> **If this returns `StorageAccountAlreadyTaken`** (the derived `sttfs<hash>` name collides globally), pick a unique name and use it for the remainder of Path B — including `terraform init`, the `terraform import` commands, and the `-var 'tfstate_storage_account_name=...'` you'll pass to `terraform apply`:
> ```powershell
> $STATE_SA = "sttfs<something-unique>"   # then rerun the `az storage account create` above
> ```

Create the `tfstate` container:

```powershell
az storage container create `
    --auth-mode login `
    --account-name $STATE_SA `
    -n tfstate

az storage container list --auth-mode login --account-name $STATE_SA --query "[].{Name:name, PublicAccess:publicAccess}" -o table
```

Expected: `tfstate` container present with `PublicAccess = None`.

### Step 3. Init base with the remote backend + import the bootstrapped SA (~2 min)

`cd` into the base Terraform directory — everything in Steps 3 and 4 runs from here:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/base/terraform
Get-Location   # expect: ...\environments\ai-foundry\base\terraform
```

Init:

```powershell
terraform init `
    -backend-config="resource_group_name=$RG" `
    -backend-config="storage_account_name=$STATE_SA"
```

Expected: `Terraform has been successfully initialized!`

Import the storage account and its container so Terraform manages them going forward:

```powershell
terraform import `
    "module.tfstate_storage.azurerm_storage_account.this" `
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STATE_SA"

terraform import `
    "azurerm_storage_container.tfstate" `
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STATE_SA/blobServices/default/containers/tfstate"

terraform state list
```

Expected: at minimum `azurerm_storage_container.tfstate` and `module.tfstate_storage.azurerm_storage_account.this` present in the list.

### Step 4. Apply base (~5 min)

Still in `environments/ai-foundry/base/terraform` from Step 3. If you overrode `$STATE_SA` from the default, pass it as a variable — otherwise omit the `-var` flag:

```powershell
terraform apply `
    -var "tfstate_storage_account_name=$STATE_SA"
```

Terraform reconciles the imported state SA (adds its blob PE, applies blob-service properties: 30-day soft delete + versioning + last-access tracking), then creates the VNet + 5 subnets + 11 DNS zones with VNet links.

Verify:

```powershell
az resource list -g $RG --query "[?type=='Microsoft.Network/virtualNetworks' || type=='Microsoft.Network/privateDnsZones' || type=='Microsoft.Network/privateEndpoints'].{Name:name, Type:type}" -o table
```

Expected: 1 VNet, 11 privateDnsZones, **1 privateEndpoint** (on the state SA).

### Step 5. Init workload with remote backend + apply (~15–20 min)

`cd` into the workload Terraform directory:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/terraform
Get-Location   # expect: ...\environments\ai-foundry\workload\terraform
```

Init points at the same tfstate SA as base, but with a different blob key (`workload.tfstate`):

```powershell
terraform init `
    -backend-config="resource_group_name=$RG" `
    -backend-config="storage_account_name=$STATE_SA"
```

Apply:

```powershell
terraform apply
```

The workload's `data.http.myip` auto-detects your IP and pins it into all 4 service firewalls. The Cosmos SQL role assignment + Foundry capability host provisioning both perform data-plane calls from your laptop, so your IP must be allowlisted at deploy time.

### Step 6. Full inventory

```powershell
az resource list -g $RG --query "sort_by([], &type)[].{Name:name, Type:type}" -o table
```

Expected: 1 VNet, 5 subnets, 11 privateDnsZones, **10 privateEndpoints** (Path A would have 9; Path B's extra PE is on the state SA), 1 Cognitive account + 1 project, 2 Storage (state SA + workload SA), 1 Cosmos, 1 Search.

---

## Redeploy

Both paths are idempotent — rerun the deploy commands to pick up any change (config edit, code change, or your IP moved because you reconnected the VPN). The IaC reconciles firewall allowlists automatically.

> **If you're in a new terminal session, redefine variables first** — re-run Step 1 for both paths, plus Step 2's `$STATE_SA` derivation for Path B.

### Path A — Bicep

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/bicep

$env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()

az deployment group create `
    -g $RG `
    -n workload-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam
```

### Path B — Terraform

If your IP changed since the last apply, refresh the state SA's firewall allowlist first (Storage's control plane is always reachable regardless of the data-plane firewall — that's how this ad-hoc rule gets added):

```powershell
$DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
az storage account network-rule add -g $RG -n $STATE_SA --ip-address $DEPLOYER_IP
```

Then apply workload:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/terraform

terraform apply
```

The ad-hoc network-rule stays as drift on the state SA until the next `base` apply, at which point `data.http.myip` reconciles the full allowlist canonically.

---

## Part C — Harden: remove deployer IP and close public endpoints

Once you've finished a deploy session, lock the workload data planes down.

### Path A — Bicep

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/bicep

az deployment group create `
    -g $RG `
    -n harden-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam `
    -p enablePublicNetworkAccess=false `
    -p deployerIp=""
```

Verify all 4 services flipped to `Disabled`:

```powershell
az cognitiveservices account show -g $RG -n "cog-acc-ai-foundry-dev-eastus2" --query "properties.publicNetworkAccess" -o tsv
az storage account list -g $RG --query "[?!contains(name, 'sttfs')].{Name:name, PublicNetwork:publicNetworkAccess}" -o table
az cosmosdb list -g $RG --query "[].{Name:name, PublicNetwork:publicNetworkAccess}" -o table
az search service list -g $RG --query "[].{Name:name, PublicNetwork:publicNetworkAccess}" -o table
```

Expected: `Disabled` for the Foundry account, the workload Storage account (not the state SA), Cosmos, and Search.

### Path B — Terraform

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/terraform

terraform apply `
    -var 'enable_public_network_access=false' `
    -var 'deployer_ip='
```

Same result. Verify identically to Path A.

### Un-harden (before your next deploy)

**Path A — Bicep**: rerun Path A Step 3 exactly as written (including the `cd` into `environments/ai-foundry/workload/bicep`) — `$env:DEPLOYER_IP` gets re-read from the current session, and `enablePublicNetworkAccess` falls back to its default (`true`).

**Path B — Terraform**: `cd` into `environments/ai-foundry/workload/terraform` and rerun `terraform apply` with no `-var` flags. `enable_public_network_access` defaults back to `true` and `deployer_ip` re-auto-detects via `data.http.myip`.

---

## Tear down

### Path A — Bicep

```powershell
az group delete -n $RG --yes --no-wait
az group exists -n $RG
```

Expected: `false` once the async delete completes (typically 2–5 min).

### Path B — Terraform

Remove the state SA + container from Terraform's tracking BEFORE destroying, so `terraform destroy` on base doesn't try to delete the backend it's currently reading state from.

First, destroy the workload stack:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/terraform

terraform destroy
```

Then switch to base, untrack the state SA + container, and destroy:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/base/terraform

terraform state rm 'module.tfstate_storage.azurerm_storage_account.this'
terraform state rm 'azurerm_storage_container.tfstate'
terraform destroy
```

Finally, delete the RG (which cleans up the still-in-Azure, no-longer-in-Terraform tfstate SA + container):

```powershell
az group delete -n $RG --yes --no-wait
az group exists -n $RG
```

Workload destroy runs first (its resources reference base). Base destroy only removes the VNet + DNS zones because we untracked the tfstate SA + container. The final `az group delete` cleans up the (still in Azure, no longer in Terraform) tfstate SA and its container.

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

Terraform waits 60 s via `time_sleep` between assignments and capability-host provisioning; Bicep does the same via a `Microsoft.Resources/deploymentScripts` resource with `forceUpdateTag: utcNow()` (which makes it re-fire on every apply).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `terraform apply` fails reading state with an authorization / 403 on the tfstate blob | Your IP changed and isn't allowlisted on the state SA firewall | `az storage account network-rule add -g $RG -n $STATE_SA --ip-address $((Invoke-RestMethod https://api.ipify.org).Trim())` then retry |
| `az storage account create` in Path B Step 2 returns `StorageAccountAlreadyTaken` | Your derived `sttfs<hash>` name collides globally with someone else's account | See the collision note **inside Path B Step 2** — pick a unique name for `$STATE_SA` and re-run Step 2 with it; carry the same value through `terraform init` and the `-var 'tfstate_storage_account_name=...'` in Step 4 |
| Bicep or Terraform deploy fails on `Microsoft.CognitiveServices/accounts/capabilityHosts` with 403 | RBAC propagation lag (Entra ID replication) between the workload's role assignments and the data-plane call to create the capability host | Rerun the deployment. Bicep's `deploymentScripts` re-fires its 60 s sleep on every apply (via `forceUpdateTag: utcNow()`). Terraform's `time_sleep` will NOT re-fire if already in state — if the retry still 403s, force the sleep to re-run from `environments/ai-foundry/workload/terraform`: `terraform apply -replace='module.foundry_project.time_sleep.wait_for_rbac_propagation'` |
| First `terraform apply` for base in Path B Step 4 wants to *create* the state SA instead of updating it | You skipped the `terraform import` commands in Path B Step 3 | Cancel the apply, run the two `terraform import` commands from Step 3, then rerun `terraform apply` |
| Workload deployed OK but hitting a workload endpoint (e.g. `Invoke-RestMethod` to the Foundry account) returns 403 | Your public IP isn't currently allowlisted, or you ran the [hardening step](#part-c--harden-remove-deployer-ip-and-close-public-endpoints) | Rerun the workload deploy from the current network to reconcile the allowlist; if hardened, follow the [un-harden step](#un-harden-before-your-next-deploy) |
| `az storage container create --auth-mode login` returns 403 | RBAC propagation lag on the `Storage Blob Data Contributor` assignment | Wait 30-60 s and retry (Path B Step 1 already includes a `Start-Sleep 60`) |

---

## References

- [Foundry Standard Agent Setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup)
- [Foundry private networking guide](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/virtual-networks)
- [Foundry supported regions for private networking](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions)
- [Terraform azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Bicep language reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
