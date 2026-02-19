resource "azurerm_ai_services" "this" {
  resource_group_name   = var.resource_group_name
  custom_subdomain_name = "ais-cloud-playground-eastus2"
  location              = "eastus2"
  name                  = "ais-cloud-playground-eastus2"
  sku_name              = "S0"

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"
    bypass = "AzureServices"
  }
}

resource "azurerm_cognitive_account" "this" {
  name                = "cog-acc-playground-eastus2"
  resource_group_name = var.resource_group_name
  location            = "eastus2"
  kind                = "AIServices"
  sku_name            = "S0"

  # required for stateful development in Foundry including agent service
  custom_subdomain_name = "cog-acc-playground-eastus2"
  project_management_enabled = true

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}