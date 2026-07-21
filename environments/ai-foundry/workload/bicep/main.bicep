// ============================================================================
// AI Foundry -- WORKLOAD stack (Bicep, RG-scoped).
//
// Deploy from your laptop AFTER the base stack has been applied:
//
//   az group create -n rg-ai-foundry-dev -l eastus2         # if not already
//   MYIP=$(curl -s https://api.ipify.org)
//   az deployment group create \
//     -g rg-ai-foundry-dev \
//     -f main.bicep \
//     -p main.bicepparam \
//     -p deployerIp=$MYIP
//
// Peer of `environments/ai-foundry/workload/terraform/`. Creates:
//   - Storage (6 PEs), Cosmos DB (1 PE), AI Search (1 PE), Foundry account (1 PE)
//   - All 4 services have publicNetworkAccess=Enabled + default-deny firewall
//     with the deployer's IP pinned in the allowlist. The agent runtime
//     inside the VNet reaches them through their private endpoints.
//   - Foundry project + connections + RBAC + capability hosts.
//
// Bicep has no equivalent of Terraform's `data "http" "myip"`, so the
// deployer's public IP must be supplied via `deployerIp`. Grab it with
// `curl -s https://api.ipify.org` (or your CI's egress-IP mechanism).
// ============================================================================

targetScope = 'resourceGroup'

// ----------------------------------------------------------------------------
// Parameters
// ----------------------------------------------------------------------------

@description('Short project identifier used as a prefix for derived names. Must match the base stack.')
param baseName string = 'playground'

@description('Environment suffix (e.g. dev / prod). Must match the base stack.')
param environment string = 'dev'

@description('Azure region for the workload. Must match the base stack; default eastus2 supports Foundry Agent Service private networking.')
param location string = 'eastus2'

// --- Name overrides (blank = derive from baseName/environment/location) ---

@description('VNet name. Blank = convention.')
param vnetName string = ''

@description('Cognitive-PE subnet name. Blank = convention.')
param subnetNameCognitivePep string = ''

@description('Storage-PE subnet name. Blank = convention.')
param subnetNameStoragePep string = ''

@description('Cosmos-PE subnet name. Blank = convention.')
param subnetNameCosmosPep string = ''

@description('Search-PE subnet name. Blank = convention.')
param subnetNameSearchPep string = ''

@description('Agent (delegated) subnet name. Blank = convention.')
param subnetNameAgent string = ''

@description('Custom subdomain for the Foundry / Cognitive AIServices account. This is NOT the account resource name -- the account is always ais-<baseName>-<environment>-<location>. Blank = convention (cog-acc-...).')
param cognitiveCustomSubdomainName string = ''

// --- DNS zone name overrides (defaults are the required Standard Setup set) ---

@description('The 3 private DNS zones the Foundry account\'s `account` sub-resource resolves through. If you override, you must supply EXACTLY 3 zone names in the same order (cognitiveservices, openai, services.ai).')
@minLength(3)
@maxLength(3)
param cognitivePrivateDnsZoneNames array = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]

@description('The 6 private DNS zones the Storage account\'s private endpoints resolve through (one per subresource, in order: blob/file/queue/table/dfs/web). If you override, you must supply EXACTLY 6 zone names in that order.')
@minLength(6)
@maxLength(6)
param storagePrivateDnsZoneNames array = [
  'privatelink.blob.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.web.core.windows.net'
]

@description('Cosmos SQL DNS zone. Default: privatelink.documents.azure.com.')
param cosmosPrivateDnsZoneName string = 'privatelink.documents.azure.com'

@description('AI Search DNS zone. Default: privatelink.search.windows.net.')
param searchPrivateDnsZoneName string = 'privatelink.search.windows.net'

// --- Public-endpoint / IP-allowlist controls ---

