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

    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }

  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  storage_use_azuread             = true
  resource_provider_registrations = "none"
}

provider "azapi" {
}