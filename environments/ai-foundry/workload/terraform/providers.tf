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

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # -----------------------------------------------------------------------------
  # Remote state -- consumed from the storage account BASE creates.
  #
  # `backend "azurerm"` is a "partial" backend here: the container name and
  # blob key are hardcoded, but the resource_group_name + storage_account_name
  # are injected at `terraform init` time via `-backend-config` because they
  # depend on values only known after BASE apply.
  #
  # Typical init command (after `terraform apply` in base/terraform/):
  #
  #   terraform init \
  #     -backend-config="resource_group_name=$(terraform -chdir=../../base/terraform output -raw tfstate_resource_group_name)" \
  #     -backend-config="storage_account_name=$(terraform -chdir=../../base/terraform output -raw tfstate_storage_account_name)"
  #
  # Alternative: create `workload/terraform/backend.tfbackend` with
  #   resource_group_name  = "rg-ai-foundry-dev"
  #   storage_account_name = "sttfs<hash>"
  # then run `terraform init -backend-config=backend.tfbackend`.
  #
  # The state blob (key "workload.tfstate") lives in the `tfstate` container
  # on the tfstate storage account, which has a firewall allowlist that must
  # include the deployer's public IP -- see the ai-foundry README for the
  # deploy lifecycle.
  # -----------------------------------------------------------------------------
  backend "azurerm" {
    container_name   = "tfstate"
    key              = "workload.tfstate"
    use_azuread_auth = true
  }
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
  # RP registration is owned by the BASE stack (which runs first). Setting
  # `resource_provider_registrations = "none"` with no
  # `resource_providers_to_register` list disables all registration attempts
  # from this stack.
  #
  # Prereq: You must deploy the base stack BEFORE the workload stack.
  # ---------------------------------------------------------------------------
  resource_provider_registrations = "none"
}

provider "azapi" {
}

provider "http" {
}