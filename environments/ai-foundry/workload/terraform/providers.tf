terraform {
  required_version = ">=1.7.5"

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.10"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_certificates_on_destroy = true
      recover_soft_deleted_certificates          = true
      purge_soft_deleted_secrets_on_destroy      = true
      recover_soft_deleted_secrets               = true
    }
  }

  storage_use_azuread = true

  # ---------------------------------------------------------------------------
  # RP registration is owned by the BASE stack.
  #
  # Workload runs as the runner UAMI, which has only RG-scope Owner on the
  # target RG. RP registration is a SUBSCRIPTION-scope operation and would
  # fail from this principal. The base stack (running as a bootstrap principal
  # with sub-scope perms) has already registered every namespace both stacks
  # use — see environments/ai-foundry/base/terraform/providers.tf.
  #
  # Setting `resource_provider_registrations = "none"` with no
  # `resource_providers_to_register` list disables all registration attempts
  # from this stack.
  #
  # Prereq: You must deploy the base stack BEFORE the workload stack.
  # ---------------------------------------------------------------------------
  resource_provider_registrations = "none"
}

provider "azapi" {
}