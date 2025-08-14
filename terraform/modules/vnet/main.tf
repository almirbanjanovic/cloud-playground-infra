#----------------------------------------------------------------
# General configuration
#----------------------------------------------------------------

locals {
  vnet_name = "vnet-${var.base_name}-${var.environment}-${var.location}"
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_subnet" "acr" {
  name                 = "snet-acr-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_acr]
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_aks_nodes]
}

resource "azurerm_subnet" "aks_api_server" {
  name                 = "snet-aks-api-server-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_aks_api_server]

  delegation {
    name = "Microsoft.ContainerService/managedClusters"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
      name = "Microsoft.ContainerService/managedClusters"
    }
  }
}

resource "azurerm_subnet" "aks_pods" {
  name                 = "snet-aks-pods-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_aks_pods]

  delegation {
    name = "Microsoft.ContainerService/managedClusters"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
      name = "Microsoft.ContainerService/managedClusters"
    }
  }

}

resource "azurerm_subnet" "app_gateway" {
  name                 = "snet-appgw-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_app_gateway]
}

resource "azurerm_subnet" "azure_psql" {
  name                 = "snet-azurepostgresql-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_azure_postgresql]
}

resource "azurerm_subnet" "key_vault" {
  name                 = "snet-keyvault-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_key_vault]
}

resource "azurerm_subnet" "private_dns_resolver" {
  name                 = "snet-dns-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_private_dns_resolver]

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
      name = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "storage_account" {
  name                 = "snet-storage-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_storage_account]
}

resource "azurerm_subnet" "vpn_gateway" {
  name                 = "GatewaySubnet" # This is a required name for the subnet that will host the VPN Gateway
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_vpn_gateway]
}

resource "azurerm_subnet" "azure_monitor" {
  name                 = "snet-azuremonitor-${var.base_name}-${var.environment}-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix_azure_monitor]
}

module "nat_gateway" {
  source              = "../nat_gateway"
  base_name           = var.base_name
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}


#---------------------------------------------------------------------------
# NAT Gateway Subnet Associations.  Required for AKS and Machine Learning
#---------------------------------------------------------------------------

resource "azurerm_subnet_nat_gateway_association" "pod_nat" {
  subnet_id      = azurerm_subnet.aks_pods.id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "node_nat" {
  subnet_id      = azurerm_subnet.aks_nodes.id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "azure_monitor_nat" {
  subnet_id      = azurerm_subnet.azure_monitor.id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "acr_nat" {
  subnet_id      = azurerm_subnet.acr.id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "kv_nat" {
  subnet_id      = azurerm_subnet.key_vault.id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}

resource "azurerm_subnet_nat_gateway_association" "storage_nat" {
  subnet_id      = azurerm_subnet.storage_account.id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
}