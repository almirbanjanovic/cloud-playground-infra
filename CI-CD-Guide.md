# APIM AI Gateway CI/CD Guide

This guide walks through the complete CI/CD setup and deployment process for Azure API Management (APIM) as an AI Gateway using GitHub Actions and OpenID Connect (OIDC) authentication.

## Overview

The CI/CD pipeline automates the deployment of APIM infrastructure and policy configurations using Bicep templates. The workflow includes infrastructure validation (what-if), manual approval gates, and automated deployment.

---

## Understanding "Environments" in This Repository

The term "environment" is used in three distinct ways in this repository. Understanding these differences is critical for proper configuration:

### 1. GitHub Environments (Deployment Targets)

**GitHub Environments** are configured in your repository settings (`Settings → Environments`) and serve as deployment targets for CI/CD workflows.

**In this repository, each GitHub Environment corresponds to a specific lab/illustration project:**

- `ai-foundry` — Deploys the AI Foundry lab
- `apim-lab` — Deploys the general APIM learning environment
- `apim-mcp` — Deploys APIM with Model Context Protocol integration
- `backend-pool-load-balancing` — Deploys the APIM backend pool load balancing example

Each GitHub Environment stores:
- Environment-specific **variables** (e.g., `RESOURCE_GROUP`, `BICEP_WORKING_DIRECTORY`, `LOCATION`)
- Environment-specific **secrets** (e.g., `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`)
- **Protection rules** (optional: required reviewers, branch restrictions)

### 2. Environment Lanes (Traditional SDLC Stages)

**Environment Lanes** refer to traditional software development lifecycle stages:
- Development
- Test/Staging
- Production

**Important:** This repository does **NOT** currently use separate dev/test/prod lanes. All GitHub Environments (`ai-foundry`, `apim-lab`, `apim-mcp`, `backend-pool-load-balancing`) deploy to the same Azure subscription and resource group.

To implement dev/test/prod lanes, you would need to:
1. Create separate resource groups (e.g., `rg-apim-lab-dev`, `rg-apim-lab-test`, `rg-apim-lab-prod`)
2. Create additional GitHub Environments (e.g., `apim-lab-dev`, `apim-lab-test`, `apim-lab-prod`)
3. Configure environment-specific variables for each lane

### 3. Environments Folder (Lab Projects)

The [`environments/`](environments/) folder contains self-contained lab projects or illustration scenarios:

- `ai-foundry/` — AI Foundry infrastructure with Terraform
- `apim-lab/` — General APIM concepts and configurations (Bicep + Terraform)
- `apim-mcp/` — APIM integrated with Model Context Protocol server
- `backend-pool-load-balancing/` — APIM backend pool load balancing demonstration

**Key Point:** Each folder in `environments/` should have a matching GitHub Environment with the same name to enable deployment via CI/CD.

---

## Prerequisites

- Azure subscription with appropriate permissions
- GitHub repository (forked or cloned)
- Access to Azure Portal and Microsoft Entra ID

---

## 1. Configure App Registration in Microsoft Entra ID

To enable GitHub Actions to deploy to Azure using OIDC (no client secrets required):

### Steps

1. Navigate to the Azure Portal → **Microsoft Entra ID** → **App registrations**
2. Click **New registration**
   - Name: e.g., `github-actions-apim-gateway`
   - Supported account types: Single tenant
   - Click **Register**

3. After registration, navigate to **Certificates & secrets** → **Federated credentials** → **Add credential**

4. Configure the federated credential:
   - **Federated credential scenario**: GitHub Actions deploying Azure resources
   - **Organization**: Your GitHub username or organization (e.g., `almirbanjanovic`)
   - **Repository**: `owner/repo-name` (e.g., `almirbanjanovic/cloud-playground-infra`)
   - **Entity type**: Environment
   - **GitHub environment name**: e.g., `apim-lab`, `backend-pool-load-balancing`, or `apim-mcp`
   - **Name**: A descriptive name (e.g., `github-apim-lab-oidc`)

