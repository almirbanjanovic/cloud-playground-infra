# AI Foundry Lab

Foundry Agent Service with a **BYO stateful stack** — Storage, Cosmos DB, and AI Search stay in your subscription and are wired to Foundry via managed-identity connections and capability hosts, with a fully-private VNet.

This lab is split into two Terraform stacks:

| Stack | Purpose | Runs from |
|---|---|---|
| [`base/`](base/terraform/) | Shared network (VNet, subnets, NAT, DNS zones) + jumpbox + self-hosted GitHub Actions runner + federated identity for the workload stack. | `ubuntu-latest` (GitHub-hosted) |
| [`workload/`](workload/terraform/) | Foundry account, project, capability hosts + BYO Storage/Cosmos/AI Search + private endpoints. Everything here has `public_network_access_enabled = false`. | `[self-hosted, ai-foundry]` (the runner from `base/`) |

Why the split: workload data-plane operations (Cosmos SQL role assignments, Foundry capability host provisioning, Storage container access) need to reach services whose public network access is disabled. A GitHub-hosted runner can't reach them — the self-hosted runner living inside the VNet can.

## Architecture

Source diagram: [assets/architecture.png](assets/architecture.png) &nbsp; · &nbsp; Icons: [assets/icons/](assets/icons/)

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


## Deploy — CI-only

Five workflow runs (two need one manual approval each). The only manual prerequisites are creating a **temporary Azure service principal** (one command in Cloud Shell) and creating **two GitHub PATs** (browser UI). Everything else is a click.

### Prereq A. Create a temporary Azure bootstrap SP (~1 minute)

The Azure identity workflow needs *something* to authenticate as on its first run — Azure has no way to auth without a pre-existing identity. Create a throwaway service principal with a client secret, use it once, then delete it.

