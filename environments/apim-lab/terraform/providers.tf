terraform {
  required_version = ">=1.7.5"

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.41.0"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~>2.6.0"
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

  resource_provider_registrations = "none"
}

provider "azapi" {
}