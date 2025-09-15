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

    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

provider "azapi" {
}