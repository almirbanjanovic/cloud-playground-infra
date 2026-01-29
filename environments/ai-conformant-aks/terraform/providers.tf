terraform {
  required_version = ">=1.14.4"

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.58.0"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~>2.8.0"
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