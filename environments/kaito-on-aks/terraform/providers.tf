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

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~>1.18.0"
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
  host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  load_config_file       = false
}