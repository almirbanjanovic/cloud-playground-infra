output "id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "The address space of the Virtual Network"
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "The IDs of the subnets within the Virtual Network"
  value = {
    acr                  = azurerm_subnet.acr.id
    aks_nodes            = azurerm_subnet.aks_nodes.id
    aks_pods             = azurerm_subnet.aks_pods.id
    aks_api_server       = azurerm_subnet.aks_api_server.id
    app_gateway          = azurerm_subnet.app_gateway.id
    azure_psql           = azurerm_subnet.azure_psql.id
    key_vault            = azurerm_subnet.key_vault.id
    private_dns_resolver = azurerm_subnet.private_dns_resolver.id
    storage_account      = azurerm_subnet.storage_account.id
    vpn_gateway          = azurerm_subnet.vpn_gateway.id
    azure_monitor        = azurerm_subnet.azure_monitor.id
  }
}

output "subnet_names" {
  description = "The names of the subnets within the Virtual Network"
  value = {
    acr                  = azurerm_subnet.acr.name
    aks_nodes            = azurerm_subnet.aks_nodes.name
    aks_pods             = azurerm_subnet.aks_pods.name
    aks_api_server       = azurerm_subnet.aks_api_server.name
    app_gateway          = azurerm_subnet.app_gateway.name
    azure_psql           = azurerm_subnet.azure_psql.name
    key_vault            = azurerm_subnet.key_vault.name
    private_dns_resolver = azurerm_subnet.private_dns_resolver.name
    storage_account      = azurerm_subnet.storage_account.name
    vpn_gateway          = azurerm_subnet.vpn_gateway.name
    azure_monitor        = azurerm_subnet.azure_monitor.name
  }
}
