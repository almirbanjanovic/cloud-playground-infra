terraform {
  required_version = ">=1.7.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # -----------------------------------------------------------------------------
  # RP registration — the base stack owns registration for BOTH stacks.
  #
  # Both terraform workflows (base and workload) authenticate as the same
  # subscription-scope App Registration (see ai-foundry README > Auth model),
  # which has permission to register resource providers. Base runs first, so
  # it does the registration for every namespace both stacks consume; workload
  # then sets `resource_provider_registrations = "none"` with no list, so it
  # never attempts registration.
  #
  # Idempotent: registering an already-registered RP is a no-op.
  # -----------------------------------------------------------------------------
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.App",                     # subnet delegation to Microsoft.App/environments + Container Apps host for Foundry Agent runtime
    "Microsoft.CognitiveServices",       # Foundry account, project, capability hosts, connections (workload)
    "Microsoft.Compute",                 # jumpbox + runner VMs
    "Microsoft.ContainerService",        # AKS backend for Microsoft.App
    "Microsoft.DocumentDB",              # Cosmos DB accounts (workload)
    "Microsoft.KeyVault",                # Foundry secrets management
    "Microsoft.MachineLearningServices", # Capability host backing workspace
    "Microsoft.ManagedIdentity",         # User-Assigned Managed Identity (UAMI) attached to the runner VM
    "Microsoft.Network",                 # VNet, subnets, PE, NAT, DNS zones
    "Microsoft.Search",                  # AI Search (workload)
    "Microsoft.Storage",                 # Storage accounts (workload + state)
  ]
}
