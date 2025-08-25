resource "azurerm_ai_services" "this" {
  resource_group_name                = var.resource_group_name
  custom_subdomain_name              = "admin-7390-resource"
  fqdns                              = []
  local_authentication_enabled       = true
  location                           = "eastus2"
  name                               = "admin-7390-resource"
  outbound_network_access_restricted = false
  primary_access_key                 = "" # Masked sensitive attribute
  public_network_access              = "Enabled"
  
  secondary_access_key               = "" # Masked sensitive attribute
  sku_name                           = "S0"
  tags                               = {}
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }
  network_acls {
    bypass         = ""
    default_action = "Allow"
    ip_rules       = []
  }
}