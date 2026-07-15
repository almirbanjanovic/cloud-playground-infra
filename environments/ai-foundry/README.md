# AI Foundry Lab

Foundry Agent Service with a **BYO stateful stack** — Storage, Cosmos DB, and AI Search stay in your subscription and are wired to Foundry via managed-identity connections and capability hosts, with a fully-private VNet.

This lab is split into two Terraform stacks:

| Stack | Purpose | Runs from |
|---|---|---|
| [`base/`](base/terraform/) | Shared network (VNet, subnets, NAT, DNS zones) + jumpbox + self-hosted GitHub Actions runner + federated identity for the workload stack. | `ubuntu-latest` (GitHub-hosted) |
| [`workload/`](workload/terraform/) | Foundry account, project, capability hosts + BYO Storage/Cosmos/AI Search + private endpoints. Everything here has `public_network_access_enabled = false`. | `[self-hosted, ai-foundry]` (the runner from `base/`) |

Why the split: workload data-plane operations (Cosmos SQL role assignments, Foundry capability host provisioning, Storage container access) need to reach services whose public network access is disabled. A GitHub-hosted runner can't reach them — the self-hosted runner living inside the VNet can.

## Architecture

Source diagram: [assets/architecture.drawio](assets/architecture.drawio) &nbsp; · &nbsp; Icons: [assets/icons/](assets/icons/)

**Structure (following Azure diagramming best practices):**

- The **Customer VNet** is the outermost container on the left.
- Each **subnet** is a nested container inside the VNet.
- Each **private endpoint** (PE) icon sits *inside* its subnet.
- Lines go from each PE **out to the target service** (Foundry account or a BYO service) on the right.
- The **agent runtime subnet** has a separate red arrow to the Foundry account labelled "network injection" — that subnet's IPs are consumed by Foundry Agent Service compute, not by a private endpoint.

Everything on the right (Foundry account + BYO services) has `public network access = Disabled`, so those PE lines are the *only* way in.

### Viewing / editing the diagram

