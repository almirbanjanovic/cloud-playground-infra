// ============================================================================
// AI Foundry project + BYO connections + RBAC + capability hosts -- v1
//
// Mirrors the Terraform foundry_project/v1 module. Creates:
//   1. Cognitive account project (SystemAssigned MI).
//   2. Three account-scoped Entra-ID connections (storage / cosmos / search).
//   3. Phase-3 + Phase-5 RBAC to the project MI on the BYO services.
//   4. Cosmos SQL data-plane role assignment.
//   5. Account + project capability hosts (Foundry Agent Service Standard Setup).
//
// Bicep has no native "sleep 60s" primitive equivalent to Terraform's
// time_sleep. Ordering relies on `dependsOn` so capability hosts only
// deploy once all role assignments are applied. If the very first apply
// hits a 403 on the capability host (Entra ID role-propagation lag),
// rerun the deployment. It usually clears in one retry.
//
// Bicep `existing` references need compile-time-known names, so callers
// pass the SERVICE NAMES (not just IDs) for the four BYO/parent resources.
// ============================================================================

@description('Short project identifier (e.g. "ai-foundry").')
param baseName string

@description('Environment suffix (e.g. "dev").')
param environment string

@description('Azure location.')
param location string = resourceGroup().location

@description('Optional override for the project name. Default: proj-<baseName>-<environment>-<location>.')
param projectName string = ''

@description('Optional Foundry project display name. Default matches projectName.')
param displayName string = ''

@description('Optional description shown in the Foundry portal.')
param projectDescription string = ''

@description('Name of the parent Cognitive Services / AIServices account (created by cognitive_account module).')
param cognitiveAccountName string

@description('Name of the Storage account backing the project.')
param storageAccountName string

@description('Primary blob endpoint of the storage account (e.g. https://<name>.blob.core.windows.net/).')
param storageBlobEndpoint string

@description('Name of the Cosmos DB account backing the project.')
param cosmosAccountName string

@description('Cosmos DB document endpoint (e.g. https://<name>.documents.azure.com:443/).')
param cosmosDbDocumentEndpoint string

@description('Name of the AI Search service backing the project.')
param aiSearchName string

@description('AI Search endpoint (e.g. https://<name>.search.windows.net).')
param aiSearchEndpoint string

@description('Create the account + project capability hosts (Foundry Agent Service Standard Setup). Set false to defer.')
param enableCapabilityHost bool = true

@description('Tags applied to created resources.')
param tags object = {}

// ----------------------------------------------------------------------------
// Locals
// ----------------------------------------------------------------------------

var derivedProjectName = 'proj-${baseName}-${environment}-${location}'
var effectiveProjectName = empty(projectName) ? derivedProjectName : projectName
var effectiveDisplayName = empty(displayName) ? effectiveProjectName : displayName

// Cosmos SQL built-in "Data Contributor" role definition ID (same across all accounts).
var cosmosBuiltInDataContributorRoleDefinitionId = '00000000-0000-0000-0000-000000000002'

// Azure built-in role definition IDs.
var roleIds = {
  cosmosDbOperator             : '230815da-be43-4aae-9cb4-875f7bd000aa'
  storageAccountContributor    : '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  searchIndexDataContributor   : '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  searchServiceContributor     : '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  storageBlobDataContributor   : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

// ----------------------------------------------------------------------------
// Existing parent + BYO resource references (names required at compile-time).
// ----------------------------------------------------------------------------

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: cognitiveAccountName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
}

// ----------------------------------------------------------------------------
// 1. Project (SystemAssigned MI)
// ----------------------------------------------------------------------------

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: cognitiveAccount
  name: effectiveProjectName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: projectDescription
    displayName: effectiveDisplayName
  }
}

// ----------------------------------------------------------------------------
// 2. Entra-ID connections at the account scope, one per BYO service.
// ----------------------------------------------------------------------------

resource connStorage 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  parent: cognitiveAccount
  name: 'conn-storage'
  properties: {
    authType: 'AAD'
    category: 'AzureStorageAccount'
    target: storageBlobEndpoint
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: storageAccount.id
      Location: location
    }
  }
}

resource connCosmos 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  parent: cognitiveAccount
  name: 'conn-cosmos'
  properties: {
    authType: 'AAD'
    category: 'CosmosDb'
    target: cosmosDbDocumentEndpoint
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: cosmosAccount.id
      Location: location
    }
  }
}

resource connSearch 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  parent: cognitiveAccount
  name: 'conn-aisearch'
  properties: {
    authType: 'AAD'
    category: 'CognitiveSearch'
    target: aiSearchEndpoint
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchService.id
      Location: location
    }
  }
}

// ----------------------------------------------------------------------------
// 3. Phase-3 RBAC (control plane).
// ----------------------------------------------------------------------------

resource raCosmosOperator 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableCapabilityHost) {
  name: guid(cosmosAccount.id, project.id, roleIds.cosmosDbOperator)
  scope: cosmosAccount
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.cosmosDbOperator)
    principalType: 'ServicePrincipal'
  }
}

resource raStorageContrib 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableCapabilityHost) {
  name: guid(storageAccount.id, project.id, roleIds.storageAccountContributor)
  scope: storageAccount
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageAccountContributor)
    principalType: 'ServicePrincipal'
  }
}

