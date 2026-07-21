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

@description('Short project identifier (e.g. "playground").')
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
  storageBlobDataOwner         : 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
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
  name: guid(storageAccount.id, project.id, roleIds.storageBlobDataOwner)
  scope: storageAccount
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageBlobDataOwner)
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
// RBAC-propagation sleep (Bicep equivalent of Terraform's `time_sleep`).
//
// Entra ID typically takes 30-60 seconds to replicate a new role assignment
// out to the data-plane services that need to enforce it. Without a wait,
// the capability host below almost always 403s on first apply. We use a
// short deployment script (Azure Container Instances behind the scenes) as
// the only bicep-native way to introduce a delay in the dependency graph.
//
// The script:
//   - Runs a Linux container that does `sleep 60` and exits 0.
//   - `retentionInterval: PT1H` keeps ARM cleaning up the ACI within an hour.
//   - `forceUpdateTag` uses `utcNow()` so the script re-runs on every deploy
//     (deploymentScripts are idempotent by name; without the tag change ARM
//     would skip re-execution on the second apply, which is fine).
//   - Ordering: dependsOn every role assignment above so the sleep starts
//     ONLY once all assignments are created. Capability hosts below dependOn
//     this script so they wait for both.
// ----------------------------------------------------------------------------

param rbacPropagationScriptForceUpdateTag string = utcNow()

resource rbacPropagationSleep 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (enableCapabilityHost) {
  name: 'sleep-rbac-propagation-${effectiveProjectName}'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.60.0'
    scriptContent: 'echo "Waiting 60s for RBAC propagation before creating Foundry capability hosts"; sleep 60'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT10M'
    forceUpdateTag: rbacPropagationScriptForceUpdateTag
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
// 5. Capability hosts (account + project).
//
// Account host: marker record; lights up Agent Service for the account.
// Project host: binds this project's agents to the 3 BYO connections above.
// Immutable -- to change connections, delete and recreate. `dependsOn`
// chains ensure all RBAC is created before the capability hosts try to
// provision the backing containers/databases.
// ----------------------------------------------------------------------------

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = if (enableCapabilityHost) {
  parent: cognitiveAccount
  name: 'default'
  properties: {
    capabilityHostKind: 'Agents'
  }
  dependsOn: [
    rbacPropagationSleep
  ]
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = if (enableCapabilityHost) {
  parent: project
  name: 'default'
  properties: {
    // Project-scoped host binds the 3 BYO connections created above by name.
    // References to connStorage/connCosmos/connSearch make bicep infer the
    // dependsOn ordering automatically -- no explicit dependsOn needed.
    storageConnections: [connStorage.name]
    threadStorageConnections: [connCosmos.name]
    vectorStoreConnections: [connSearch.name]
  }
  dependsOn: [
    accountCapabilityHost
  ]
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output projectId string = project.id
output projectName string = project.name
output projectPrincipalId string = project.identity.principalId
output foundryProjectEndpoint string = 'https://${cognitiveAccount.name}.services.ai.azure.com/api/projects/${project.name}'