- **VS Code**: install the [Draw.io Integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) extension and open the `.drawio` file — it renders inline and stays editable.
- **Browser**: open [diagrams.net](https://app.diagrams.net) → *File → Open from Device* and pick the `.drawio` file (make sure the `icons/` folder is beside it so the SVG references resolve).
- **Export a PNG for GitHub inline rendering**: *File → Export as → PNG*, save to `assets/architecture.png`, and swap the `Source diagram:` reference to that PNG.

## What each stack creates

### `base/` — network, jumpbox, runner

- **1 VNet** (`10.0.0.0/16`) with **7 subnets** via [subnet/v1](../../iac-modules/terraform/subnet/v1/main.tf):
  - 4 private-endpoint subnets: `snet-cognitive`, `snet-storage`, `snet-cosmos`, `snet-search`
  - 1 agent-runtime subnet delegated to `Microsoft.App/environments`
  - `snet-cicd` for the GitHub Actions runner
  - `snet-jumpbox` for the operator jumpbox
- **11 private DNS zones** (3 for Foundry, 6 for Storage, 1 for Cosmos, 1 for Search) linked to the VNet via [private_dns_zone/v1](../../iac-modules/terraform/private_dns_zone/v1/main.tf).
- **NAT gateway** attached to `snet-cicd` + `snet-jumpbox` so both VMs have outbound Internet to GitHub, apt, and Azure ARM.
- **Jumpbox** via [jumpbox/v1](../../iac-modules/terraform/jumpbox/v1/main.tf) — Ubuntu 22.04, public IP with SSH allowlist, Entra ID SSH login enabled.
- **CI/CD runner** via [cicd_runner/v1](../../iac-modules/terraform/cicd_runner/v1/main.tf) — Ubuntu 22.04, no public IP, UAMI, cloud-init that installs Azure CLI + Terraform + tflint and registers the runner against your repo with a fresh registration token minted from your PAT.
- **Federated identity credential** on the runner UAMI trusting `repo:${github_org}/${github_repo}:environment:ai-foundry-workload` so the workload workflow can `azure/login@v2` as this UAMI.
- **RBAC**: runner UAMI is Owner of the resource group (required so the workload apply can create the phase-3 / phase-5 role assignments the foundry_project module needs).

### `workload/` — Foundry, BYO services, capability hosts

- **BYO data plane** via [cosmos_db/v1](../../iac-modules/terraform/cosmos_db/v1/main.tf), [storage account/v1](../../iac-modules/terraform/storage%20account/v1/main.tf), and [ai_search/v1](../../iac-modules/terraform/ai_search/v1/main.tf). All have public network disabled, local auth disabled, SystemAssigned MI, and private endpoints into the corresponding subnets from `base/`.
- **Foundry account** via [cognitive_account/v1](../../iac-modules/terraform/cognitive_account/v1/main.tf) — `kind = "AIServices"`, `project_management_enabled = true`, network injection into the agent subnet from `base/`.
- **Foundry project + capability hosts** via [foundry_project/v1](../../iac-modules/terraform/foundry_project/v1/main.tf) — creates the project MI, grants Phase-3 and Phase-5 RBAC, waits 60s for RBAC propagation, then creates the account and project capability hosts that bind the three BYO connections into Agent Service.

Workload references everything in `base/` via `data` sources (by name), so the two stacks don't share state files — only the naming convention encoded in `locals` at the top of both `main.tf` files.

## Auth model — no keys anywhere

Every path is managed-identity + Entra ID:

| From | To | Auth |
|---|---|---|
| Foundry runtime (project MI) | Storage, Cosmos, Search | Entra ID (private endpoint) |
| Terraform (workload stack) | Foundry account, connections, cap hosts | Entra ID |
| Terraform data-plane calls | Storage | `storage_use_azuread = true` in provider |
| GitHub Actions (workload) → Azure | — | OIDC federated to the runner UAMI |
| Operator → Jumpbox | — | Entra ID SSH (`az ssh vm`) |

Local (key-based) auth is disabled on the Cognitive account, Storage, Cosmos, and AI Search. No connection strings or account keys appear in state.

## RBAC (all granted to project MI, by the workload stack)

| Phase | Role | Scope | Why |
|---|---|---|---|
| 3 | Cosmos DB Operator | Cosmos account | Foundry creates `enterprise_memory` DB + containers |
| 3 | Storage Account Contributor | Storage account | Foundry creates agent blob containers |
| 5 | Search Index Data Contributor | AI Search | Agents read/write vector indexes |
| 5 | Search Service Contributor | AI Search | Agents create indexes on demand |
| 5 | Storage Blob Data Owner | Storage account | Agents read/write files in the auto-created containers |
| 5 | Cosmos DB Built-in Data Contributor | Cosmos account | Agents read/write threads in `enterprise_memory` |

**Prerequisites for the principal running `terraform apply`:** Owner, User Access Administrator, or Role Based Access Administrator on the resource group (Contributor is NOT enough — it lacks `Microsoft.Authorization/roleAssignments/write`). The runner UAMI is granted Owner by `base/`.

## Prereq resource providers

Registered idempotently via `resource_providers_to_register` in each stack's `providers.tf`. Combined across both stacks: `Microsoft.App`, `Microsoft.CognitiveServices`, `Microsoft.Compute`, `Microsoft.ContainerService`, `Microsoft.DocumentDB`, `Microsoft.KeyVault`, `Microsoft.MachineLearningServices`, `Microsoft.ManagedIdentity`, `Microsoft.Network`, `Microsoft.Search`, `Microsoft.Storage`.

---


## Deploy — step by step

Rough time budget: ~15 min one-time setup, ~45 min of workflow runs (mostly waiting on Azure). Skip nothing — the order matters.

### Preflight — what you need in your hand before starting

- Azure subscription ID and tenant ID.
- Owner (or User Access Administrator + Contributor) on that subscription.
- Your OpenSSH public key (contents of `~/.ssh/id_ed25519.pub` or similar).
- Your Entra object ID (`az ad signed-in-user show --query id -o tsv`).
- Your workstation's public egress IP (`curl ifconfig.me`).
- GitHub CLI (`gh`) installed AND authenticated locally as a user with repo-admin access. Verify with `gh auth status`. If not logged in, run `gh auth login`.
- Azure CLI (`az`) installed locally, logged in with `az login`.
- **This lab is region-pinned to `centralus`** (see `local.location` in [base/terraform/main.tf](base/terraform/main.tf) and [workload/terraform/main.tf](workload/terraform/main.tf)). If you set the `LOCATION` GitHub variable to anything else, the resource group + state SA land in that region but Terraform still deploys VNet/services in `centralus`. Change both `local.location` blocks in lockstep if you want a different region.

---

### One-time setup (~15 minutes, done ONCE per repo)

#### A. Create the bootstrap Azure principal + federated credential

The bootstrap principal is what runs the first base-stack apply (before the runner UAMI exists). It needs subscription-scope `Owner` and a federated credential that trusts this repo + the `ai-foundry-base` GitHub environment.

Below uses a UAMI (recommended, no client secrets to rotate). Replace the placeholders in ALL CAPS.

```bash
# 1. Log in and set your subscription
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>

# 2. Create a resource group for the bootstrap identity
az group create --name rg-shared-identity --location centralus

# 3. Create the UAMI
az identity create \
  --name uami-cpi-bootstrap \
  --resource-group rg-shared-identity \
  --location centralus

# Capture IDs for later
export BOOTSTRAP_CLIENT_ID=$(az identity show --name uami-cpi-bootstrap --resource-group rg-shared-identity --query clientId -o tsv)
export BOOTSTRAP_PRINCIPAL_ID=$(az identity show --name uami-cpi-bootstrap --resource-group rg-shared-identity --query principalId -o tsv)
export TENANT_ID=$(az account show --query tenantId -o tsv)
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# 4. Grant Owner on the subscription — needed to create RGs, register RPs,
#    and grant the runner UAMI its downstream role assignments
az role assignment create \
  --assignee-object-id "$BOOTSTRAP_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Owner \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 4b. Grant Storage Blob Data Contributor on the subscription. Owner covers
#     control-plane operations (creating the state SA, the container as an
#     ARM resource), but `az storage container create --auth-mode login` and
#     Terraform's `ARM_USE_AZUREAD=true` backend both talk to the BLOB
#     ENDPOINT and need a data-plane role. Subscription scope is broader than
#     strictly necessary (RG scope would work too, but the RG doesn't exist
#     yet), which is acceptable for a playground.
az role assignment create \
  --assignee-object-id "$BOOTSTRAP_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 5. Federated credential trusting the ai-foundry-base GitHub environment.
#    Replace GITHUB_OWNER/GITHUB_REPO (e.g. abanjanovic/cloud-playground-infra).
az identity federated-credential create \
  --name gh-actions-ai-foundry-base \
  --identity-name uami-cpi-bootstrap \
  --resource-group rg-shared-identity \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:GITHUB_OWNER/GITHUB_REPO:environment:ai-foundry-base" \
  --audiences "api://AzureADTokenExchange"

echo "BOOTSTRAP_CLIENT_ID=$BOOTSTRAP_CLIENT_ID"
echo "TENANT_ID=$TENANT_ID"
echo "SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
```

Save the three `echo`-ed values in a scratchpad — you'll paste them into GitHub in step C.

**Verify (must all return values, not errors):**

```bash
az role assignment list --assignee "$BOOTSTRAP_PRINCIPAL_ID" --scope "/subscriptions/$SUBSCRIPTION_ID" -o table
az identity federated-credential list --identity-name uami-cpi-bootstrap --resource-group rg-shared-identity -o table
```

#### B. Create the two GitHub PATs

Two fine-grained PATs are needed. Create both at https://github.com/settings/personal-access-tokens/new. **Scope each to only this repository.**

| PAT | Repository permissions | Used for | Store as |
|---|---|---|---|
| `GH_ADMIN_PAT` | Environments: **Read and write** · Secrets: **Read and write** · Variables: **Read and write** · Metadata: Read | The bootstrap workflow uses this to create environments + populate their secrets/vars. | **Repo-level** secret |
| `GH_RUNNER_PAT` | Administration: **Read and write** · Metadata: Read | The self-hosted runner uses this at boot to mint a fresh runner-registration token from the GitHub API. | Workflow input in Step 1 (ends up as env-scoped secret) |

Give them a sensible expiration (90 days is fine — rotate by re-running Step 1).

**Store `GH_ADMIN_PAT` as a repo-level secret NOW** — this is the ONE manual GitHub-UI step:

```bash
gh secret set GH_ADMIN_PAT --repo GITHUB_OWNER/GITHUB_REPO
# paste the PAT when prompted, press Enter
```

Or via Repo → Settings → Secrets and variables → Actions → New repository secret.

Hold onto `GH_RUNNER_PAT` for Step 1.

#### C. Create both GitHub environments and populate non-personal config

The bootstrap workflow in Step 1 populates the 4 *personal* values (SSH key, PAT, allowlists) as env-scoped secrets/vars. The rest of the per-env config (Azure IDs, RG name, storage settings, working directories) is stack-shape, not personal, so we set it upfront.

Fastest path via `gh` CLI. Replace placeholders (`GITHUB_OWNER/GITHUB_REPO`, `<RESOURCE_GROUP>`, `<STORAGE_ACCOUNT>`) with your values. `STORAGE_ACCOUNT` must be globally unique across all of Azure — pick something like `staifoundry<6-digit-random>`.

```bash
for env in ai-foundry-base ai-foundry-workload; do
  gh api -X PUT "repos/GITHUB_OWNER/GITHUB_REPO/environments/$env" >/dev/null

  gh secret set AZURE_CLIENT_ID       --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "$BOOTSTRAP_CLIENT_ID"
  gh secret set AZURE_TENANT_ID       --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "$TENANT_ID"
  gh secret set AZURE_SUBSCRIPTION_ID --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "$SUBSCRIPTION_ID"
  gh secret set TAGS                  --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "environment=dev workload=ai-foundry"

  gh variable set RESOURCE_GROUP                        --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "rg-ai-foundry-dev"
  gh variable set LOCATION                              --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "centralus"
  gh variable set STORAGE_ACCOUNT                       --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "staifoundry123456"
  gh variable set STORAGE_ACCOUNT_SKU                   --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "Standard_LRS"
  gh variable set STORAGE_ACCOUNT_ENCRYPTION_SERVICES   --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "blob"
  gh variable set STORAGE_ACCOUNT_MIN_TLS_VERSION       --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "TLS1_2"
  gh variable set STORAGE_ACCOUNT_PUBLIC_NETWORK_ACCESS --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "Enabled"
  gh variable set TERRAFORM_STATE_CONTAINER             --env "$env" --repo GITHUB_OWNER/GITHUB_REPO --body "tfstate"
done

# Per-env: different state blob key + working directory
gh variable set TERRAFORM_STATE_BLOB        --env ai-foundry-base     --repo GITHUB_OWNER/GITHUB_REPO --body "base.tfstate"
gh variable set TERRAFORM_WORKING_DIRECTORY --env ai-foundry-base     --repo GITHUB_OWNER/GITHUB_REPO --body "environments/ai-foundry/base/terraform"
gh variable set TERRAFORM_STATE_BLOB        --env ai-foundry-workload --repo GITHUB_OWNER/GITHUB_REPO --body "workload.tfstate"
gh variable set TERRAFORM_WORKING_DIRECTORY --env ai-foundry-workload --repo GITHUB_OWNER/GITHUB_REPO --body "environments/ai-foundry/workload/terraform"
```

`github_org` / `github_repo` are auto-derived at workflow runtime from `${{ github.repository_owner }}` and `${{ github.event.repository.name }}` — no need to store them.

**Verify:**

```bash
gh api "repos/GITHUB_OWNER/GITHUB_REPO/environments" --jq ".environments[].name"
# expected: ai-foundry-base, ai-foundry-workload

gh variable list --env ai-foundry-base --repo GITHUB_OWNER/GITHUB_REPO
# expected: 10 variables (RESOURCE_GROUP, LOCATION, STORAGE_ACCOUNT,
#   STORAGE_ACCOUNT_SKU, STORAGE_ACCOUNT_ENCRYPTION_SERVICES,
#   STORAGE_ACCOUNT_MIN_TLS_VERSION, STORAGE_ACCOUNT_PUBLIC_NETWORK_ACCESS,
#   TERRAFORM_STATE_CONTAINER, TERRAFORM_STATE_BLOB,
#   TERRAFORM_WORKING_DIRECTORY)
```

---

### Step 1. Run the bootstrap workflow (populates the 4 personal inputs)

Actions → **Bootstrap GitHub Environments** → *Run workflow*. Fill in:

| Input | How to get the value |
|---|---|
| `admin_ssh_public_key` | `cat ~/.ssh/id_ed25519.pub` — paste the full single line |
| `github_runner_pat` | The `GH_RUNNER_PAT` you created in Step B (will be masked in logs) |
| `allowed_ssh_source_prefixes` | JSON array of CIDRs. Get your egress IP with `curl ifconfig.me`, e.g. `["203.0.113.42/32"]`. Never `["0.0.0.0/0"]`. |
| `jumpbox_entra_admin_object_ids` | JSON array of Entra object IDs. Get yours with `az ad signed-in-user show --query id -o tsv`. |

Click *Run workflow*. Runs in ~15 seconds.

**Verify (log output ends with):**

```
-> Populating "ai-foundry-base"
   done: ADMIN_SSH_PUBLIC_KEY, GH_RUNNER_PAT, ALLOWED_SSH_SOURCE_PREFIXES, JUMPBOX_ENTRA_ADMIN_OBJECT_IDS
-> Populating "ai-foundry-workload"
   done: ADMIN_SSH_PUBLIC_KEY, GH_RUNNER_PAT, ALLOWED_SSH_SOURCE_PREFIXES, JUMPBOX_ENTRA_ADMIN_OBJECT_IDS

All four inputs populated in both environments.
```

Re-run any time to rotate the PAT, update the SSH allowlist, add a new Entra admin — it's idempotent.

---

### Step 2. Bootstrap the state backend (creates the shared state SA)

Actions → **Terraform Init Remote Backend** → *Run workflow* → Environment: **`ai-foundry-base`**.

Creates the resource group + state storage account + `tfstate` container. Takes ~2 minutes. State SA ends up with `public-network-access = Disabled` (the workflow's `trap` disables it on exit).

Because `ai-foundry-workload` uses the same `STORAGE_ACCOUNT` and `TERRAFORM_STATE_CONTAINER`, no second run is needed — workload writes `workload.tfstate` into the same container.

**Verify:**

```bash
az storage account show \
  --name <STORAGE_ACCOUNT> \
  --resource-group <RESOURCE_GROUP> \
  --query "publicNetworkAccess" -o tsv
# expected: Disabled

# Container listing via the management (ARM) endpoint works even when the
# data plane is private. Use --auth-mode login only if your identity has
# Storage Blob Data Reader on the SA.
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT>/blobServices/default/containers?api-version=2023-05-01" \
  --query "value[].name" -o tsv
# expected: tfstate
```

---

### Step 3. Deploy the base stack

Actions → **Terraform Plan, Approve, Apply** → *Run workflow* → Environment: **`ai-foundry-base`**. Runs on `ubuntu-latest`. Expect **~10–15 minutes** end-to-end (VNet + NAT + 11 DNS zones + 2 VMs + role assignments).

When the workflow reaches the `manual-approval` step, it opens an issue. Comment `approved` (or click the issue button) to continue.

**Verify (workflow log):**

- Plan step: ~40+ resources to add, 0 to change, 0 to destroy.
- Apply step ends with `Apply complete! Resources: 40+ added, 0 changed, 0 destroyed.`
- Outputs section at the bottom shows:
  ```
  runner_uami_client_id = "abcd1234-5678-..."
  jumpbox_public_ip     = "20.x.y.z"
  jumpbox_vm_name       = "vm-playground-dev-jumpbox"
  runner_vm_name        = "vm-playground-dev-runner"
  ```

Grab `runner_uami_client_id` — you need it for Step 4.

If you need to fetch the outputs from CLI later (requires Storage Blob Data Contributor on the state SA — the bootstrap principal has it from Step A/4b; your personal user may not):

```bash
# First temporarily enable public access on the state SA (workflow-only paths
# do this automatically; from your laptop you have to do it by hand).
az storage account update --name <STORAGE_ACCOUNT> --resource-group <RESOURCE_GROUP> --public-network-access Enabled
sleep 10

terraform -chdir=environments/ai-foundry/base/terraform init \
  -backend-config="resource_group_name=<RESOURCE_GROUP>" \
  -backend-config="storage_account_name=<STORAGE_ACCOUNT>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=base.tfstate"
terraform -chdir=environments/ai-foundry/base/terraform output -raw runner_uami_client_id

az storage account update --name <STORAGE_ACCOUNT> --resource-group <RESOURCE_GROUP> --public-network-access Disabled
```

Recommended alternative: just grab the value from the workflow log's `Outputs:` section — no CLI, no role fiddling.

---

### Step 4. Point the workload env at the runner UAMI

The workload workflow logs in to Azure as the runner UAMI (not the bootstrap principal). Base created a federated credential on the runner UAMI trusting `repo:{owner}/{repo}:environment:ai-foundry-workload` — you just need to point `AZURE_CLIENT_ID` at it.

```bash
gh secret set AZURE_CLIENT_ID \
  --env ai-foundry-workload \
  --repo GITHUB_OWNER/GITHUB_REPO \
  --body "<runner_uami_client_id from Step 3>"
```

Or via UI: Repo → Settings → Environments → `ai-foundry-workload` → `AZURE_CLIENT_ID` → *Update secret*.

**Verify:**

```bash
gh secret list --env ai-foundry-workload --repo GITHUB_OWNER/GITHUB_REPO
# AZURE_CLIENT_ID should show "Updated <recent timestamp>"
```

---

### Step 5. Verify the self-hosted runner is online

Repo → Settings → Actions → Runners. Runner registration happens in cloud-init AFTER VM provisioning (installs Azure CLI + Terraform + tflint + downloads runner tarball). **Allow 5–15 minutes** after Step 3 finishes — first-boot package downloads dominate this window.

You should see:

```
vm-playground-dev-runner   self-hosted, linux, ai-foundry   Idle
```

**If the runner isn't showing up after 15 minutes:**

SSH to the runner is BLOCKED (its NSG has explicit deny-all-inbound at priority 4000), so use `az vm run-command` from your laptop instead:

```bash
# Tail cloud-init output on the runner without SSH
az vm run-command invoke \
  --resource-group <RESOURCE_GROUP> \
  --name vm-playground-dev-runner \
  --command-id RunShellScript \
  --scripts "sudo tail -n 200 /var/log/cloud-init-output.log"

# Check the runner systemd service
az vm run-command invoke \
  --resource-group <RESOURCE_GROUP> \
  --name vm-playground-dev-runner \
  --command-id RunShellScript \
  --scripts "sudo systemctl status 'actions.runner.*.service' --no-pager"
```

Common failures:

| Log line contains | Cause | Fix |
|---|---|---|
| `Failed to mint runner registration token` | `GH_RUNNER_PAT` scope is wrong | Regenerate PAT with `Administration: Read and write`, re-run Step 1, then recreate the runner VM: `terraform taint module.cicd_runner.azurerm_linux_virtual_machine.this && terraform apply` (or trigger Step 3 apply again — the taint forces recreation which reruns cloud-init) |
| `Could not resolve host: api.github.com` | NAT gateway not attached | Should not happen if base applied cleanly; check `azurerm_subnet_nat_gateway_association.cicd` in state |
| `Runner already exists` (from a prior half-registration) | Cloud-init's runcmd only fires on first boot; a simple restart does NOT re-run it | (a) Delete the orphaned runner in Repo → Settings → Actions → Runners, then (b) recreate the VM to trigger cloud-init: `terraform taint module.cicd_runner.azurerm_linux_virtual_machine.this` and re-run Step 3 |

---

### Step 6. Deploy the workload stack

Actions → **Terraform Plan, Approve, Apply** → *Run workflow* → Environment: **`ai-foundry-workload`**. The caller workflow auto-selects `runs-on: [self-hosted, ai-foundry]` for this environment name, so it lands on the runner from Step 5.

Expect **~15–20 minutes** (Storage + Cosmos + AI Search + Foundry account + 4 private endpoints + capability hosts + 60s RBAC-propagation `time_sleep`).

Approve the plan when the issue opens.

**Verify (workflow log):**

- Plan: ~30+ resources to add.
- Apply ends with `Apply complete! Resources: 30+ added, 0 changed, 0 destroyed.`

---

### Step 7. Validate private connectivity from the jumpbox

```bash
az ssh vm --resource-group <RESOURCE_GROUP> --name vm-playground-dev-jumpbox
```

On the jumpbox:

```bash
# Every FQDN must resolve to a 10.0.x.x address (private endpoint IP)
nslookup cog-acc-playground-dev-centralus.cognitiveservices.azure.com
nslookup $(az storage account list -g <RESOURCE_GROUP> --query "[?tags.workload=='ai-foundry'].name | [0]" -o tsv).blob.core.windows.net
nslookup $(az cosmosdb list -g <RESOURCE_GROUP> --query "[0].name" -o tsv).documents.azure.com
nslookup $(az search service list -g <RESOURCE_GROUP> --query "[0].name" -o tsv).search.windows.net

# Reachability check — must return HTTP 401 or 404 (auth required, NOT connection refused)
curl -sI https://cog-acc-playground-dev-centralus.cognitiveservices.azure.com | head -1
```

**If any nslookup returns a public IP from the jumpbox**, private DNS linking is broken — verify base created the `azurerm_private_dns_zone_virtual_network_link` resources and they're associated with the correct VNet.

**Same nslookup from OUTSIDE the VNet** (from your laptop) returns the PUBLIC IP, and curl fails with a 403 or connection error because `public_network_access_enabled = false`.

---

## Troubleshooting cheatsheet

| Symptom | Likely cause | Fix |
|---|---|---|
| Bootstrap workflow fails on `gh api` with `HTTP 403` | `GH_ADMIN_PAT` lacks Environments/Secrets/Variables r/w | Regenerate PAT with correct scopes, re-set the repo secret |
| Base apply fails with `AuthorizationFailed` on role assignment | Bootstrap principal has Contributor but not Owner/UAA | Grant Owner (or User Access Administrator alongside Contributor) on the subscription |
| Base apply fails with `SubscriptionNotRegistered` | RP registration failed | Grant Owner, or manually run `az provider register --namespace <RP>` for each namespace listed in `base/terraform/providers.tf` |
| Workload workflow shows `No runner matching the labels was found` | Self-hosted runner not online yet | Wait 3–5 minutes after Step 3 completes, then check Repo → Settings → Actions → Runners |
| Workload apply fails on Cosmos SQL role assignment with a network error | Workflow ran on `ubuntu-latest` instead of self-hosted | Confirm you selected `ai-foundry-workload` (not `ai-foundry-base`) as the environment in the workflow dispatch |
| Workload apply fails on `azurerm_cognitive_account_capability_host` | Foundry data-plane RBAC hasn't propagated | Wait a couple of minutes and re-run apply; the `time_sleep` module is 60s which is usually enough but Azure control-plane RBAC can lag longer under load |

---

## Local development (running Terraform from your laptop)

Once base is deployed and the jumpbox is reachable, you can iterate on workload from your laptop by SSH-ing to the jumpbox, cloning the repo there, and running `terraform apply`. The jumpbox has the same VNet reachability as the runner, so private endpoints resolve correctly.

If you'd rather run Terraform on your laptop directly, you'd need to peer your laptop's network (VPN or ExpressRoute) into the VNet — out of scope for this lab.

## References

- [Foundry Standard Agent Setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup)
- [Foundry private networking guide](https://learn.microsoft.com/azure/foundry/agents/how-to/virtual-networks)
- [Foundry supported regions for private networking](https://learn.microsoft.com/azure/foundry/agents/concepts/limits-quotas-regions#supported-regions)
- [GitHub Actions self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Azure OIDC federation for GitHub Actions](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [GitHub CLI `gh secret set` / `gh variable set`](https://cli.github.com/manual/gh_secret_set)
