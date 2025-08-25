
# cloud-playground-infra

Infrastructure-as-Code for cloud playground environments.


## Structure

- `environments/` – Contains cloud playgrounds (each subfolder is a separate environment)
- `iac-modules/` – Infrastructure-as-Code modules (Terraform and Bicep for Azure resources)
- `assets/` – Supporting files:
	- `kubernetes/` – Kubernetes manifests (e.g., for databases, machine learning)
	- `scripts/` – Utility scripts (SQL, shell, etc.)
- `.github/` – GitHub Actions workflows and configuration

## Usage

1. Clone the repo.
2. Configure environment variables in your repository’s Settings → Environments for your chosen environment.
3. Run the following GitHub Actions pipelines.

## Requirements

- Terraform
- Azure CLI
- Access to an Azure subscription

---

For details on modules or workflows, see comments in the code.

## Adding a New Environment ("Cloud Playground")

To add a new environment:

1. Go to your repository’s **Settings** → **Environments** in GitHub.
2. Create a new environment (e.g., `dev`, `test`, `prod`, etc.).
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
5. You can now run the following pipelines:


	1. Test OpenID Connect
	2. Terraform Init Remote Backend
	3. Terraform Plan, Approve, Apply