Open [Azure Cloud Shell](https://shell.azure.com) (browser, no local install) and run:

```bash
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

az ad sp create-for-rbac \
  --name cpi-bootstrap-temp \
  --role Owner \
  --scopes "/subscriptions/<YOUR_SUBSCRIPTION_ID>"
```

The command prints JSON with `appId`, `password`, and `tenant`. You'll paste these into three repo secrets in Prereq B.

> The SP has subscription-scope Owner temporarily. You delete it as soon as the Azure identity workflow succeeds (Step 1 prints exact cleanup instructions), so exposure is minutes.

### Prereq B. Create GitHub PATs and store all repo secrets (~4 minutes)

Two fine-grained PATs are needed. Create both at https://github.com/settings/personal-access-tokens/new. **Scope each to only this repository.**

| PAT | Repository permissions | Purpose |
|---|---|---|
| `GH_ADMIN_PAT` | Environments r/w · Secrets r/w · Variables r/w · Metadata r | Both bootstrap workflows use this to create environments and write env-scoped secrets. Also used by the base apply post-step. |
| `GH_RUNNER_PAT` | Administration r/w · Metadata r | Cloud-init on the runner VM uses this to mint fresh runner-registration tokens. Passed to the GitHub-envs workflow as an input. |

Now set **four repo-level secrets** in Repo → Settings → Secrets and variables → Actions → *New repository secret*:

| Name | Value |
|---|---|
| `GH_ADMIN_PAT` | The admin PAT you just created. |
| `AZ_BOOTSTRAP_CLIENT_ID` | `appId` from Prereq A. |
| `AZ_BOOTSTRAP_CLIENT_SECRET` | `password` from Prereq A. |
| `AZ_BOOTSTRAP_TENANT_ID` | `tenant` from Prereq A. |

Hold on to `GH_RUNNER_PAT` — it's an input to Step 2.

---

### Step 1. Actions → *Bootstrap Azure Identity* → *Run workflow*

Input: your Azure `subscription_id`. Everything else has sensible defaults.

Takes ~30 seconds. The workflow:

1. Logs into Azure using the temporary SP (via the `AZ_BOOTSTRAP_*` repo secrets).
2. Creates a resource group `rg-shared-identity` and a UAMI `uami-cpi-bootstrap` inside it.
3. Grants the UAMI subscription-scope `Owner` and `Storage Blob Data Contributor` (with retries against Entra ID replication delay).
4. Creates (or updates) a federated credential trusting `repo:{owner}/{repo}:environment:ai-foundry-base`.
5. Uses `GH_ADMIN_PAT` to write `AZURE_CLIENT_ID` (base only), `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` as env-scoped secrets in both `ai-foundry-base` and `ai-foundry-workload`.
6. Prints cleanup instructions — copy them into Cloud Shell to delete the temporary SP and note which repo secrets to remove.

**Verify** (workflow log tail):

```
Azure bootstrap identity created and GitHub env secrets populated.
```

After a successful run, delete the temporary SP + its 3 repo secrets per the printed instructions. You don't need them again unless you have to recreate the UAMI (rare).

Re-run any time to reconcile drift (repo rename, subscription change, etc.). Idempotent.

---

### Step 2. Actions → *Bootstrap GitHub Environments* → *Run workflow*

Fill in 5 required inputs + 2 optional. `github_runner_pat` is masked in logs.

| Input | Value |
|---|---|
| `state_storage_account_name` | Globally-unique 3-24 lowercase alphanumerics, e.g. `staifoundry123456`. |
| `admin_ssh_public_key` | Output of `cat ~/.ssh/id_ed25519.pub` on your laptop. |
| `github_runner_pat` | `GH_RUNNER_PAT` from Prereq B. |
| `allowed_ssh_source_prefixes` | JSON list of CIDRs allowed to SSH the jumpbox, e.g. `["203.0.113.42/32"]`. Get your egress IP at https://ifconfig.me. Never `["0.0.0.0/0"]`. |
| `jumpbox_entra_admin_object_ids` | JSON list of Entra object IDs (users/groups) allowed to `az ssh vm` the jumpbox. Find yours in Entra ID → Users → your account → Object ID. |
| `resource_group_name` (optional) | Default `rg-ai-foundry-dev`. |
| `tags` (optional) | Default `environment=dev workload=ai-foundry`. |

Takes ~15 seconds. Preflight verifies that Step 1 ran successfully (all 5 Azure secrets present in both envs) before writing anything.

**Verify** (workflow log tail):

```
Bootstrap complete.
ai-foundry-base    : 3 secrets + 11 variables (from this workflow)
ai-foundry-workload: 3 secrets + 11 variables (from this workflow)
```

Re-run any time to rotate `GH_RUNNER_PAT`, change the allowlist, etc. It's idempotent and never touches the Azure identity secrets.

---

### Step 3. Actions → *Terraform Init Remote Backend* → *Run workflow*

Environment: **`ai-foundry-base`**. Takes ~2 minutes.

Creates the resource group + state storage account + `tfstate` container. Public network access ends `Disabled` (the workflow's `trap`). `ai-foundry-workload` shares the same SA + container (different blob key), so no second init is needed.

**Verify**: workflow log ends with the container-create step succeeding.

---

### Step 4. Actions → *Terraform Plan, Approve, Apply* → *Run workflow*

Environment: **`ai-foundry-base`**. Runs on `ubuntu-latest`. Takes **~10–15 minutes** end-to-end.

When the approval issue opens, comment `approved` (or click the button in the issue) to continue.

On successful apply, this workflow automatically:

1. Reads `runner_uami_client_id` from Terraform outputs.
2. Uses `GH_ADMIN_PAT` to update `AZURE_CLIENT_ID` in the `ai-foundry-workload` environment to point at the runner UAMI (which has its own federated credential trusting `ai-foundry-workload`, created by base's Terraform).

That's what makes Step 6 work — no manual copy/paste needed.

**Verify**: workflow log shows `Apply complete!` and a line like `AZURE_CLIENT_ID on ai-foundry-workload updated to runner UAMI (abcd1234...).`

---

### Step 5. (~5–15 minutes wait) Verify the self-hosted runner is online

Repo → Settings → Actions → Runners. Wait for `vm-playground-dev-runner` to show `Idle` with labels `self-hosted, linux, ai-foundry`. Cloud-init downloads and installs packages, so first-boot registration takes 5–15 minutes after the base apply finishes.

If the runner doesn't come online after 15 minutes, see the [troubleshooting appendix](#appendix-a--optional-local-debugging).

---

### Step 6. Actions → *Terraform Plan, Approve, Apply* → *Run workflow*

Environment: **`ai-foundry-workload`**. The caller workflow auto-selects `runs-on: [self-hosted, ai-foundry]` for this environment name, so it lands on the runner from Step 5.

Takes **~15–20 minutes** (Storage + Cosmos + AI Search + Foundry account + 4 private endpoints + capability hosts + 60s RBAC-propagation wait).

Approve the plan when the issue opens.

**Verify**: workflow log ends with `Apply complete!`. You now have the full Foundry Agent Service stack deployed on private endpoints.

---

## Appendix A — Optional local debugging

Nothing below is required for the happy path. Use only if a workflow fails and you need to poke at the deployed resources.

### Diagnose runner cloud-init from your laptop

SSH to the runner is blocked (its NSG denies all inbound at priority 4000). Use Azure's built-in run-command instead — no network path required, no SSH keys:

```bash
az vm run-command invoke \
  --resource-group rg-ai-foundry-dev \
  --name vm-playground-dev-runner \
  --command-id RunShellScript \
  --scripts "sudo tail -n 200 /var/log/cloud-init-output.log"

az vm run-command invoke \
  --resource-group rg-ai-foundry-dev \
  --name vm-playground-dev-runner \
  --command-id RunShellScript \
  --scripts "sudo systemctl status 'actions.runner.*.service' --no-pager"
```

Common failures:

| Log line contains | Cause | Fix |
|---|---|---|
| `Failed to mint runner registration token` | `GH_RUNNER_PAT` scope is wrong | Regenerate with `Administration: r/w`, re-run Step 1, then re-run Step 3 (base apply). The runner VM is tainted implicitly if the cloud-init input changes; otherwise `terraform taint module.cicd_runner.azurerm_linux_virtual_machine.this` first. |
| `Could not resolve host: api.github.com` | NAT gateway not attached | Should not happen if base applied cleanly; check `azurerm_subnet_nat_gateway_association.cicd` in state. |
| `Runner already exists` (from a prior half-registration) | Cloud-init's `runcmd` only fires on first boot — a restart does NOT re-run it | Delete the orphaned runner in Repo → Settings → Actions → Runners, then recreate the VM to trigger cloud-init: `terraform taint module.cicd_runner.azurerm_linux_virtual_machine.this && terraform apply`. |

### Validate private connectivity from the jumpbox

`az ssh vm` uses AAD SSH (the jumpbox has the `AADSSHLoginForLinux` extension + role assignments granted to the Entra IDs you listed in Step 1). No local SSH keys needed if you use it.

```bash
az ssh vm --resource-group rg-ai-foundry-dev --name vm-playground-dev-jumpbox
```

Once inside:

```bash
# Every FQDN must resolve to a 10.0.x.x address (private endpoint IP)
nslookup cog-acc-playground-dev-centralus.cognitiveservices.azure.com
nslookup $(az storage account list -g rg-ai-foundry-dev --query "[?tags.workload=='ai-foundry'].name | [0]" -o tsv).blob.core.windows.net
nslookup $(az cosmosdb list        -g rg-ai-foundry-dev --query "[0].name" -o tsv).documents.azure.com
nslookup $(az search service list  -g rg-ai-foundry-dev --query "[0].name" -o tsv).search.windows.net

# Reachability check — HTTP 401 (auth required) is success. Connection refused = broken PE.
curl -sI https://cog-acc-playground-dev-centralus.cognitiveservices.azure.com | head -1
```

**Same nslookup from OUTSIDE the VNet** (from your laptop) returns the PUBLIC IP, and `curl` fails because `public_network_access_enabled = false`.

### Fetch Terraform outputs from your laptop

Not needed for the CI flow (the base apply logs the outputs and the workflow auto-propagates the important one). But if you want to poke at state:

```bash
# Requires an interactive identity that has Storage Blob Data Contributor
# on the state SA (grant it temporarily, or use the bootstrap principal via
# an Azure VM/automation context assigned to that UAMI — laptops cannot
# assume a UAMI directly).
# Temporarily enable public access on the state SA (workflow does this
# automatically; from laptop you do it manually):
az storage account update --name <STORAGE_ACCOUNT> --resource-group rg-ai-foundry-dev --public-network-access Enabled
sleep 10

terraform -chdir=environments/ai-foundry/base/terraform init \
  -backend-config="resource_group_name=rg-ai-foundry-dev" \
  -backend-config="storage_account_name=<STORAGE_ACCOUNT>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=base.tfstate"
terraform -chdir=environments/ai-foundry/base/terraform output

az storage account update --name <STORAGE_ACCOUNT> --resource-group rg-ai-foundry-dev --public-network-access Disabled
```

---

## Appendix B — Troubleshooting cheatsheet

| Symptom | Likely cause | Fix |
|---|---|---|
| Bootstrap workflow fails on `gh api` with `HTTP 403` | `GH_ADMIN_PAT` lacks Environments/Secrets/Variables r/w | Regenerate PAT with correct scopes, update the repo secret, re-run Step 1. |
| Base apply fails with `AuthorizationFailed` on role assignment | Bootstrap principal has Contributor but not Owner | Grant Owner (or User Access Administrator alongside Contributor) on the subscription — see Prereq A. |
| Base apply fails with `SubscriptionNotRegistered` | RP registration failed | Grant subscription Owner to the bootstrap principal, or manually run `az provider register --namespace <RP>` for each namespace in `base/terraform/providers.tf`. |
| Base post-apply step fails with `gh: HTTP 404 on repos/.../environments/ai-foundry-workload/secrets` | `ai-foundry-workload` env doesn't exist | Run Step 1 (bootstrap workflow) first — it creates both environments. |
| Step 5 workflow shows `No runner matching the labels was found` | Self-hosted runner not online yet | Wait 5–15 minutes after Step 3 completes, check Repo → Settings → Actions → Runners. Use the run-command diagnostics in Appendix A if it's still missing. |
| Step 5 apply fails on Cosmos SQL role assignment with a network error | Workflow accidentally ran on `ubuntu-latest` | Confirm you selected `ai-foundry-workload` (not `ai-foundry-base`) as the environment. |
| Step 5 apply fails on `azurerm_cognitive_account_capability_host` | Foundry data-plane RBAC hasn't propagated | Wait a couple of minutes and re-run apply; the `time_sleep` module is 60s which is usually enough but Azure control-plane RBAC can lag longer under load. |

---

## References

- [Foundry Standard Agent Setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup)
- [Foundry private networking guide](https://learn.microsoft.com/azure/foundry/agents/how-to/virtual-networks)
- [Foundry supported regions for private networking](https://learn.microsoft.com/azure/foundry/agents/concepts/limits-quotas-regions#supported-regions)
- [GitHub Actions self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Azure OIDC federation for GitHub Actions](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [GitHub CLI `gh secret set` / `gh variable set`](https://cli.github.com/manual/gh_secret_set)
