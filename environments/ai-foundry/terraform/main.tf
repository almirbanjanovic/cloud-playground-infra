resource "azurerm_ai_services" "this" {
  resource_group_name                = var.resource_group_name
  custom_subdomain_name              = "ais-cloud-playground-eastus2"
  location                           = "eastus2"
  name                               = "ais-cloud-playground-eastus2"
  sku_name                           = "S0"
  
  identity {
    type         = "SystemAssigned"
  }
  
  network_acls {
    default_action = "Allow"
  }
}