// ----------------------------------------------------------------------------
// 4. Phase-5 RBAC (data plane).
// ----------------------------------------------------------------------------

resource raSearchIndex 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableCapabilityHost) {
  name: guid(searchService.id, project.id, roleIds.searchIndexDataContributor)
  scope: searchService
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchIndexDataContributor)
    principalType: 'ServicePrincipal'
  }
}

resource raSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableCapabilityHost) {
  name: guid(searchService.id, project.id, roleIds.searchServiceContributor)
  scope: searchService
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchServiceContributor)
    principalType: 'ServicePrincipal'
  }
}

resource raStorageBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableCapabilityHost) {
  name: guid(storageAccount.id, project.id, roleIds.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageBlobDataContributor)
    principalType: 'ServicePrincipal'
  }
}

// Cosmos DB data-plane RBAC (SQL role assignment -- Cosmos has its own RBAC).
resource cosmosDataRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = if (enableCapabilityHost) {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, project.id, cosmosBuiltInDataContributorRoleDefinitionId)
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosBuiltInDataContributorRoleDefinitionId}'
    scope: cosmosAccount.id
  }
}

// ----------------------------------------------------------------------------
// RBAC-propagation ordering.
//
// Entra ID typically takes 30-60 seconds to replicate a new role assignment
// out to the data-plane services that need to enforce it. Without a wait,
// the project capability host below can 403 on first apply when it tries
// to provision the backing DB / blob containers via the newly-assigned
// project MI.
//
// We used to insert a `Microsoft.Resources/deploymentScripts` (Azure
// Container Instance running `sleep 60`) here to force a delay in the
// dependency graph -- Bicep's only native "wait" primitive. That approach
// is fundamentally incompatible with Azure Policies that enforce
// `allowSharedKeyAccess = false` on all storage accounts: the
// deploymentScripts service authenticates to its own auto-provisioned SA
// with shared-key auth ONLY, so under such a policy every apply fails
// with `KeyBasedAuthenticationNotPermitted`. Since the ai-foundry lab
// creates its BYO Storage account with shared-key disabled (and the same
// policy usually applies at subscription scope), we cannot use
// deploymentScripts here.
//
// Instead we rely purely on ARM's `dependsOn` chain: capability hosts
// wait for every role assignment to be CREATED (which is what ARM tracks
// -- not "propagated"). The lag between "created" and "usable at the
// data plane" is what causes the occasional first-apply 403. Recovery
// is trivial: `az deployment group create ...` a second time; the whole
// deploy is idempotent, everything else is a no-op, and the capability
// host retry succeeds because RBAC has finished propagating during the
// interval. Terraform's `time_sleep` avoids this by living entirely
// client-side (no Azure resources), which is why the Terraform path
// still keeps its 60s sleep.
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// 5. Project capability host.
//
// Foundry Agent Service Standard Setup has two capability hosts:
//
//   1. Account-scoped host (Microsoft.CognitiveServices/accounts/capabilityHosts).
//      NOT created by this module -- the platform provisions it IMPLICITLY when
//      the parent Cognitive account is created with
//      `networkInjections.scenario='agent'` (see cognitive_account module).
//      Only ONE account-scoped capability host per account is allowed, and
//      trying to create a second one explicitly fails with
//      `The customerSubnet property must match the subnet recorded on the
//      Foundry account.` See Microsoft's official Standard Agent Setup
//      sample (`15-private-network-standard-agent-setup`): its `main.bicep`
//      skips creating an account host for fresh deployments for exactly this
//      reason.
//
//   2. Project-scoped host (Microsoft.CognitiveServices/accounts/projects/capabilityHosts)
//      -- created here. Binds this project's agents to the 3 BYO connections.
//      Also needs a `customerSubnet` that MATCHES the subnet the account was
//      injected into (that's what ARM validates in the error above).
//
// Immutable -- to change connections, delete and recreate. `dependsOn` chains
// ensure all RBAC is created before the capability host tries to provision
// the backing containers/databases.
// ----------------------------------------------------------------------------

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-10-01-preview' = if (enableCapabilityHost) {
  parent: project
  name: 'default'
  properties: {
    // Project-scoped host binds the 3 BYO connections created above by name.
    // References to connStorage/connCosmos/connSearch make bicep infer the
    // dependsOn ordering automatically -- no explicit dependsOn needed.
    storageConnections: [connStorage.name]
    threadStorageConnections: [connCosmos.name]
    vectorStoreConnections: [connSearch.name]
    // NOTE: `customerSubnet` is NOT a valid property on the PROJECT capability
    // host schema. The subnet is recorded on the parent Cognitive account via
    // `networkInjections.scenario='agent'`, and the platform-provisioned
    // account capability host wraps it. The project host inherits the
    // account's subnet -- no explicit reference needed here.
  }
  dependsOn: [
    raCosmosOperator
    raStorageContrib
    raSearchIndex
    raSearchService
    raStorageBlob
    cosmosDataRole
  ]
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output projectId string = project.id
output projectName string = project.name
output projectPrincipalId string = project.identity.principalId
output foundryProjectEndpoint string = 'https://${cognitiveAccount.name}.services.ai.azure.com/api/projects/${project.name}'
