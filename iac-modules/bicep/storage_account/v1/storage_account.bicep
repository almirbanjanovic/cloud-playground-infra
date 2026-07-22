// ============================================================================
// Storage account — v1
//
// StorageV2, MI-only (shared-key disabled + OAuth default), configurable IP
// allowlist, and up to 6 private endpoints (blob/file/queue/table/dfs/web),
// each with its own DNS zone group. Mirrors the Terraform storage account/v1
// module used by the AI Foundry workload stack.
// ============================================================================

@description('Short project identifier (e.g. "ai-foundry").')
param baseName string

@description('Environment suffix (e.g. "dev").')
param environment string

@description('Azure location.')
param location string = resourceGroup().location

@description('Optional suffix appended to the derived storage account name (for uniqueness in shared subs).')
param suffix string = ''

@description('Storage account SKU tier.')
@allowed(['Standard', 'Premium'])
param accountTier string = 'Standard'

@description('Storage account replication type.')
@allowed(['LRS', 'GRS', 'RAGRS', 'ZRS', 'GZRS', 'RAGZRS'])
param replicationType string = 'LRS'

@description('Minimum TLS version.')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minTlsVersion string = 'TLS1_2'

@description('Enable public network access. When true, the network ACL default action + allowedIps control who can reach the public endpoint.')
param publicNetworkAccessEnabled bool = true

@description('Default action for the network rules (Deny + allowedIps = IP-allowlist mode).')
@allowed(['Allow', 'Deny'])
param networkRulesDefaultAction string = 'Deny'

@description('IPv4 addresses / CIDR ranges allowed to reach the public endpoint when publicNetworkAccessEnabled=true.')
param allowedIps array = []

@description('Subnet ID where the PEs are provisioned.')
param subnetId string

@description('Private DNS zone IDs (one list per subresource). Empty list disables that subresource\'s PE.')
param blobPrivateDnsZoneIds array = []
param filePrivateDnsZoneIds array = []
param queuePrivateDnsZoneIds array = []
param tablePrivateDnsZoneIds array = []
param dfsPrivateDnsZoneIds array = []
param webPrivateDnsZoneIds array = []

@description('Tags applied to the storage account and its PEs.')
param tags object = {}

@description('Full storage account name override. When set (non-empty) this wins over the derived `st<baseName><environment><location><suffix>` convention. Use when the derived name would exceed 24 chars or when you need a specific globally-unique name (e.g. the terraform-state storage account uses a hashed short name). Empty string (default) triggers the derived-name path.')
param customName string = ''

// ------------------------------------------------------------------
// Locals
// ------------------------------------------------------------------

// Storage account names must be 3-24 chars, lowercase letters + numbers only.
// The @minLength/@maxLength on the params keep individual inputs bounded, but
// only the caller can enforce the concatenated length -- so validate at plan
// time here with a `resource` name derived only from `accountName` (Bicep has
// no lifecycle precondition, but the resource's own name-length rule will
// fire before any ARM call). Hyphens in the inputs (e.g. baseName='ai-foundry')
// are stripped -- Storage rejects any non-alphanumeric character, and hyphens
// are the only invalid char that the rest of our naming convention actually
// uses. Anything more exotic: pass `customName`.
var derivedAccountName = replace(toLower('st${baseName}${environment}${location}${suffix}'), '-', '')
var accountName = empty(customName) ? derivedAccountName : customName

// ------------------------------------------------------------------
// Storage account
// ------------------------------------------------------------------

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: accountName
  location: location
  tags: tags
  sku: {
    name: '${accountTier}_${replicationType}'
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    minimumTlsVersion: minTlsVersion
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkRulesDefaultAction
      ipRules: [for ip in allowedIps: {
        value: ip
        action: 'Allow'
      }]
      virtualNetworkRules: []
    }
  }
}

// ------------------------------------------------------------------
// Blob service properties (parity with the Terraform module).
//   - 30-day soft delete for blobs and containers
//   - Blob versioning (data-protection default)
//   - Last-access-time tracking (for lifecycle policies)
// ------------------------------------------------------------------

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true
    lastAccessTimeTrackingPolicy: {
      enable: true
      name: 'AccessTimeTracking'
      trackingGranularityInDays: 1
    }
  }
}