@description('Master switch for the public endpoint on every workload data-plane service (Storage, Cosmos, AI Search, Foundry). When true (default) the services are reachable via their public FQDN, filtered by the IP allowlist (deployerIp + allowedIpsExtra). When false the public endpoint is disabled entirely on all 4 services -- only VNet-injected agent runtime traffic can reach them via private endpoints. Flip to false to harden the deployment once you\'re done making changes; flip back to true before your next apply that touches Cosmos SQL role assignments or Foundry capability hosts (both of which use the data plane).')
param enablePublicNetworkAccess bool = true

@description('Public IPv4 of the machine running the deployment. Bare IPv4 or CIDR /0-/30. Do NOT pass /31 or /32 -- Cognitive Services rejects them; use the bare IP. Pass "" (empty) to skip adding the deployer IP -- useful for CI runs and the hardening step.')
param deployerIp string

@description('Additional IPv4 or CIDR entries allowlisted on every workload service (teammates, office ranges, CI runner). Same format rules as deployerIp.')
param allowedIpsExtra array = []

@description('Tags applied to every workload resource.')
param tags object = {
  environment: 'dev'
  workload: 'ai-foundry'
  stack: 'workload'
  managed_by: 'bicep'
}

// ----------------------------------------------------------------------------
// Locals
// ----------------------------------------------------------------------------

var effectiveVnetName = empty(vnetName) ? 'vnet-${baseName}-${environment}-${location}' : vnetName
var effectiveCognitiveSubnetName = empty(subnetNameCognitivePep) ? 'snet-cognitive-${baseName}-${environment}' : subnetNameCognitivePep
var effectiveStorageSubnetName   = empty(subnetNameStoragePep)   ? 'snet-storage-${baseName}-${environment}'   : subnetNameStoragePep
var effectiveCosmosSubnetName    = empty(subnetNameCosmosPep)    ? 'snet-cosmos-${baseName}-${environment}'    : subnetNameCosmosPep
var effectiveSearchSubnetName    = empty(subnetNameSearchPep)    ? 'snet-search-${baseName}-${environment}'    : subnetNameSearchPep
var effectiveAgentSubnetName     = empty(subnetNameAgent)        ? 'snet-agent-${baseName}-${environment}'     : subnetNameAgent
var effectiveCognitiveSubdomain  = empty(cognitiveCustomSubdomainName) ? 'cog-acc-${baseName}-${environment}-${location}' : cognitiveCustomSubdomainName

// DNS zone params default to the full required set, and length is locked to
// exactly 3/6 by @minLength/@maxLength decorators, so we can use the param
// values directly without an "empty -> defaults" fallback.

// Empty deployerIp would silently pass through as "" into the firewall ipRules
// and be rejected late (or worse, deploy silently with no allowlist). Guard
// the union to omit empty deployerIp; if BOTH deployerIp and allowedIpsExtra
// are empty, the resulting allowedIps=[] with default-deny will lock everyone
// out -- which is a safer failure mode than accidentally allowlisting nothing
// while claiming to allowlist the deployer.
var allowedIps = union(empty(deployerIp) ? [] : [deployerIp], allowedIpsExtra)

// ----------------------------------------------------------------------------
// Existing base-stack resources (looked up by name; created by base main.bicep).
// ----------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: effectiveVnetName
}

resource snetCognitive 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: effectiveCognitiveSubnetName
}
resource snetStorage 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: effectiveStorageSubnetName
}
resource snetCosmos 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: effectiveCosmosSubnetName
}
resource snetSearch 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: effectiveSearchSubnetName
}
resource snetAgent 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: effectiveAgentSubnetName
}

resource cognitiveZones 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [for zone in cognitivePrivateDnsZoneNames: {
  name: zone
}]
resource storageZones 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [for zone in storagePrivateDnsZoneNames: {
  name: zone
}]
resource cosmosZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: cosmosPrivateDnsZoneName
}
resource searchZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: searchPrivateDnsZoneName
}