5. Click **Add** to save the credential

6. Copy the following values (needed for GitHub secrets):
   - **Application (client) ID** → Use for `AZURE_CLIENT_ID`
   - **Directory (tenant) ID** → Use for `AZURE_TENANT_ID`
   - Your **Subscription ID** → Use for `AZURE_SUBSCRIPTION_ID`

> **Note**: Repeat step 3-4 for each GitHub environment you plan to use (e.g., `ai-foundry`, `apim-lab`, `apim-mcp`, `backend-pool-load-balancing`).

---

## 2. Create Resource Group

Create a dedicated resource group for your APIM AI Gateway resources.

### Using Azure Portal

1. Navigate to **Resource groups** → **Create**
2. Select your subscription
3. **Resource group name**: e.g., `rg-apim-aigateway-dev`
4. **Region**: Choose your preferred location (e.g., `Central US`)
5. Click **Review + create** → **Create**

### Using Azure CLI

```powershell
az group create --name rg-apim-aigateway-dev --location centralus
```

---

## 3. Grant RBAC Permissions to App Registration

Assign the necessary roles to the App Registration to allow infrastructure deployment and management.

### Recommended Role Assignments

Assign the following roles to your App Registration, scoped to the **Resource Group** or **Subscription**:

| Role | Scope | Purpose |
|------|-------|---------|
| **Contributor** | Resource Group or Subscription | Deploy and manage Azure resources |
| **Storage Blob Data Contributor** | Storage Account (for Terraform state) | Read/write Terraform state files |
| **User Access Administrator** | Resource Group or Subscription | Assign managed identities and RBAC roles via IaC |

### Steps to Assign Roles

1. Navigate to your **Resource Group** → **Access control (IAM)** → **Add role assignment**
2. Select the role (e.g., **Contributor**)
3. Click **Next** → **Select members**
4. Search for your App Registration by name (e.g., `github-actions-apim-gateway`)
5. Click **Select** → **Review + assign**

Repeat for each required role.

> **Important**: For production environments, follow the principle of least privilege and scope permissions as narrowly as possible.

