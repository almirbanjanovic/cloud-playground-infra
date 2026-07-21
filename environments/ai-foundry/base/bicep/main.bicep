// ============================================================================
// AI Foundry -- BASE stack (Bicep, RG-scoped).
//
// Deploy from your laptop:
//
//   az group create -n rg-ai-foundry-dev-westus3 -l westus3
//   az deployment group create \
//     -g rg-ai-foundry-dev-westus3 \
//     -f main.bicep \
//     -p main.bicepparam
//
// Peer of `environments/ai-foundry/base/terraform/`. Creates:
//   - VNet with 5 subnets (4 PE + 1 agent, delegated to Microsoft.App/environments)
//   - 11 private DNS zones (3 cognitive + 6 storage + 1 cosmos + 1 search),
//     each VNet-linked so PEs created by the workload stack auto-register.
//
// No jumpbox, no NAT. Both stacks apply from the deployer's laptop; the
// workload stack pins the deployer's IP into each workload service's firewall
// allowlist.
// ============================================================================

targetScope = 'resourceGroup'

// ----------------------------------------------------------------------------
// Parameters
// ----------------------------------------------------------------------------

@description('Short project identifier used as a prefix for derived names.')
param baseName string = 'ai-foundry'

@description('Environment suffix (e.g. dev / prod).')
param environment string = 'dev'

@description('Azure region for the VNet + every regional resource. `westus3` is on Microsoft\'s list of Foundry Agent Service regions that support the private-networking Standard Setup, has 3 availability zones, and has broad Azure OpenAI model coverage.')
param location string = 'westus3'

@description('VNet name. Leave blank to use the convention vnet-<baseName>-<environment>-<location>.')
param vnetName string = ''

@description('VNet address space CIDR blocks.')
param vnetAddressSpace array = ['10.0.0.0/16']

@description('Tags applied to every resource.')
param tags object = {
  environment: 'dev'
  workload: 'ai-foundry'
  stack: 'base'
  managed_by: 'bicep'
}

// ----------------------------------------------------------------------------
// Locals
// ----------------------------------------------------------------------------

var effectiveVnetName = empty(vnetName) ? 'vnet-${baseName}-${environment}-${location}' : vnetName

var cognitiveDnsZones = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]

var storageDnsZones = [
  'privatelink.blob.${az.environment().suffixes.storage}'
  'privatelink.file.${az.environment().suffixes.storage}'
  'privatelink.queue.${az.environment().suffixes.storage}'
  'privatelink.table.${az.environment().suffixes.storage}'
  'privatelink.dfs.${az.environment().suffixes.storage}'
  'privatelink.web.${az.environment().suffixes.storage}'
]

var cosmosDnsZone = 'privatelink.documents.azure.com'
var searchDnsZone = 'privatelink.search.windows.net'

// Subnet map -- key = logical name used in outputs; value.name = Azure name.
var subnets = {
  cognitive_pep: {
    name: 'snet-cognitive-${baseName}-${environment}'
    addressPrefixes: ['10.0.1.0/24']
  }
  storage_pep: {
    name: 'snet-storage-${baseName}-${environment}'
    addressPrefixes: ['10.0.2.0/24']
  }
  cosmos_pep: {
    name: 'snet-cosmos-${baseName}-${environment}'
    addressPrefixes: ['10.0.3.0/24']
  }
  search_pep: {
    name: 'snet-search-${baseName}-${environment}'
    addressPrefixes: ['10.0.4.0/24']
  }
  agent: {
    name: 'snet-agent-${baseName}-${environment}'
    addressPrefixes: ['10.0.10.0/24']
    delegations: [
      {
        name: 'Microsoft.App/environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// Modules
// ----------------------------------------------------------------------------

module vnet '../../../../iac-modules/bicep/vnet/v1/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    name: effectiveVnetName
    location: location
    addressSpace: vnetAddressSpace
    subnets: subnets
    tags: tags
  }
}

module cognitiveZones '../../../../iac-modules/bicep/private_dns_zone/v1/dns_zone.bicep' = [for zone in cognitiveDnsZones: {
  name: 'deploy-dns-${replace(zone, '.', '-')}'
  params: {
    zoneName: zone
    vnetId: vnet.outputs.id
    tags: tags
  }
}]

module storageZones '../../../../iac-modules/bicep/private_dns_zone/v1/dns_zone.bicep' = [for zone in storageDnsZones: {
  name: 'deploy-dns-${replace(zone, '.', '-')}'
  params: {
    zoneName: zone
    vnetId: vnet.outputs.id
    tags: tags
  }
}]

module cosmosZone '../../../../iac-modules/bicep/private_dns_zone/v1/dns_zone.bicep' = {
  name: 'deploy-dns-${replace(cosmosDnsZone, '.', '-')}'
  params: {
    zoneName: cosmosDnsZone
    vnetId: vnet.outputs.id
    tags: tags
  }
}

module searchZone '../../../../iac-modules/bicep/private_dns_zone/v1/dns_zone.bicep' = {
  name: 'deploy-dns-${replace(searchDnsZone, '.', '-')}'
  params: {
    zoneName: searchDnsZone
    vnetId: vnet.outputs.id
    tags: tags
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output vnetId string = vnet.outputs.id
output vnetName string = vnet.outputs.name
output subnetIds object = vnet.outputs.subnetIds
output subnetNames object = vnet.outputs.subnetNames
