# Cloud Playground Environments

Infrastructure-as-Code for cloud playground environments.

---

## Structure

- `environments/` – Contains cloud playgrounds (each subfolder is a separate environment)
- `iac-modules/` – Infrastructure-as-Code modules (Terraform and Bicep for Azure resources)
- `assets/` – Supporting files:
	- `kubernetes/` – Kubernetes manifests (e.g., for databases, machine learning)
	- `scripts/` – Utility scripts (SQL, shell, etc.)
- `.github/` – GitHub Actions workflows and configuration

## Requirements

- Terraform
- Azure CLI
- Access to an Azure subscription

## Usage

1. Fork the repo.
2. Configure new App Registration in Microsoft Entra ID.
3. Configure a new Cloud Playground.
4. Deploy a new Cloud Playground.


---

## Configure new App Registration in Microsoft Entra ID

To enable GitHub Actions to deploy to Azure using OIDC, follow these steps:

1. In the Azure Portal, go to **Microsoft Entra ID** > **App registrations** > **New registration**. Register a new application for your cloud playground.
2. After registration, go to your new App Registration > **Certificates & secrets** > **Federated credentials** > **Add credential**.
3. Configure the federated credential as follows:
	- **Federated credential scenario**: GitHub Actions deploying Azure resources
	- **Organization**: Your GitHub org or username
	- **Repository**: Your repository name (e.g., `almirbanjanovic/cloud-playground-infra`)
	- **Entity type**: Environment
	- **Based on selection**: The GitHub environment name (your cloud playground)
4. Save the federated credential. No client secret is required for OIDC.
5. Copy the following values for use as GitHub secrets:
	- Application (client) ID → `AZURE_CLIENT_ID`
	- Directory (tenant) ID → `AZURE_TENANT_ID`
	- Your Azure Subscription ID → `AZURE_SUBSCRIPTION_ID`

---

### Assign IAM Roles for App Registration

1. **Contributor** (subscription scope is required for 2. Terraform Init Remote Backend to create Resource Group, but best practice would be to lower this later to adhere to Principle of Least Privilege)
2. **Storage Blob Data Contributor** (at the scope of the storage account used for the Terraform state)
3. Additional RBAC roles as required by your cloud playground's resources

You can assign these roles in the Azure Portal under the relevant scope's **Access control (IAM)** > **Add role assignment**. Use the App Registration's client ID as the principal.

---

## Configure a new Cloud Playground

1. Go to your repository’s **Settings** → **Environments** in GitHub.
2. Create a cloud playground (new environment) (e.g., `dev`, `test`, `prod`, etc.).
3. Add the following environment variables (minimum required):

	- `LOCATION`
	- `RESOURCE_GROUP`
	- `STORAGE_ACCOUNT`
	- `STORAGE_ACCOUNT_ENCRYPTION_SERVICES`
	- `STORAGE_ACCOUNT_MIN_TLS_VERSION`
	- `STORAGE_ACCOUNT_PUBLIC_NETWORK_ACCESS`
	- `STORAGE_ACCOUNT_SKU`
	- `TERRAFORM_STATE_BLOB`
	- `TERRAFORM_STATE_CONTAINER`
	- `WORKING_DIRECTORY`
4. Add these secrets (at the environment or repository level) for OIDC authentication:

	- `AZURE_CLIENT_ID` (from Microsoft Entra ID Application Registration)
	- `AZURE_SUBSCRIPTION_ID`
	- `AZURE_TENANT_ID` (Microsoft Entra Tenant ID)

5. Add new cloud playground folder name to `terraform-init-backend.yaml` and `terraform-plan-approve-apply.yaml` under `options`:
```
inputs:
	environment:
	description: 'Select environment'
	required: true
	default: apim-lab
	type: choice
	options:
		- ai-foundry
		- apim-lab
```

---

## Terraform a new Cloud Playground
You can now run the following pipelines:


	1. Test OpenID Connect
	2. Terraform Init Remote Backend
	3. Terraform Plan, Approve, Apply

---

## Manual Approval in Cloud Playground Pipelines

The workflow **3. Terraform Plan, Approve, Apply** uses [trstringer/manual-approval@v1](https://github.com/trstringer/manual-approval) to require a manual check of the Terraform plan before applying changes. This is intended for cloud playground scenarios to allow review and approval of infrastructure changes.

> **Note:** Generally, it is best practice to separate Terraform Plan and Terraform Apply into different workflows or pull requests (PRs) for better change management and review.

---

## About This Repository

This repository is intended for training, proof-of-concept, and demo purposes. In a real-world production scenario:

- There would typically be one repository per architecture or environment.
- Reusable workflows could also be maintained in a dedicated repository and shared across projects.
