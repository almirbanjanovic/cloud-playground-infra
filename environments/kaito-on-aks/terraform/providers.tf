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

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>3.0.1"
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

provider "kubernetes" {
  host                   = var.first_run ? null : azurerm_kubernetes_cluster.this.kube_config[0].host
  client_certificate     = var.first_run ? null : base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = var.first_run ? null : base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = var.first_run ? null : base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}