// ----------------------------------------------------------------------------
// Data-plane services (all with IP allowlist + private endpoint).
// ----------------------------------------------------------------------------

module storage '../../../../iac-modules/bicep/storage_account/v1/storage_account.bicep' = {
  name: 'deploy-storage'
  params: {
    baseName: baseName
    environment: environment
    location: location
    tags: tags

    publicNetworkAccessEnabled: enablePublicNetworkAccess
    networkRulesDefaultAction: 'Deny'
    allowedIps: allowedIps

    subnetId: snetStorage.id

    blobPrivateDnsZoneIds:  [storageZones[0].id]
    filePrivateDnsZoneIds:  [storageZones[1].id]
    queuePrivateDnsZoneIds: [storageZones[2].id]
    tablePrivateDnsZoneIds: [storageZones[3].id]
    dfsPrivateDnsZoneIds:   [storageZones[4].id]
    webPrivateDnsZoneIds:   [storageZones[5].id]
  }
}

module cosmos '../../../../iac-modules/bicep/cosmos_db/v1/cosmos_db.bicep' = {
  name: 'deploy-cosmos'
  params: {
    baseName: baseName
    environment: environment
    location: location
    tags: tags

    publicNetworkAccessEnabled: enablePublicNetworkAccess
    ipRangeFilter: allowedIps

    subnetId: snetCosmos.id
    privateDnsZoneIds: [cosmosZone.id]
  }
}

module search '../../../../iac-modules/bicep/ai_search/v1/ai_search.bicep' = {
  name: 'deploy-search'
  params: {
    baseName: baseName
    environment: environment
    location: location
    tags: tags

    sku: 'basic'
    publicNetworkAccessEnabled: enablePublicNetworkAccess
    allowedIps: allowedIps

    subnetId: snetSearch.id
    privateDnsZoneIds: [searchZone.id]
  }
}

// ----------------------------------------------------------------------------
// Foundry account (Cognitive AIServices) + agent-subnet network injection.
// ----------------------------------------------------------------------------

module cognitive '../../../../iac-modules/bicep/cognitive_account/v1/cognitive_account.bicep' = {
  name: 'deploy-cognitive'
  params: {
    baseName: baseName
    environment: environment
    location: location
    tags: tags

    kind: 'AIServices'
    skuName: 'S0'
    customSubdomainName: effectiveCognitiveSubdomain
    projectManagementEnabled: true

    publicNetworkAccessEnabled: enablePublicNetworkAccess
    networkAclsDefaultAction: 'Deny'
    networkAclsBypass: 'AzureServices'
    networkAclsIpRules: allowedIps

    subnetId: snetCognitive.id
    privateDnsZoneIds: [for i in range(0, length(cognitivePrivateDnsZoneNames)): cognitiveZones[i].id]

    agentSubnetId: snetAgent.id
  }
}

// ----------------------------------------------------------------------------
// Foundry project + BYO connections + RBAC + capability hosts.
// ----------------------------------------------------------------------------

module foundryProject '../../../../iac-modules/bicep/foundry_project/v1/foundry_project.bicep' = {
  name: 'deploy-foundry-project'
  params: {
    baseName: baseName
    environment: environment
    location: location
    tags: tags

    cognitiveAccountName: cognitive.outputs.name

    storageAccountName: storage.outputs.name
    storageBlobEndpoint: storage.outputs.blobEndpoint

    cosmosAccountName: cosmos.outputs.name
    cosmosDbDocumentEndpoint: cosmos.outputs.documentEndpoint

    aiSearchName: search.outputs.name
    aiSearchEndpoint: search.outputs.endpoint

    enableCapabilityHost: true
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output storageAccountName string = storage.outputs.name
output cosmosAccountName string = cosmos.outputs.name
output aiSearchName string = search.outputs.name
output cognitiveAccountName string = cognitive.outputs.name
output foundryProjectEndpoint string = foundryProject.outputs.foundryProjectEndpoint
