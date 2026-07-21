// ============================================================================
// Azure AI Search — v1
//
// Basic-tier Search service, MI-only (local auth disabled), configurable
// public-access + IP allowlist, one private endpoint. Mirrors the Terraform
// ai_search/v1 module for the AI Foundry workload stack.
// ============================================================================

@description('Short project identifier.')
param baseName string

@description('Environment suffix.')
param environment string

@description('Azure location.')
param location string = resourceGroup().location

@description('Search service SKU.')
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param sku string = 'basic'

@description('Enable public network access. Combine with allowedIps for the deployer-IP allowlist pattern.')
param publicNetworkAccessEnabled bool = true

@description('IPv4 addresses / CIDR ranges allowed on the public endpoint.')
param allowedIps array = []

@description('Whether admin/query API keys can be used to authenticate. Defaults to false (Entra ID / RBAC only).')
param localAuthenticationEnabled bool = false

@description('Subnet ID where the PE lives.')
param subnetId string

@description('Private DNS zone IDs for the searchService PE.')
param privateDnsZoneIds array

@description('Tags applied to the search service and PE.')
param tags object = {}

var searchName = toLower('srch-${baseName}-${environment}-${location}')

// Pre-computed IP-rule set (avoids BCP138 -- can't nest for-expressions inside union()).
var searchIpRules = [for ip in allowedIps: {
  value: ip
}]

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: union({
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: publicNetworkAccessEnabled ? 'enabled' : 'disabled'
    disableLocalAuth: !localAuthenticationEnabled
    networkRuleSet: {
      bypass: 'AzureServices'
      ipRules: searchIpRules
    }
  }, localAuthenticationEnabled ? {
    // authOptions can only be set when local auth is enabled -- omit it
    // entirely (rather than serialize null) when disabled, so the ARM RP
    // doesn't see a conflicting property.
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  } : {})
}

module pe '../../private_endpoint/v1/private_endpoint.bicep' = {
  name: take('pe-${searchName}', 64)
  params: {
    name: 'pe-${searchName}'
    location: location
    targetResourceId: search.id
    subresourceNames: ['searchService']
    subnetId: subnetId
    privateDnsZoneIds: privateDnsZoneIds
    tags: tags
  }
}

output id string = search.id
output name string = search.name
output endpoint string = 'https://${search.name}.search.windows.net'
output principalId string = search.identity.principalId
