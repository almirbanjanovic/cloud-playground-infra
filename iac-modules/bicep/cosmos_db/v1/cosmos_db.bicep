// ============================================================================
// Cosmos DB (SQL / NoSQL API) — v1
//
// SQL-API Cosmos account, MI-only (local auth disabled), configurable
// public-access + IP allowlist, one private endpoint for the SQL subresource.
// Mirrors the Terraform cosmos_db/v1 module for the AI Foundry workload stack.
// ============================================================================

@description('Short project identifier.')
param baseName string

@description('Environment suffix.')
param environment string

@description('Azure location.')
param location string = resourceGroup().location

@description('Cosmos DB API kind. Only SQL/NoSQL is exercised by this module today; MongoDB and other APIs need different subresource names and connection strings.')
@allowed(['GlobalDocumentDB'])
param kind string = 'GlobalDocumentDB'

@description('Enable public network access. Combine with ipRangeFilter for the deployer-IP allowlist pattern.')
param publicNetworkAccessEnabled bool = true

@description('IPv4 addresses / CIDR ranges allowed on the public endpoint. Ignored when publicNetworkAccessEnabled=false.')
param ipRangeFilter array = []

@description('Whether local (key) auth is enabled. Defaults to false (Entra ID / MI only). SQL API only.')
param localAuthenticationEnabled bool = false

@description('Enable automatic failover.')
param automaticFailoverEnabled bool = false

@description('Enable the free tier (one free-tier account per subscription).')
param freeTierEnabled bool = false

@description('Consistency level.')
@allowed(['BoundedStaleness', 'Eventual', 'Session', 'Strong', 'ConsistentPrefix'])
param consistencyLevel string = 'Session'

@description('Whether the primary geo replica is zone-redundant.')
param zoneRedundant bool = false

@description('Subnet ID where the PE lives.')
param subnetId string

@description('Private DNS zone IDs for the SQL PE.')
param privateDnsZoneIds array

@description('PE subresource group ID. SQL API uses "Sql".')
param subresourceName string = 'Sql'

@description('Tags applied to the account and PE.')
param tags object = {}

var accountName = toLower('cosmos-${baseName}-${environment}-${location}')

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  tags: tags
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: automaticFailoverEnabled
    enableFreeTier: freeTierEnabled
    disableLocalAuth: !localAuthenticationEnabled
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    ipRules: [for ip in ipRangeFilter: {
      ipAddressOrRange: ip
    }]
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: zoneRedundant
      }
    ]
    capabilities: []
  }
}

module pe '../../private_endpoint/v1/private_endpoint.bicep' = {
  name: take('pe-${accountName}', 64)
  params: {
    name: 'pe-${accountName}'
    location: location
    targetResourceId: cosmos.id
    subresourceNames: [subresourceName]
    subnetId: subnetId
    privateDnsZoneIds: privateDnsZoneIds
    tags: tags
  }
}

output id string = cosmos.id
output name string = cosmos.name
output documentEndpoint string = cosmos.properties.documentEndpoint
output principalId string = cosmos.identity.principalId
