terraform {
  required_version = ">=1.7.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # -----------------------------------------------------------------------------
  # Remote state — consumed from the tfstate storage account that gets
  # bootstrapped manually + imported into this stack. The container name
  # and blob key are hardcoded; the RG name + storage account name are
  # injected via `-backend-config` at `terraform init` time because they
  # depend on values the user chose at bootstrap.
  #
  # Typical init command (after bootstrap.ps1 / bootstrap.sh):
  #
  #   terraform init \
  #     -backend-config="resource_group_name=rg-ai-foundry-dev" \
  #     -backend-config="storage_account_name=sttfs<hash>"
  #
  # Then, before the FIRST `terraform apply`, import the bootstrapped
  # storage account + container so Terraform manages them going forward:
  #
  #   terraform import 'module.tfstate_storage.azurerm_storage_account.this' \
  #     "/subscriptions/<sub>/resourceGroups/rg-ai-foundry-dev/providers/Microsoft.Storage/storageAccounts/sttfs<hash>"
  #
  #   terraform import azurerm_storage_container.tfstate \
  #     "https://sttfs<hash>.blob.core.windows.net/tfstate"
  #
  # See the ai-foundry README for the full deploy lifecycle.
  # -----------------------------------------------------------------------------
  backend "azurerm" {
    container_name   = "tfstate"
    key              = "base.tfstate"
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}

  # -----------------------------------------------------------------------------
  # RP registration — the base stack owns registration for BOTH stacks.
  #
  # Base runs first, so it registers every namespace both stacks consume;
  # workload then sets `resource_provider_registrations = "none"` with no
  # list, so it never attempts registration.
  #
  # Idempotent: registering an already-registered RP is a no-op.
  # -----------------------------------------------------------------------------
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.App",                     # subnet delegation to Microsoft.App/environments + Container Apps host for Foundry Agent runtime
    "Microsoft.CognitiveServices",       # Foundry account, project, capability hosts, connections (workload)
    "Microsoft.ContainerService",        # AKS backend for Microsoft.App
    "Microsoft.DocumentDB",              # Cosmos DB accounts (workload)
    "Microsoft.KeyVault",                # Foundry secrets management
    "Microsoft.MachineLearningServices", # Capability host backing workspace
    "Microsoft.Network",                 # VNet, subnets, PE, DNS zones
    "Microsoft.Search",                  # AI Search (workload)
    "Microsoft.Storage",                 # Storage account (workload)
  ]
}
