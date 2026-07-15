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
  # Base runs from a bootstrap principal (typically GitHub-hosted runner with
  # subscription-scoped permissions) that CAN register resource providers. The
  # workload stack runs as the runner UAMI which only has RG-scope Owner and
  # cannot register RPs — so we register everything here and workload sets
  # `resource_provider_registrations = "none"` with an empty registration list.
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
    "Microsoft.ManagedIdentity",         # UAMI for runner
    "Microsoft.Network",                 # VNet, subnets, PE, NAT, DNS zones
    "Microsoft.Search",                  # AI Search (workload)
    "Microsoft.Storage",                 # Storage accounts (workload + state)
  ]
}
