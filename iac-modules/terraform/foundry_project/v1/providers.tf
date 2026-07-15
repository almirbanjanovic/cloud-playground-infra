terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.10"
    }

    # Used only for time_sleep between RBAC assignments and the capability
    # host below — gives Entra ID / Azure RBAC time to propagate before
    # ARM checks permissions during capability-host provisioning.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