For detailed role recommendations, see [IAM Role Suggestions](../../README.md#iam-role-suggestions) in the main README.

---

## 4. Configure GitHub Environment

Set up a GitHub environment with the required variables and secrets.

### Steps

1. Go to your GitHub repository → **Settings** → **Environments**
2. Click **New environment** and create an environment (e.g., `apim-lab`, `backend-pool-load-balancing`)
3. Add **Environment variables**:

```text
BICEP_WORKING_DIRECTORY=environments/backend-pool-load-balancing/bicep
LOCATION=centralus
RESOURCE_GROUP=rg-apim-aigateway-dev
STORAGE_ACCOUNT=stterraformstatedev
STORAGE_ACCOUNT_ENCRYPTION_SERVICES=blob
STORAGE_ACCOUNT_MIN_TLS_VERSION=TLS1_2
STORAGE_ACCOUNT_PUBLIC_NETWORK_ACCESS=Enabled
STORAGE_ACCOUNT_SKU=Standard_LRS
TERRAFORM_STATE_BLOB=terraform.tfstate
TERRAFORM_STATE_CONTAINER=tfstate
TERRAFORM_WORKING_DIRECTORY=environments/backend-pool-load-balancing/terraform
```

4. Add **Environment secrets** or **Repository secrets**:

```text
AZURE_CLIENT_ID=<your-app-registration-client-id>
AZURE_TENANT_ID=<your-tenant-id>
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
```

5. (Optional) Configure **Environment protection rules**:
   - Required reviewers for manual approvals
   - Deployment branches (e.g., only `main`)

---

## 5. Review Workflow Steps for Infrastructure Deployment

The infrastructure deployment uses the [**Bicep What-If, Create Deploy**](.github/workflows/bicep-what-if-create-deploy.yaml) workflow.

### Workflow Overview

The workflow consists of three sequential jobs:

#### Job 1: `bicep-what-if`
- **Purpose**: Preview infrastructure changes before deployment
- **Steps**:
  1. Checkout repository code
  2. Authenticate to Azure using OIDC
  3. Run `az deployment group what-if` to show what resources will be created, modified, or deleted
- **Reusable workflow**: [bicep-what-if.yaml](.github/workflows/bicep-what-if.yaml)

#### Job 2: `manual-approval`
- **Purpose**: Require manual review and approval before deployment
- **Steps**:
  1. GitHub issue automatically created for manual approval
  2. Wait for an authorized approver to comment `/approve` or `/deny`
  3. Fail deployment if denied
- **Action**: `trstringer/manual-approval@v1`
- **Approvers**: Configured in the workflow (e.g., `almirbanjanovic`)

#### Job 3: `bicep-create-deploy`
- **Purpose**: Deploy infrastructure to Azure
- **Steps**:
  1. Checkout repository code
  2. Authenticate to Azure using OIDC
  3. Deploy Bicep template using `azure/arm-deploy@v1` action
- **Reusable workflow**: [bicep-create-deploy.yaml](.github/workflows/bicep-create-deploy.yaml)

### Workflow Diagram

```text
┌─────────────────┐
│ Bicep What-If   │
│ (Preview)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Manual Approval │
│ (GitHub Issue)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Bicep Deploy    │
│ (Create)        │
└─────────────────┘
```

---

## 6. Run Infrastructure Deployment Workflow

### Steps

1. Navigate to your GitHub repository → **Actions**
2. Select the **Bicep What-If, Create Deploy** workflow
3. Click **Run workflow**
4. Select:
   - **Branch**: `main` (or your working branch)
   - **Environment**: Choose your environment (e.g., `apim-lab`, `backend-pool-load-balancing`)
5. Click **Run workflow**

### Monitor Workflow Progress

1. The **Bicep What-If** job runs first and displays infrastructure changes
2. Review the what-if output in the workflow logs
3. A **GitHub issue** is automatically created for manual approval
4. Navigate to **Issues** → Find the approval issue
5. Review the what-if results and comment:
   - `/approve` to proceed with deployment
   - `/deny` to cancel deployment
6. After approval, the **Bicep Create Deploy** job runs automatically
7. Verify deployment success in the workflow logs and Azure Portal

---

## 7. Review Workflow Steps for Policy Updates

Policy updates are deployed as part of the infrastructure deployment. APIM policies are embedded in Bicep templates using the `loadTextContent()` function.

### How Policy Updates Work

1. **Policy files** are stored alongside Bicep templates (e.g., [`policy.xml`](environments/backend-pool-load-balancing/policy.xml))
2. **Bicep templates** reference policy files using `loadTextContent()`:

```bicep
policyXml: loadTextContent('../policy.xml')
```

3. When the Bicep deployment runs, the policy XML is loaded and applied to the APIM API or operation

### Example Policy Structure

```xml
<policies>
    <inbound>
        <base />
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
        <set-header name="Authorization" exists-action="override">
            <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
        </set-header>
        <set-backend-service backend-id="{backend-id}" />
        <azure-openai-emit-token-metric namespace="openai">
            <dimension name="Subscription ID" value="@(context.Subscription.Id)" />
        </azure-openai-emit-token-metric>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

---

## 8. Make Changes to Policy and Submit via Commit/Pull Request

### Option A: Direct Commit (Fast Iteration)

1. Edit the policy file (e.g., [`environments/backend-pool-load-balancing/policy.xml`](environments/backend-pool-load-balancing/policy.xml))
2. Make your changes (e.g., add rate limiting, modify headers, add caching)
3. Commit changes:

```powershell
git commit -am "feat: add rate limiting to APIM policy"
git push origin main
```

4. Manually trigger the **Bicep What-If, Create Deploy** workflow from the Actions tab
5. Review what-if output, approve, and deploy

### Option B: Pull Request (Recommended for Production)

1. Create a new branch:

```powershell
git checkout -b feature/update-apim-policy
```

2. Edit the policy file (e.g., [`policy.xml`](environments/backend-pool-load-balancing/policy.xml))
3. Commit and push changes:

```powershell
git commit -m "feat: add request throttling to AI gateway policy"
git push origin feature/update-apim-policy
```

4. Create a **Pull Request** in GitHub
5. Add reviewers and request approval
6. After PR approval, merge to `main`
7. Trigger the deployment workflow manually or configure automatic triggers on merge

### Policy Change Examples

#### Example 1: Add Rate Limiting

```xml
<inbound>
    <base />
    <rate-limit calls="100" renewal-period="60" />
    <!-- existing policies -->
</inbound>
```

#### Example 2: Add Response Caching

```xml
<inbound>
    <base />
    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" />
</inbound>
<outbound>
    <base />
    <cache-store duration="3600" />
</outbound>
```

#### Example 3: Add Request Validation

```xml
<inbound>
    <base />
    <validate-content unspecified-content-type-action="prevent" max-size="102400" size-exceeded-action="prevent" />
    <validate-headers specified-header-action="prevent" unspecified-header-action="ignore" errors-variable-name="validationErrors" />
</inbound>
```

---

## Workflow Files Reference

- [**bicep-what-if-create-deploy.yaml**](.github/workflows/bicep-what-if-create-deploy.yaml) - Main deployment workflow (what-if → approve → deploy)
- [**bicep-what-if.yaml**](.github/workflows/bicep-what-if.yaml) - Reusable workflow for infrastructure preview
- [**bicep-create-deploy.yaml**](.github/workflows/bicep-create-deploy.yaml) - Reusable workflow for infrastructure deployment
- [**test-oidc.yaml**](.github/workflows/test-oidc.yaml) - Test OIDC authentication setup

---

## Troubleshooting

### OIDC Authentication Fails

- Verify the App Registration federated credential matches:
  - GitHub organization/username
  - Repository name
  - Environment name
- Ensure secrets are correctly configured in GitHub

### Deployment Fails Due to Permissions

- Verify RBAC roles are assigned to the App Registration
- Check that roles are scoped correctly (Resource Group or Subscription)

### What-If Shows Unexpected Changes

- Review the Bicep template changes
- Check for parameter changes in environment variables
- Verify policy XML syntax is valid

### Policy Not Applied

- Ensure `loadTextContent()` path is correct in Bicep
- Validate XML syntax in policy file
- Check APIM deployment logs in Azure Portal

---

## Best Practices

1. **Always run what-if** before deploying infrastructure changes
2. **Use pull requests** for policy changes in production environments
3. **Test policy changes** in a dev/staging environment first
4. **Use environment-specific** GitHub environments for isolation
5. **Monitor APIM metrics** after policy updates (rate limiting, token usage, errors)
6. **Version control all policies** in the repository
7. **Use semantic commit messages** (e.g., `feat:`, `fix:`, `chore:`)

---

## Next Steps

- Explore [APIM policy expressions](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions)
- Configure [APIM backend pools](https://learn.microsoft.com/azure/api-management/backends?tabs=bicep) for load balancing
- Set up [Azure Monitor and Application Insights](https://learn.microsoft.com/azure/api-management/api-management-howto-use-azure-monitor) for observability
- Implement [advanced rate limiting](https://learn.microsoft.com/azure/api-management/api-management-sample-flexible-throttling) strategies

---

## Related Documentation

- [Main Repository README](../../README.md)
- [Azure APIM Documentation](https://learn.microsoft.com/azure/api-management/)
- [GitHub Actions OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)