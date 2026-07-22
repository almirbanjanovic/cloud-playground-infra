# AI Foundry Private Networking Lab

Foundry Agent Service with a **BYO stateful stack** — Storage, Cosmos DB, and AI Search stay in your subscription, wired to Foundry via managed-identity connections + capability hosts, over a fully-private VNet.

This lab follows the [Cloud Adoption Framework (CAF) landing-zone pattern](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/network-topology-and-connectivity) for network topology: **networking / platform resources live in a dedicated networking RG**, and **workload data-plane resources live in a separate per-workload RG**. This mirrors production CAF landing zones where a central platform team owns and manages shared networking (VNets, private DNS zones, subnets), and application teams deploy their workloads cross-RG on top of it.

Two implementations of the same architecture, side-by-side:

- **Path A — Bicep** in [`base/bicep/`](base/bicep/) + [`workload/bicep/`](workload/bicep/). No state to manage; ARM tracks deployment history natively.
- **Path B — Terraform** in [`base/terraform/`](base/terraform/) + [`workload/terraform/`](workload/terraform/). Uses a remote `azurerm` backend; the state Storage account itself is bootstrapped with `az`, then imported so Terraform manages it (including adding its Private Endpoint) from there.

Pick one path. Don't mix Path A + Path B against the same RGs — the two paths use identical naming conventions and would fight over resource names.

## Architecture

![AI Foundry BYO stateful stack — architecture & deployment](assets/architecture.png)

Source: [`assets/architecture.drawio`](assets/architecture.drawio) &nbsp; · &nbsp; PNG: [`assets/architecture.png`](assets/architecture.png)

The diagram shows the runtime architecture that both paths provision. Path B additionally bootstraps a Terraform-state Storage account with a blob Private Endpoint — a Terraform mechanism, not part of the deployed application — described in Path B Step 2 but intentionally omitted from the diagram.

**Base stack (both paths)** — deploys into the **networking RG** (`rg-ai-foundry-network-dev-westus3` by default):
- 1 VNet (`10.0.0.0/16`) + 5 subnets: 4 private-endpoint subnets + 1 agent subnet delegated to `Microsoft.App/environments`
- 11 private DNS zones (3 Cognitive + 6 Storage + Cosmos + Search) linked to the VNet

**Base stack (Path B only)** additionally bootstraps (into the networking RG):
- A **Terraform-state Storage account** (`sttfs<hash>`) with a blob Private Endpoint, holding a `tfstate` container that both stacks use as their remote-state backend. Path A doesn't need this — ARM tracks its own deployment history.

**Workload stack (both paths)** — deploys into the **workload RG** (`rg-ai-foundry-workload-dev-westus3` by default) and looks up base's VNet + DNS zones cross-RG:
- Foundry account (`AIServices` kind, project management enabled, agent-subnet network injection) + Private Endpoint
- BYO Storage account (6 PEs: blob/file/queue/table/dfs/web), Cosmos DB (SQL API + 1 PE), AI Search (standard + 1 PE)
- Foundry project + 3 Entra-ID connections + all Phase-3 / Phase-5 RBAC + account & project capability hosts
- All 4 data-plane services default to **public network access enabled** with a **default-deny** firewall + deployer-IP allowlist

Every private-endpoint-bearing service uses the same posture: local (shared-key/API-key) auth **disabled**, SystemAssigned MI, private endpoint from the VNet, public endpoint restricted to the deployer's IP (which you can strip in the [hardening step](#part-c--harden-remove-deployer-ip-and-close-public-endpoints)).

### DNS zones + private endpoints