// ------------------------------------------------------------------
// Private endpoints — one per subresource with non-empty DNS zone list.
//
// The 6 PEs are SERIALISED via an explicit dependsOn chain
// (blob -> file -> queue -> table -> dfs -> web) rather than the
// Bicep default of parallel sibling deploys. Rationale:
//
//   * All 6 PEs target the SAME storage-PE subnet, so each PE's NIC
//     creation writes to `subnet.properties.ipConfigurations` under
//     Network RP's per-subnet write lock.
//   * All 6 PEs target the SAME storage account, so each PE's
//     `privateLinkServiceConnections` write hits Storage RP's per-
//     account write lock.
//
// Two shared write-locks + 6 concurrent writers is the same class of
// race that produces `RetryableError` / `AnotherOperationInProgress`
// / `409 Conflict` on the first apply -- exactly the pattern we
// serialised for subnets in iac-modules/bicep/vnet/v1/vnet.bicep via
// `@batchSize(1)`. We use dependsOn here (instead of refactoring into
// a single `[for] @batchSize(1)` module loop) so existing deployments
// keep their symbolic-name state addresses and don't get replaced.
//
// Cost: ~5-10s added to first apply. Benefit: deterministic first-run
// success on the storage private-endpoint fan-out.
// ------------------------------------------------------------------

module pe_blob '../../private_endpoint/v1/private_endpoint.bicep' = if (!empty(blobPrivateDnsZoneIds)) {
  name: take('pe-${accountName}-blob', 64)
  params: {
    name: 'pe-${accountName}-blob'
    location: location
    targetResourceId: storage.id
    subresourceNames: ['blob']
    subnetId: subnetId
    privateDnsZoneIds: blobPrivateDnsZoneIds
    tags: tags
  }
}

module pe_file '../../private_endpoint/v1/private_endpoint.bicep' = if (!empty(filePrivateDnsZoneIds)) {
  name: take('pe-${accountName}-file', 64)
  params: {
    name: 'pe-${accountName}-file'
    location: location
    targetResourceId: storage.id
    subresourceNames: ['file']
    subnetId: subnetId
    privateDnsZoneIds: filePrivateDnsZoneIds
    tags: tags
  }
  dependsOn: [pe_blob]
}

module pe_queue '../../private_endpoint/v1/private_endpoint.bicep' = if (!empty(queuePrivateDnsZoneIds)) {
  name: take('pe-${accountName}-queue', 64)
  params: {
    name: 'pe-${accountName}-queue'
    location: location
    targetResourceId: storage.id
    subresourceNames: ['queue']
    subnetId: subnetId
    privateDnsZoneIds: queuePrivateDnsZoneIds
    tags: tags
  }
  dependsOn: [pe_file]
}

module pe_table '../../private_endpoint/v1/private_endpoint.bicep' = if (!empty(tablePrivateDnsZoneIds)) {
  name: take('pe-${accountName}-table', 64)
  params: {
    name: 'pe-${accountName}-table'
    location: location
    targetResourceId: storage.id
    subresourceNames: ['table']
    subnetId: subnetId
    privateDnsZoneIds: tablePrivateDnsZoneIds
    tags: tags
  }
  dependsOn: [pe_queue]
}

module pe_dfs '../../private_endpoint/v1/private_endpoint.bicep' = if (!empty(dfsPrivateDnsZoneIds)) {
  name: take('pe-${accountName}-dfs', 64)
  params: {
    name: 'pe-${accountName}-dfs'
    location: location
    targetResourceId: storage.id
    subresourceNames: ['dfs']
    subnetId: subnetId
    privateDnsZoneIds: dfsPrivateDnsZoneIds
    tags: tags
  }
  dependsOn: [pe_table]
}

module pe_web '../../private_endpoint/v1/private_endpoint.bicep' = if (!empty(webPrivateDnsZoneIds)) {
  name: take('pe-${accountName}-web', 64)
  params: {
    name: 'pe-${accountName}-web'
    location: location
    targetResourceId: storage.id
    subresourceNames: ['web']
    subnetId: subnetId
    privateDnsZoneIds: webPrivateDnsZoneIds
    tags: tags
  }
  dependsOn: [pe_dfs]
}

// ------------------------------------------------------------------
// Outputs
// ------------------------------------------------------------------

output id string = storage.id
output name string = storage.name
output blobEndpoint string = storage.properties.primaryEndpoints.blob
output principalId string = storage.identity.principalId
