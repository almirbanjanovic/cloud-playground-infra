# Cloud Playground Environments

Infrastructure-as-Code for cloud playground environments.

## Structure

- `.github/workflows/` — GitHub Actions workflows for CI/CD-driven deploys of the APIM and Kaito environments
  - `bicep-create-deploy.yaml`, `bicep-what-if.yaml`, `bicep-what-if-create-deploy.yaml`
  - `terraform-init-backend.yaml`, `terraform-plan.yaml`, `terraform-apply.yaml`, `terraform-plan-approve-apply.yaml`
  - `test-oidc.yaml`
- `environments/` — one folder per playground lab. Each has its own IaC (Bicep and/or Terraform) and its own `README.md`.
  - `ai-foundry/` — Foundry Agent Service private-networking lab with **manual** deployment (Bicep OR Terraform). Sub-divided into `base/` (VNet + DNS zones) and `workload/` (Foundry + BYO Storage/Cosmos/AI Search).
  - `apim-lab/` — general APIM learning environment (Bicep + Terraform).
  - `apim-mcp/` — APIM integrated with Model Context Protocol (Terraform).
  - `backend-pool-load-balancing/` — APIM backend pool load balancing demo (Bicep).
  - `kaito-on-aks/` — KAITO on AKS (Terraform + Kubernetes manifests).
- `iac-modules/` — Reusable IaC modules (Bicep and Terraform)
- `assets/` — Repo-wide supporting files
- `LICENSE`, `README.md`, `CI-CD-Guide.md` — repository metadata + CI/CD walkthrough

Repository layout example:

```text
cloud-playground-infra/
├── .github/
│   └── workflows/
├── environments/
│   ├── ai-foundry/
│   │   ├── base/
│   │   │   ├── bicep/
│   │   │   └── terraform/
│   │   ├── workload/
│   │   │   ├── bicep/
│   │   │   └── terraform/
│   │   └── README.md
│   ├── apim-lab/
│   │   ├── bicep/
│   │   └── terraform/
│   ├── apim-mcp/
│   │   └── terraform/
│   ├── backend-pool-load-balancing/
│   │   └── bicep/
│   └── kaito-on-aks/
│       ├── assets/
│       └── terraform/
├── iac-modules/
│   ├── bicep/
│   └── terraform/
├── CI-CD-Guide.md
├── LICENSE
└── README.md
```

## Requirements

- Bicep
- Terraform
- Azure CLI
- Access to an Azure subscription

## Usage

1. Fork the repo.
2. Configure an App Registration in Microsoft Entra ID for OIDC (see below).
3. Create a new Resource Group.
4. Grant appropriate permissions to App Registration. See [IAM Role Suggestions](#iam-role-suggestions) below for details.
5. Create a GitHub Environment for the cloud playground and set required variables.
6. Run the GitHub Actions pipelines in order.

---

## Configure new App Registration in Microsoft Entra ID

To enable GitHub Actions to deploy to Azure using OIDC:

1. In the Azure Portal, go to Microsoft Entra ID → App registrations → New registration.
2. After registration, open the App Registration → Certificates & secrets → Federated credentials → Add credential.
3. Configure the federated credential:
   - Federated credential scenario: GitHub Actions deploying Azure resources
   - Organization: your GitHub org or username
   - Repository: `owner/repo` (e.g., `almirbanjanovic/cloud-playground-infra`)
   - Entity type: Environment
   - Based on selection: GitHub environment name (e.g., `apim-lab`)
4. Save the credential. No client secret is required for OIDC.
5. Copy values for GitHub secrets (repository or environment level):
   - `AZURE_CLIENT_ID` (Application/Client ID)
   - `AZURE_TENANT_ID` (Directory/Tenant ID)
   - `AZURE_SUBSCRIPTION_ID`

### IAM Role Suggestions

- Contributor
  - Scope: Subscription or Resource Group as needed
- Storage Blob Data Contributor 
  - Scope: Storage Account used for Terraform state
- User Access Administrator 
  - Scope: Subscription or Resource Group as needed for managed and RBAC deplyed via IAC
- Additional roles as required by the environment

---

## Configure a new Cloud Playground (GitHub Environment)

1. Go to your repository Settings → Environments and create a new environment (e.g., `apim-lab`).
2. Add the following environment variables (minimum required):

```text
BICEP_WORKING_DIRECTORY
LOCATION
RESOURCE_GROUP
STORAGE_ACCOUNT
STORAGE_ACCOUNT_ENCRYPTION_SERVICES
STORAGE_ACCOUNT_MIN_TLS_VERSION
STORAGE_ACCOUNT_PUBLIC_NETWORK_ACCESS
STORAGE_ACCOUNT_SKU
TERRAFORM_STATE_BLOB
TERRAFORM_STATE_CONTAINER
TERRAFORM_WORKING_DIRECTORY
```

3. Add required secrets (repository or environment level) for OIDC:

```text
AZURE_CLIENT_ID
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
```

4. Update workflow inputs if you add new environment names to the repository-level dropdowns (if used).

---

## Pipelines

- Test Authentication
1. Test OpenID Connect (`test-oidc.yaml`)

After a successful OIDC test you may choose one of two deployment paths:

- Terraform deployment
  1. Terraform Init Remote Backend (`terraform-init-backend.yaml`) — prepares storage backend and related resources
  2. Terraform Plan, Approve, Apply (`terraform-plan-approve-apply.yaml`) — runs plan, requires manual approval, then applies
  - The reusable plan workflow is `terraform-plan.yaml` and the apply workflow is `terraform-apply.yaml`.

- Bicep deployment
  1. Bicep What-If, Deploy (`bicep-what-if-create-deploy.yaml`) — runs the Bicep templates for environments that use Bicep modules. This workflow includes a manual approval step (same manual-approval action used by the Terraform workflow) to review changes before applying.

Notes:
- `Test OpenID Connect` should be run first to validate OIDC setup.
- Choose the deployment path (`Terraform` or `Bicep`) that matches the IaC used for the target environment.

---

## Manual Approval

Workflows "Bicep What-If, Deploy" and "Terraform Plan, Approve, Apply" use `trstringer/manual-approval@v1` to require a manual check of the Terraform plan before applying changes. For production, consider separating Plan and Apply into distinct workflows or gated by PRs.

---

## About This Repository

This repository is intended for training, proof-of-concept, and demo purposes. In production, you would usually maintain one repository per architecture and move reusable workflows to a dedicated repo.