The base stack creates **11 private DNS zones**, all VNet-linked, matching the authoritative Microsoft [private endpoint DNS zone table](https://learn.microsoft.com/azure/private-link/private-endpoint-dns):

| Service | Subresource / groupId | Zone (Azure public cloud) |
|---|---|---|
| Foundry account (`Microsoft.CognitiveServices/accounts`, kind=AIServices) | `account` | `privatelink.cognitiveservices.azure.com` + `privatelink.openai.azure.com` + `privatelink.services.ai.azure.com` (all three are required for Foundry Standard Setup) |
| Storage account (`Microsoft.Storage/storageAccounts`) | `blob` / `file` / `queue` / `table` / `dfs` / `web` | `privatelink.<subresource>.core.windows.net` (6 zones) |
| Cosmos DB (`Microsoft.DocumentDB/databaseAccounts`, SQL API) | `Sql` | `privatelink.documents.azure.com` |
| AI Search (`Microsoft.Search/searchServices`) | `searchService` | `privatelink.search.windows.net` |

Total: 3 + 6 + 1 + 1 = **11 zones**. Base VNet-links them BEFORE the workload's PEs are created so `privateDnsZoneGroups` auto-register the PE A-records at creation time. Bicep derives the storage suffix via `az.environment().suffixes.storage` for cross-cloud portability; the other 3 zone names are hardcoded to commercial-cloud values. **Sovereign-cloud deploys (Azure Gov / China) need to override `cosmosPrivateDnsZoneName`, `searchPrivateDnsZoneName`, and (in Terraform only) `storagePrivateDnsZoneNames` to their cloud-specific values** — see the MS DNS zone table's Government / China sections.

**On storage PE breadth:** we create all 6 storage subresource PEs (blob/file/queue/table/dfs/web) for symmetry with Microsoft's general private-endpoint patterns. Foundry Agent Service Standard Setup itself only *uses* `blob` at runtime — the other 5 are ~$35/month of belt-and-braces provisioning that lets you later use File Share, Queue-backed Function tools, ADLS Gen2, or Static Web hosting without changing the network topology. If cost matters and you know you'll only use blob, pass empty arrays for the 5 unused subresources' `*PrivateDnsZoneIds` params on the storage_account module (Bicep) / `*_private_dns_zone_ids` variables (Terraform) — the module skips creating a PE for any subresource with an empty zone list.

---

## Prerequisites

- **Windows PowerShell 7+** — all commands below are pwsh. **Keep one session open for the whole deploy** so shell variables persist. If you close and reopen, re-run Step 1 (both paths) and Step 2 (Path B) before continuing.
- **Azure CLI** ≥ 2.60 ([install](https://learn.microsoft.com/cli/azure/install-azure-cli)).
- **`az login` with sufficient permissions.** For a FIRST deploy the caller needs several permission classes across both RGs. **The simplest posture is `Owner` at the subscription** — it covers everything below. For least-privilege deploys, the caller needs all of these at the corresponding scopes:

  | Permission | Where | Why |
  |---|---|---|
  | Resource creation (Contributor covers this) | Both RGs | Create/update the VNet, subnets, DNS zones, Storage, Cosmos, AI Search, Foundry account, project, PEs, connections, capability host |
  | `Microsoft.Authorization/roleAssignments/write` (**User Access Administrator** or **Role Based Access Control Administrator**) | Workload RG | Create the 5 `Microsoft.Authorization/roleAssignments` the workload grants to the project MI on Storage / Cosmos / AI Search |
  | `Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments/write` (**Cosmos DB Operator** on the Cosmos account, or Contributor at sub/RG scope) | Workload RG (Cosmos account) | Create the Cosmos SQL data-plane role assignment for the project MI. This is a Cosmos-native RBAC resource, NOT `Microsoft.Authorization/roleAssignments` — **UAA and RBAC Admin do NOT include it.** |
  | `Microsoft.Network/privateDnsZones/join/action` (**Private DNS Zone Contributor** or higher) | Networking RG (private DNS zones) | Link the 9 workload PEs' DNS zone groups to the private DNS zones that live in the networking RG (per the [CAF split-RG topology](#deployment-topology-public-path-vs-private-path)). Same-RG deployers skip this. |

  RP registration by itself only needs `*/register/action` (Contributor at sub scope is sufficient). Returning deployers with all existing role assignments and DNS zone group links can drop to Contributor for subsequent redeploys.
- **Terraform** ≥ 1.7.5 ([install](https://developer.hashicorp.com/terraform/install)) — Path B only.
- **Bicep CLI** ≥ 0.30 (bundled with recent `az`; run `az bicep upgrade` if needed) — Path A only.
- Outbound HTTPS to `https://api.ipify.org` from your laptop (skip if you're on the [private-path deploy](#deployment-topology-public-path-vs-private-path)).

Each deploy step below **starts with a `Set-Location` (`cd`) into the specific stack directory** — `environments/ai-foundry/base/bicep`, `environments/ai-foundry/base/terraform`, `environments/ai-foundry/workload/bicep`, or `environments/ai-foundry/workload/terraform` — and all Bicep / Terraform commands in that step use short relative paths (`main.bicep`, `.`) from there. If a command errors with `Could not find ...\main.bicep` or Terraform picks up the wrong module, check `Get-Location` — you're in the wrong directory. Sign-in / variable-setup steps and `az` verification commands don't depend on your working directory, so you can run them from anywhere.

Both paths default to region `westus3` and the CAF split-RG layout:

| Stack | Default RG name | Contents |
|---|---|---|
| Base (networking) | `rg-ai-foundry-network-dev-westus3` | VNet, subnets, private DNS zones (+ tfstate SA for Path B) |
| Workload (data plane) | `rg-ai-foundry-workload-dev-westus3` | Foundry, Storage, Cosmos, AI Search + all workload private endpoints |

---

## Deployment topology: public path vs private path

The workload data-plane services (Storage, Cosmos, AI Search, Foundry) all sit behind private endpoints, but their **public endpoints stay `Enabled` by default** with a default-deny firewall + explicit allowlist. The allowlist mostly exists for the **post-deploy** admin / SDK operations you're likely to run from the deployer's machine — opening the Foundry portal, listing Cosmos containers with `az cosmosdb sql container list`, uploading a test blob with `az storage blob upload`, running the Python Foundry SDK, etc. All of those go straight to the service's public FQDN and get blocked by the default-deny firewall unless your IP is on the allowlist.

During the deploy itself, the picture is subtler: the workload's IaC provisions resources like `Microsoft.CognitiveServices/accounts/connections`, `Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments`, and `Microsoft.CognitiveServices/accounts/projects/capabilityHosts`. These are **ARM control-plane** operations — the deployer's `az` session calls `management.azure.com`, and Azure's own RPs then talk to the target services internally (via the `bypass = AzureServices` trusted-services path that all four workload modules set). So the deploy usually succeeds even without an allowlist entry for the deployer. The IP allowlist matters most for what you'll do with the deployment afterward.

Two supported topologies. Both use the same IaC; only the value you pass for `deployerIp` (Bicep) / `deployer_ip` (Terraform) differs.

| Topology | Deployer machine is… | Post-deploy admin traffic | `deployerIp` value | Typical use |
|---|---|---|---|---|
| **Public path** (default) | On the public internet (laptop at home, unmanaged network) | Deployer → public FQDN → firewall allowlist → service | Your public IPv4 (auto-detected in Path B via `api.ipify.org`; read from `$env:DEPLOYER_IP` in Path A) | Personal / lab deploys from an unmanaged network |
| **Private path** | On a corporate network with VPN / ExpressRoute / Bastion into the workload VNet, or on a jump box / CI runner already in the VNet (see [`iac-modules/terraform/cicd_runner/v1/`](../../iac-modules/terraform/cicd_runner/v1/) for a starter) | Deployer → public FQDN → **resolves to private IP via the base stack's private DNS zones** → PE → service | `""` (empty string) — skips the allowlist entry | Corporate deploys where the laptop already has private DNS + routing, CI runners inside the VNet |

**How the private path works:** the workload services' FQDNs (`<name>.blob.core.windows.net`, `<name>.documents.azure.com`, `<subdomain>.services.ai.azure.com`, etc.) resolve through the 11 private DNS zones the base stack VNet-links. When your deployer machine uses Azure-integrated DNS for those zones — directly (VM in the VNet), through your VPN client's DNS, or via an on-prem DNS forwarder pointed at Azure's virtual server `168.63.129.16` — the FQDNs return the PE's private IP and admin traffic never touches the public endpoint. No allowlist entry is needed.

**How to verify you're on the private path** — from your deployer machine, resolve one of the service FQDNs and check it comes back private (`10.0.x.x` for this stack's default VNet):

```powershell
# Discover the Foundry account's custom-subdomain FQDN so this works even if you overrode
# cognitiveCustomSubdomainName / base_name / environment / location:
$foundryFqdn = (az cognitiveservices account list -g $RG_WORKLOAD --query "[?kind=='AIServices'].properties.endpoint | [0]" -o tsv) -replace 'https://', '' -replace '/$', ''
Resolve-DnsName $foundryFqdn | Select-Object Name, IPAddress
```

If it returns a public IP, you're on the public path — either set `deployerIp` to your public IP for this deploy, or fix your DNS routing before retrying (add a conditional forwarder / peer the VPN's DNS to Azure DNS).

**Once the deploy is complete you don't need `deployerIp` any longer.** The agent runtime always uses the private endpoints from inside the VNet. Any future deploys either need the IP re-added (public path) or need the deployer machine on the private path. See [Part C — Harden](#part-c--harden-remove-deployer-ip-and-close-public-endpoints) for the post-deploy lockdown that strips the IP and (optionally) fully closes the public endpoints.

---

Both RGs are region-scoped and expected to live in the same region. To collapse into a single-RG topology (dev / lab shortcut), point both stacks' `resource_group_name` (Terraform) / `-g` flag (Bicep) at the same RG name and set the workload's `baseResourceGroupName` / `base_resource_group_name` to match.

> ⚠️ **Every resource in this stack must be in the SAME Azure region.** That means both RGs, the VNet, the 5 subnets, the 11 private DNS zone links, all 9 workload private endpoints, and the 4 data-plane services (Foundry, Storage, Cosmos, AI Search). This is an Azure requirement, not a lab convention:
>
> - A **private endpoint MUST be in the same region** as the service it targets (`Microsoft.Network/privateEndpoints` fails at deploy time if the PE's subnet and the target service are in different regions).
> - The **Foundry account MUST be in the same region as its injected VNet** (per [Microsoft's Foundry Agent Service private-networking docs](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/virtual-networks#limitations)).
> - Storage / Cosmos / AI Search technically *can* be in different regions in general, but since we wire them via private endpoints in the base VNet, they too must match. Cross-region PEs are neither supported nor useful for this topology.
>
> The templates enforce co-location by using a single `location` variable in both stacks, defaulting to `westus3`. If you change the region, change it in **both** stacks (base's `location` param + workload's `location` param) — otherwise the workload's PE creation fails with a region-mismatch error. Also verify the target region is on Microsoft's [supported-regions list for Foundry Agent Service private networking](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions).

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

Set naming variables for the two CAF-pattern RGs and echo:

```powershell
$LOC          = "westus3"
$RG_NETWORK   = "rg-ai-foundry-network-dev-$LOC"    # base stack lives here
$RG_WORKLOAD  = "rg-ai-foundry-workload-dev-$LOC"   # workload stack lives here
Write-Host "LOC          = $LOC"
Write-Host "RG_NETWORK   = $RG_NETWORK"
Write-Host "RG_WORKLOAD  = $RG_WORKLOAD"
```

Create both RGs:

```powershell
az group create -n $RG_NETWORK  -l $LOC --tags environment=dev workload=ai-foundry stack=network
az group create -n $RG_WORKLOAD -l $LOC --tags environment=dev workload=ai-foundry stack=workload
az group list --query "[?name=='$RG_NETWORK' || name=='$RG_WORKLOAD'].{Name:name, Location:location, State:properties.provisioningState}" -o table
```

Expected: both rows show `Succeeded` in the `State` column.

Register Resource Providers, then show the state for all of them in one query:

```powershell
$rps = @(
    'Microsoft.App',                # required by the agent subnet's Microsoft.App/environments delegation (Foundry Agent Service runtime)
    'Microsoft.CognitiveServices',  # Foundry account + project + connections + capability hosts
    'Microsoft.DocumentDB',         # Cosmos DB
    'Microsoft.Network',            # VNet, subnets, private DNS zones, private endpoints
    'Microsoft.Search',             # AI Search
    'Microsoft.Storage'             # Storage account
)
foreach ($rp in $rps) { az provider register --namespace $rp --wait }

$rpList = "'" + ($rps -join "','") + "'"
az provider list --query "[?contains([$rpList], namespace)].{Namespace:namespace, State:registrationState}" -o table
```

Expected: every row shows `Registered`.

### Step 2. Deploy the base stack (~4 min)

Base creates the VNet + 5 subnets + 11 private DNS zones with VNet links, **into the networking RG (`$RG_NETWORK`)**. No IP allowlisting needed — none of these are firewalled services.

`cd` into the base Bicep directory:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/base/bicep
Get-Location   # expect: ...\environments\ai-foundry\base\bicep
```

Deploy:

```powershell
az deployment group create `
    -g $RG_NETWORK `
    -n base-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam
```

Verify:

```powershell
az resource list -g $RG_NETWORK --query "[?type=='Microsoft.Network/virtualNetworks' || type=='Microsoft.Network/privateDnsZones'].{Name:name, Type:type}" -o table
```

Expected: 1 VNet (`vnet-ai-foundry-dev-westus3`) + 11 privateDnsZones — all in `$RG_NETWORK`.

### Step 3. Deploy the workload stack (~15–20 min)

The workload deploys **into `$RG_WORKLOAD`** and looks up base's VNet + DNS zones cross-RG in `$RG_NETWORK` (the `baseResourceGroupName` param in `main.bicep` defaults to `rg-ai-foundry-network-dev-westus3`).

> **Resuming from an existing base deploy?** If you're in a new terminal session (variables gone) or the base was deployed by someone else / a prior CI run, you need at minimum these three session variables before running the deploy:
>
> ```powershell
> $LOC          = "westus3"                              # region the base stack was deployed in
> $RG_NETWORK   = "rg-ai-foundry-network-dev-$LOC"       # RG the base stack lives in
> $RG_WORKLOAD  = "rg-ai-foundry-workload-dev-$LOC"      # RG the workload deploys into (create it below if missing)
> ```
>
> Make sure `$RG_WORKLOAD` exists (Path A Step 1 creates it — skip if you already ran it):
>
> ```powershell
> az group create -n $RG_WORKLOAD -l $LOC --tags environment=dev workload=ai-foundry stack=workload
> ```
>
> **If the base stack was deployed with non-default names / values**, first discover what's actually in `$RG_NETWORK`:
>
> ```powershell
> az resource list -g $RG_NETWORK --query "[?type=='Microsoft.Network/virtualNetworks' || type=='Microsoft.Network/privateDnsZones'].{Name:name, Type:type}" -o table
> az network vnet subnet list -g $RG_NETWORK --vnet-name <your-vnet-name> --query "[].name" -o tsv
> ```
>
> Then either:
> - **Edit** [`main.bicepparam`](workload/bicep/main.bicepparam) directly — it has commented examples for every override (`baseName`, `environment`, `location`, `baseResourceGroupName`, `vnetName`, `subnetNameCognitivePep`, DNS zone names, `cognitiveCustomSubdomainName`, etc.), OR
> - **Pass overrides on the CLI** via `-p` flags on the `az deployment group create` below — e.g. `-p baseResourceGroupName=<rg-name>`, `-p baseName=<value>`, `-p vnetName=<name>`. The CLI flags override anything in `main.bicepparam`.
>
> The three most common overrides:
> - `-p baseResourceGroupName=<rg>` — if base lives in an RG that doesn't match the default `rg-ai-foundry-network-dev-<loc>`
> - `-p baseName=<v> -p environment=<v> -p location=<v>` — shifts the whole derived-name set (VNet, subnet, and Cognitive subdomain names all follow `<baseName>-<environment>-<location>`)
> - `-p vnetName=<n>` / `-p subnetName*=<n>` — override individual names if base's resources don't follow the convention (e.g. a shared platform VNet)

`cd` into the workload Bicep directory:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/bicep
Get-Location   # expect: ...\environments\ai-foundry\workload\bicep
```

Set your public IP as an environment variable (Bicep's `main.bicepparam` reads it via `readEnvironmentVariable('DEPLOYER_IP', '')`). See [Deployment topology](#deployment-topology-public-path-vs-private-path) for how to choose — both are valid; pick one:

**Option A — public-path deploy (default).** Laptop on the public internet. Grab your public IP so the workload firewalls allow your `az` session:

```powershell
$env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
Write-Host "DEPLOYER_IP = $env:DEPLOYER_IP"
```

**Option B — private-path deploy.** Deployer on VPN / ExpressRoute / Bastion / VNet-injected runner. The workload FQDNs resolve to private IPs via the base stack's private DNS zones, so no allowlist entry is needed:

```powershell
$env:DEPLOYER_IP = ""
```

Deploy:

```powershell
az deployment group create `
    -g $RG_WORKLOAD `
    -n workload-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam
```

Verify the 4 data-plane services and the 9 workload PEs (all in `$RG_WORKLOAD`):

```powershell
az resource list -g $RG_WORKLOAD --query "[?type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.Storage/storageAccounts' || type=='Microsoft.DocumentDB/databaseAccounts' || type=='Microsoft.Search/searchServices'].{Name:name, Type:type}" -o table
(az resource list -g $RG_WORKLOAD --resource-type Microsoft.Network/privateEndpoints -o json | ConvertFrom-Json).Count
```

Expected: 1 Cognitive account + 1 Storage + 1 Cosmos + 1 Search; PE count = **9** (1 Foundry + 6 Storage sub-resources + 1 Cosmos + 1 Search).

Why the IP is on the allowlist by default: the deploy itself is mostly ARM control-plane (the Cognitive Services / Cosmos / Search / Storage RPs do their work internally via the `bypass = AzureServices` trusted-services path), but the allowlist entry means your `az` / Portal / SDK admin operations from this same machine keep working **after** the deploy without further changes. On the private path (see [Deployment topology](#deployment-topology-public-path-vs-private-path)) that admin traffic goes through private endpoints instead, and no allowlist entry is needed.

### Step 4. Full inventory (across both RGs)

```powershell
Write-Host "--- $RG_NETWORK ---"
az resource list -g $RG_NETWORK  --query "sort_by([], &type)[].{Name:name, Type:type}" -o table
Write-Host "--- $RG_WORKLOAD ---"
az resource list -g $RG_WORKLOAD --query "sort_by([], &type)[].{Name:name, Type:type}" -o table
```

Expected:
- `$RG_NETWORK`: 1 VNet, 5 subnets, 11 privateDnsZones
- `$RG_WORKLOAD`: 9 privateEndpoints, 1 Cognitive account + 1 project, 1 Storage, 1 Cosmos, 1 Search

---

## Path B — Terraform

Terraform can't atomically create its own backing store, so the flow has one extra step at the top: **bootstrap the state storage account with `az`**, then `terraform import` it and let Terraform manage it (including adding its Private Endpoint) from there.

### Step 1. Sign in, create the RG, register Resource Providers, grant blob data access (~3 min)

These are all `az` commands — no working-directory dependency. Run them from anywhere.

Sign in and set variables:

```powershell
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>

$LOC          = "westus3"
$RG_NETWORK   = "rg-ai-foundry-network-dev-$LOC"    # base stack + tfstate SA live here
$RG_WORKLOAD  = "rg-ai-foundry-workload-dev-$LOC"   # workload stack lives here
$SUB          = (az account show --query id -o tsv)
$ME           = (az ad signed-in-user show --query id -o tsv)

Write-Host "LOC          = $LOC"
Write-Host "RG_NETWORK   = $RG_NETWORK"
Write-Host "RG_WORKLOAD  = $RG_WORKLOAD"
Write-Host "SUB          = $SUB"
Write-Host "ME           = $ME"
```

Expected: all six echoes non-empty; `SUB` looks like a GUID, `ME` looks like a GUID.

Create both RGs:

```powershell
az group create -n $RG_NETWORK  -l $LOC --tags environment=dev workload=ai-foundry stack=network
az group create -n $RG_WORKLOAD -l $LOC --tags environment=dev workload=ai-foundry stack=workload
az group list --query "[?name=='$RG_NETWORK' || name=='$RG_WORKLOAD'].{Name:name, Location:location, State:properties.provisioningState}" -o table
```

Register Resource Providers (Terraform's `resource_provider_registrations = "none"` means Terraform will NOT auto-register, so this is required):

```powershell
$rps = @(
    'Microsoft.App',                # required by the agent subnet's Microsoft.App/environments delegation (Foundry Agent Service runtime)
    'Microsoft.CognitiveServices',  # Foundry account + project + connections + capability hosts
    'Microsoft.DocumentDB',         # Cosmos DB
    'Microsoft.Network',            # VNet, subnets, private DNS zones, private endpoints
    'Microsoft.Search',             # AI Search
    'Microsoft.Storage'             # Storage account (also backs the tfstate SA bootstrapped in Step 2)
)
foreach ($rp in $rps) { az provider register --namespace $rp --wait }

$rpList = "'" + ($rps -join "','") + "'"
az provider list --query "[?contains([$rpList], namespace)].{Namespace:namespace, State:registrationState}" -o table
```

Expected: every row shows `Registered`.

Grant yourself `Storage Blob Data Contributor` at the **networking RG** scope (that's where the tfstate SA will live) so `az storage container create --auth-mode login` and Terraform's `azurerm` backend can both authenticate via Entra ID (shared-key access is disabled on the state SA):

```powershell
az role assignment create `
    --assignee-object-id $ME `
    --assignee-principal-type User `
    --role "Storage Blob Data Contributor" `
    --scope "/subscriptions/$SUB/resourceGroups/$RG_NETWORK"

# Wait for the role assignment to propagate before using it.
Start-Sleep -Seconds 60

az role assignment list --assignee $ME --scope "/subscriptions/$SUB/resourceGroups/$RG_NETWORK" --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{Role:roleDefinitionName, Scope:scope}" -o table
```

Expected: one row with `Storage Blob Data Contributor` at the `$RG_NETWORK` scope.

### Step 2. Bootstrap the Terraform-state Storage account (~2 min)

The tfstate SA lives in the **networking RG** (`$RG_NETWORK`) — it's part of the base / platform stack's lifecycle. Detect your IP and derive the state SA name (`sttfs<md5(RG + base_name + environment + location)>` truncated to 12 hex chars — must match what base's `main.tf` will compute):

```powershell
$DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
$BASE_NAME   = "ai-foundry"        # must match base_name default in variables.tf
$ENVIRONMENT = "dev"               # must match environment default in variables.tf

$hashInput = "${RG_NETWORK}${BASE_NAME}${ENVIRONMENT}${LOC}"
$md5       = [System.Security.Cryptography.MD5]::Create()
$hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
$HASH      = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
$STATE_SA  = "sttfs" + $HASH.Substring(0, 12)

Write-Host "DEPLOYER_IP = $DEPLOYER_IP"
Write-Host "STATE_SA    = $STATE_SA"
```

Expected: `DEPLOYER_IP` is a public IPv4; `STATE_SA` is 17 chars starting with `sttfs`.

Create the storage account in `$RG_NETWORK`:

```powershell
az storage account create `
    -g $RG_NETWORK -n $STATE_SA -l $LOC `
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

az storage account show -g $RG_NETWORK -n $STATE_SA --query "{Name:name, SKU:sku.name, PublicNetwork:publicNetworkAccess, TLS:minimumTlsVersion, SharedKey:allowSharedKeyAccess}" -o table
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
    -backend-config="resource_group_name=$RG_NETWORK" `
    -backend-config="storage_account_name=$STATE_SA"
```

Expected: `Terraform has been successfully initialized!`

Import the storage account and its container so Terraform manages them going forward:

```powershell
terraform import `
    "module.tfstate_storage.azurerm_storage_account.this" `
    "/subscriptions/$SUB/resourceGroups/$RG_NETWORK/providers/Microsoft.Storage/storageAccounts/$STATE_SA"

terraform import `
    "azurerm_storage_container.tfstate" `
    "/subscriptions/$SUB/resourceGroups/$RG_NETWORK/providers/Microsoft.Storage/storageAccounts/$STATE_SA/blobServices/default/containers/tfstate"

terraform state list
```

Expected: at minimum `azurerm_storage_container.tfstate` and `module.tfstate_storage.azurerm_storage_account.this` present in the list.

### Step 4. Apply base (~5 min)

Still in `environments/ai-foundry/base/terraform` from Step 3. If you overrode `$STATE_SA` from the default, pass it as a variable — otherwise omit the `-var` flag:

```powershell
terraform apply `
    -var "tfstate_storage_account_name=$STATE_SA"
```

Terraform reconciles the imported state SA (adds its blob PE, applies blob-service properties: 30-day soft delete + versioning + last-access tracking), then creates the VNet + 5 subnets + 11 DNS zones with VNet links — all in `$RG_NETWORK`.

Verify:

```powershell
az resource list -g $RG_NETWORK --query "[?type=='Microsoft.Network/virtualNetworks' || type=='Microsoft.Network/privateDnsZones' || type=='Microsoft.Network/privateEndpoints'].{Name:name, Type:type}" -o table
```

Expected: 1 VNet, 11 privateDnsZones, **1 privateEndpoint** (on the state SA), all in `$RG_NETWORK`.

### Step 5. Init workload with remote backend + apply (~15–20 min)

The workload deploys **into `$RG_WORKLOAD`** and looks up base's VNet + DNS zones cross-RG in `$RG_NETWORK` (`variables.tf`'s `resource_group_name` defaults to `rg-ai-foundry-workload-dev-westus3` and `base_resource_group_name` defaults to `rg-ai-foundry-network-dev-westus3`).

> **Resuming from an existing base deploy?** If you're in a new terminal session (variables gone) or the base was deployed by someone else / a prior CI run, you need at minimum these session variables before running init + apply:
>
> ```powershell
> $LOC          = "westus3"                              # region the base stack was deployed in
> $RG_NETWORK   = "rg-ai-foundry-network-dev-$LOC"       # RG the base stack + tfstate SA live in
> $RG_WORKLOAD  = "rg-ai-foundry-workload-dev-$LOC"      # RG the workload deploys into (create it below if missing)
> ```
>
> The tfstate SA name lives in `$RG_NETWORK`. If you don't remember it, discover it directly (safer than recomputing the hash):
>
> ```powershell
> $STATE_SA = (az storage account list -g $RG_NETWORK --query "[?starts_with(name, 'sttfs')].name | [0]" -o tsv)
> Write-Host "STATE_SA = $STATE_SA"
> ```
>
> Make sure `$RG_WORKLOAD` exists (Path B Step 1 creates it — skip if you already ran it):
>
> ```powershell
> az group create -n $RG_WORKLOAD -l $LOC --tags environment=dev workload=ai-foundry stack=workload
> ```
>
> **If the base stack was deployed with non-default names / values**, first discover what's actually in `$RG_NETWORK`:
>
> ```powershell
> az resource list -g $RG_NETWORK --query "[?type=='Microsoft.Network/virtualNetworks' || type=='Microsoft.Network/privateDnsZones'].{Name:name, Type:type}" -o table
> ```
>
> Then copy [`terraform.tfvars.example`](workload/terraform/terraform.tfvars.example) to `terraform.tfvars` (git-ignored) inside `environments/ai-foundry/workload/terraform/` and uncomment the overrides you need:
>
> ```powershell
> Copy-Item environments/ai-foundry/workload/terraform/terraform.tfvars.example environments/ai-foundry/workload/terraform/terraform.tfvars
> ```
>
> The most common overrides:
> - `resource_group_name` — workload RG (if not `rg-ai-foundry-workload-dev-<loc>`)
> - `base_resource_group_name` — where base lives (if not `rg-ai-foundry-network-dev-<loc>`)
> - `base_name` / `environment` / `location` — shifts the whole derived-name set (VNet, subnet, and Cognitive subdomain names all follow `<base_name>-<environment>-<location>`)
> - Individual name overrides (`vnet_name`, `subnet_name_*`, DNS zone names, `cognitive_custom_subdomain_name`) — for a shared platform VNet whose resources don't follow the convention

`cd` into the workload Terraform directory:

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/terraform
Get-Location   # expect: ...\environments\ai-foundry\workload\terraform
```

Init points at the same tfstate SA (in `$RG_NETWORK`) as base, but with a different blob key (`workload.tfstate`):

```powershell
terraform init `
    -backend-config="resource_group_name=$RG_NETWORK" `
    -backend-config="storage_account_name=$STATE_SA"
```

Apply. See [Deployment topology](#deployment-topology-public-path-vs-private-path) for how to choose — both are valid; pick one:

**Option A — public-path deploy (default).** Deployer on the public internet. Terraform's `data.http.myip` auto-detects your public IP and pins it into the workload firewalls:

```powershell
terraform apply
```

**Option B — private-path deploy.** Deployer on VPN / ExpressRoute / Bastion / VNet-injected runner. Skip the ipify call entirely by pinning `deployer_ip` to empty string; the workload FQDNs resolve to private IPs via the base stack's private DNS zones, so no allowlist entry is needed:

```powershell
terraform apply -var 'deployer_ip='
```

### Step 6. Full inventory (across both RGs)

```powershell
Write-Host "--- $RG_NETWORK ---"
az resource list -g $RG_NETWORK  --query "sort_by([], &type)[].{Name:name, Type:type}" -o table
Write-Host "--- $RG_WORKLOAD ---"
az resource list -g $RG_WORKLOAD --query "sort_by([], &type)[].{Name:name, Type:type}" -o table
```

Expected:
- `$RG_NETWORK`: 1 VNet, 5 subnets, 11 privateDnsZones, 1 privateEndpoint (on the state SA), 1 Storage account (the state SA itself)
- `$RG_WORKLOAD`: 9 privateEndpoints, 1 Cognitive account + 1 project, 1 Storage, 1 Cosmos, 1 Search

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
    -g $RG_WORKLOAD `
    -n workload-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam
```

### Path B — Terraform

If your IP changed since the last apply, refresh the state SA's firewall allowlist first (Storage's control plane is always reachable regardless of the data-plane firewall — that's how this ad-hoc rule gets added). The state SA lives in `$RG_NETWORK`:

```powershell
$DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
az storage account network-rule add -g $RG_NETWORK -n $STATE_SA --ip-address $DEPLOYER_IP
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

> **Skip this section if you deployed on the private path** (with `deployerIp=""` / `deployer_ip=""`) — there's no allowlist entry to strip. You may still want to run the `enablePublicNetworkAccess=false` step below to close the public endpoints entirely: the default-deny firewall + empty allowlist already blocks non-Azure clients today, but the `bypass = AzureServices` trusted-services rule still lets other Azure services reach the public endpoint. Flipping public access to `Disabled` is the only way to close that path too.

### Path A — Bicep

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location environments/ai-foundry/workload/bicep

az deployment group create `
    -g $RG_WORKLOAD `
    -n harden-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -f main.bicep `
    -p main.bicepparam `
    -p enablePublicNetworkAccess=false `
    -p deployerIp=""
```

Verify all 4 services flipped to `Disabled` (all workload services live in `$RG_WORKLOAD`). The Foundry account resource name is `ais-<baseName>-<environment>-<location>` (the `cog-acc-...` string you may see elsewhere is the custom subdomain, not the account name) — discover it dynamically so this works regardless of override:

```powershell
$foundryAccount = (az cognitiveservices account list -g $RG_WORKLOAD --query "[?kind=='AIServices'].name | [0]" -o tsv)
az cognitiveservices account show -g $RG_WORKLOAD -n $foundryAccount --query "properties.publicNetworkAccess" -o tsv
az storage account list -g $RG_WORKLOAD --query "[].{Name:name, PublicNetwork:publicNetworkAccess}" -o table
az cosmosdb list -g $RG_WORKLOAD --query "[].{Name:name, PublicNetwork:publicNetworkAccess}" -o table
az search service list -g $RG_WORKLOAD --query "[].{Name:name, PublicNetwork:publicNetworkAccess}" -o table
```

Expected: `Disabled` for the Foundry account, the workload Storage account, Cosmos, and Search. The state SA (Path B only, in `$RG_NETWORK`) is intentionally untouched — keep its public endpoint enabled so subsequent Terraform runs can reach the backend.

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

Delete both RGs (workload first for cleanliness, though the operations are RG-scoped and won't cross-block):

```powershell
az group delete -n $RG_WORKLOAD --yes --no-wait
az group delete -n $RG_NETWORK  --yes --no-wait
az group exists -n $RG_WORKLOAD
az group exists -n $RG_NETWORK
```

Expected: both return `false` once the async deletes complete (typically 2–5 min each).

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

Finally, delete both RGs (which cleans up the still-in-Azure, no-longer-in-Terraform tfstate SA + container):

```powershell
az group delete -n $RG_WORKLOAD --yes --no-wait
az group delete -n $RG_NETWORK  --yes --no-wait
az group exists -n $RG_WORKLOAD
az group exists -n $RG_NETWORK
```

Workload destroy runs first (its resources reference base). Base destroy only removes the VNet + DNS zones because we untracked the tfstate SA + container. The final `az group delete` on both RGs cleans up the (still in Azure, no longer in Terraform) tfstate SA and its container from `$RG_NETWORK`, plus anything untracked in `$RG_WORKLOAD`.

---

## RBAC roster (workload)

The workload's `foundry_project` module grants these to the Foundry project's SystemAssigned MI:

| Phase | Role | Scope | Why |
|---|---|---|---|
| 3 | Cosmos DB Operator | Cosmos account | Foundry creates `enterprise_memory` DB + containers |
| 3 | Storage Account Contributor | Storage account | Foundry creates agent blob containers |
| 5 | Search Index Data Contributor | AI Search | Agents read/write vector indexes |
| 5 | Search Service Contributor | AI Search | Agents create indexes on demand |
| 5 | Storage Blob Data Contributor | Storage account | Agents read/write files in the auto-created containers (Contributor, not Owner — Owner's ACL / POSIX management bits aren't needed at runtime) |
| 5 | Cosmos DB Built-in Data Contributor | Cosmos account (SQL role) | Agents read/write threads in `enterprise_memory` |

Terraform waits 60 s via `time_sleep` between assignments and capability-host provisioning — that's a client-side wait, no Azure resources involved. Bicep has no equivalent primitive: we used to insert a `Microsoft.Resources/deploymentScripts` (Azure Container Instance running `sleep 60`) to force a delay, but deploymentScripts requires shared-key auth to its own auto-provisioned Storage account, which is incompatible with tenant policies that enforce `allowSharedKeyAccess = false`. Bicep therefore relies purely on ARM's `dependsOn` chain and accepts that first-apply capability-host creation may occasionally 403 on RBAC propagation lag — recovery is a plain rerun of the same `az deployment group create` (idempotent; everything else is a no-op; the capability host retry succeeds after propagation completes).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `terraform apply` fails reading state with an authorization / 403 on the tfstate blob | Your IP changed and isn't allowlisted on the state SA firewall | `az storage account network-rule add -g $RG_NETWORK -n $STATE_SA --ip-address $((Invoke-RestMethod https://api.ipify.org).Trim())` then retry |
| `az storage account create` in Path B Step 2 returns `StorageAccountAlreadyTaken` | Your derived `sttfs<hash>` name collides globally with someone else's account | See the collision note **inside Path B Step 2** — pick a unique name for `$STATE_SA` and re-run Step 2 with it; carry the same value through `terraform init` and the `-var 'tfstate_storage_account_name=...'` in Step 4 |
| Bicep or Terraform deploy fails on `Microsoft.CognitiveServices/accounts/capabilityHosts` with 403 | RBAC propagation lag (Entra ID replication) between the workload's role assignments and the data-plane call to create the capability host | **Bicep**: rerun `az deployment group create` — the whole deploy is idempotent and everything else is a no-op; the capability host retry succeeds once propagation completes (typically < 60 s). **Terraform**: `time_sleep` will NOT re-fire if already in state — if the retry still 403s, force the sleep to re-run from `environments/ai-foundry/workload/terraform`: `terraform apply -replace='module.foundry_project.time_sleep.wait_for_rbac_propagation'` |
| First `terraform apply` for base in Path B Step 4 wants to *create* the state SA instead of updating it | You skipped the `terraform import` commands in Path B Step 3 | Cancel the apply, run the two `terraform import` commands from Step 3, then rerun `terraform apply` |
| Workload deployed OK but hitting a workload endpoint (e.g. `Invoke-RestMethod` to the Foundry account) returns 403 | Your public IP isn't currently allowlisted, or you ran the [hardening step](#part-c--harden-remove-deployer-ip-and-close-public-endpoints) | Rerun the workload deploy from the current network to reconcile the allowlist; if hardened, follow the [un-harden step](#un-harden-before-your-next-deploy) |
| `az storage container create --auth-mode login` returns 403 | RBAC propagation lag on the `Storage Blob Data Contributor` assignment | Wait 30-60 s and retry (Path B Step 1 already includes a `Start-Sleep 60`) |
| Bicep base deploy fails on one or more subnets with `RetryableError` / `A retryable error occurred` (rerun succeeds) | Parallel subnet creates on the same VNet race on the VNet's per-request write lock. Bicep's default loop batchSize is 10, so all 5 subnets fire concurrently and one occasionally loses the race | Serialised in [iac-modules/bicep/vnet/v1/vnet.bicep](iac-modules/bicep/vnet/v1/vnet.bicep) via `@batchSize(1)` on the subnet `[for]` loop. If a rerun still flakes on a different resource, it's likely the same class of race on a different shared parent (see next row) |
| Workload deploy fails on one or more storage private endpoints with `RetryableError` / `AnotherOperationInProgress` / `409` (rerun succeeds) | Parallel PE creation on the shared storage-PE subnet AND on the shared Storage account — same class of race as subnets. All 6 subresource PEs (blob/file/queue/table/dfs/web) target the same subnet + same account, so their NIC writes contend on the subnet's IP-configuration write lock and their `privateLinkServiceConnections` writes contend on the Storage account write lock | Serialised via chained `dependsOn` (Bicep [iac-modules/bicep/storage_account/v1/storage_account.bicep](iac-modules/bicep/storage_account/v1/storage_account.bicep)) and chained `depends_on` (Terraform [iac-modules/terraform/storage_account/v1/main.tf](iac-modules/terraform/storage_account/v1/main.tf)). No action needed; just documented so you know why the storage step takes ~30 s instead of ~10 s |

### Deleting an AI Foundry subnet blocked by `legionservicelink`

If you delete an AI Foundry account (`kind=AIServices`) that had Agent Service configured with a delegated subnet, the underlying Container Apps managed environment (in a Microsoft-owned `hobov3_*` subscription) can be orphaned. It leaves a `legionservicelink` SAL on your subnet that you can't delete directly — the account delete hangs in `Deleting`, and the subnet is stuck.

Fix: detect what state the account is in (soft-deleted / live / stuck in `Deleting`), then either migrate the network injection off your customer subnet to the Microsoft-managed network — the RP's supported detach path, since an empty `networkInjections: []` is rejected with `Invalid/Empty NetworkInjection object` on current API versions — or let a raw delete drive the teardown. Poll for the SAL to clear before purging.

> **Naming conventions.** The script below uses the same session variables as the rest of the README (`$LOC`, `$RG_NETWORK`, `$RG_WORKLOAD`). The **Foundry account** lives in `$RG_WORKLOAD`; the **VNet + delegated subnet** live in `$RG_NETWORK` (per the [CAF split-RG topology](#deployment-topology-public-path-vs-private-path)). If you have a pre-CAF single-RG deployment, set `$RG_NETWORK` and `$RG_WORKLOAD` to the same value.

```powershell
# Session variables -- align with the values you used at deploy time.
$LOC          = "westus3"
$RG_NETWORK   = "rg-ai-foundry-network-dev-$LOC"      # holds VNet + agent subnet
$RG_WORKLOAD  = "rg-ai-foundry-workload-dev-$LOC"     # holds the Foundry account
$ACCT         = "ais-ai-foundry-dev-$LOC"             # Foundry account resource name
$VNET         = "vnet-ai-foundry-dev-$LOC"
$SUBNET       = "snet-agent-ai-foundry-dev"

# ---------------------------------------------------------------------------
# 1. Detect account state so we branch cleanly instead of running every step
#    unconditionally (the previous version of this script called `recover`
#    even when the account wasn't soft-deleted, which returned exit 1 and
#    confused users into thinking the script had failed).
# ---------------------------------------------------------------------------
$ACCT_ID = (az cognitiveservices account show -g $RG_WORKLOAD -n $ACCT --query id -o tsv 2>$null)
$LASTEXITCODE = 0  # `show` returns 1 when the account isn't live; don't propagate.

$SOFT_DELETED = $false
if (-not $ACCT_ID) {
    # Not live -- check the soft-delete list.
    $SOFT_HITS = az cognitiveservices account list-deleted --query "[?name=='$ACCT' && location=='$LOC'] | length(@)" -o tsv
    $SOFT_DELETED = ($SOFT_HITS -eq "1")
}

if ($SOFT_DELETED) {
    Write-Host "Account '$ACCT' is soft-deleted -- recovering to a mutable state so we can PATCH it..."
    az cognitiveservices account recover --location $LOC --name $ACCT --resource-group $RG_WORKLOAD | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Recover failed. Check the account name + location match the soft-deleted entry." }
    $ACCT_ID = (az cognitiveservices account show -g $RG_WORKLOAD -n $ACCT --query id -o tsv)
}

if (-not $ACCT_ID) {
    throw "Account '$ACCT' not visible in '$RG_WORKLOAD' (neither live nor soft-deleted). Check names + subscription."
}

$STATE = az cognitiveservices account show --ids $ACCT_ID --query "properties.provisioningState" -o tsv
Write-Host "Account state: $STATE   ID: $ACCT_ID"

# ---------------------------------------------------------------------------
# 2. Migrate the network injection OFF the customer subnet by flipping
#    `useMicrosoftManagedNetwork = true`. The RP's supported detach path --
#    `networkInjections: []` is rejected on api-version 2025-06-01 with
#    `InvalidResourceProperties: Invalid/Empty NetworkInjection object`.
#
#    SKIP when the account is already in `Deleting`: ARM rejects PATCHes on
#    resources mid-delete, and Step 3's poll will still drive the SAL to
#    clear as the platform tears down the injection as part of the delete.
# ---------------------------------------------------------------------------
if ($STATE -eq "Deleting") {
    Write-Host "Account is already in Deleting state -- skipping PATCH; waiting for the platform delete to release the SAL."
} else {
    $BODY_FILE = Join-Path $env:TEMP "detach-ni.json"
    $body = @{
        properties = @{
            networkInjections = @(
                @{
                    scenario                   = "agent"
                    useMicrosoftManagedNetwork = $true
                }
            )
        }
    } | ConvertTo-Json -Depth 6 -Compress
    [System.IO.File]::WriteAllText($BODY_FILE, $body)

    az rest --method patch `
      --uri "https://management.azure.com$ACCT_ID`?api-version=2025-06-01" `
      --headers "Content-Type=application/json" `
      --body "@$BODY_FILE"
    if ($LASTEXITCODE -ne 0) { throw "PATCH failed. See error above; the account may be in a state that doesn't accept PATCHes." }
}

# ---------------------------------------------------------------------------
# 3. Poll until the `legionservicelink` SAL clears from the subnet
#    (typically 5-30 min while the platform migrates the injection off the
#    customer subnet, or 5-45 min if we're waiting on a raw delete).
#    If the SAL still hasn't cleared after ~1 hour, break out of this loop
#    and open a support ticket -- see the note below the script.
# ---------------------------------------------------------------------------
$SLEEP_SECS = 30
$MAX_ITERS  = 90   # 90 * 30 s = 45 min hard cap
for ($i = 0; $i -lt $MAX_ITERS; $i++) {
    Start-Sleep -Seconds $SLEEP_SECS
    $STATE = az cognitiveservices account show --ids $ACCT_ID --query "properties.provisioningState" -o tsv 2>$null
    $LASTEXITCODE = 0
    $SAL = az network vnet subnet show -g $RG_NETWORK --vnet-name $VNET -n $SUBNET --query "serviceAssociationLinks[].name" -o tsv
    Write-Host ("[{0:mm\:ss}] provisioningState={1}  SAL='{2}'" -f (New-TimeSpan -Seconds (($i + 1) * $SLEEP_SECS)), $STATE, $SAL)
    if (-not $SAL) { break }
}
if ($SAL) { throw "SAL still present after $($MAX_ITERS * $SLEEP_SECS / 60) min. Open a support ticket -- see below." }

# ---------------------------------------------------------------------------
# 4. Delete + purge the account (skip delete if it already completed while
#    we were polling -- Step 3's `show` will have returned no state in that
#    case).
# ---------------------------------------------------------------------------
if ($STATE) {
    az cognitiveservices account delete --ids $ACCT_ID
    az cognitiveservices account purge --location $LOC --name $ACCT --resource-group $RG_WORKLOAD
} else {
    # Account already gone -- just purge from the soft-delete list.
    az cognitiveservices account purge --location $LOC --name $ACCT --resource-group $RG_WORKLOAD 2>$null
    $LASTEXITCODE = 0
}

# ---------------------------------------------------------------------------
# 5. Remove the subnet delegation (`--set delegations=[]` is version-safe
#    across az CLI builds; `--remove delegations` behaves inconsistently)
#    and delete the subnet.
# ---------------------------------------------------------------------------
az network vnet subnet update -g $RG_NETWORK --vnet-name $VNET -n $SUBNET --set 'delegations=[]'
az network vnet subnet delete  -g $RG_NETWORK --vnet-name $VNET -n $SUBNET
```

**If the poll in Step 3 exhausts its 45-minute cap** with the SAL still present, open a support ticket referencing the account ARM ID and the orphaned `hobov3_*` managed environment — only the Foundry team can force-release the SAL at that point.

**Prevention:** always flip `networkInjections[].useMicrosoftManagedNetwork` to `true` (via Bicep / Terraform / PATCH) and wait for `provisioningState = Succeeded` on the Foundry account **before** deleting it — or, when tearing down the whole environment, use the [Tear down](#tear-down) section's `az group delete` which lets Azure resolve the deletion order internally.

---

## References

- [Foundry Standard Agent Setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup)
- [Foundry private networking guide](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/virtual-networks)
- [Foundry supported regions for private networking](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/limits-quotas-regions#supported-regions)
- [Terraform azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Bicep language reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
