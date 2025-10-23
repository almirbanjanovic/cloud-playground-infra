//********************************************
// Parameters
//********************************************

@description('Primary region for all Azure resources.')
@minLength(1)
param location string = resourceGroup().location 

@description('Language runtime used by the function app.')
@allowed(['dotnet-isolated','python','java', 'node', 'powerShell'])
param functionAppRuntime string = 'dotnet-isolated' //Defaults to .NET isolated worker

@description('Target language version used by the function app.')
@allowed(['3.10','3.11', '7.4', '8.0', '9.0', '10', '11', '17', '20'])
param functionAppRuntimeVersion string = '8.0' //Defaults to .NET 8.

@description('The maximum scale-out instance count limit for the app.')
@minValue(40)
@maxValue(1000)
param maximumInstanceCount int = 100

@description('The memory size of instances used by the app.')
@allowed([2048,4096])
param instanceMemoryMB int = 2048

@description('A unique token used for resource name generation.')
@minLength(3)
param resourceToken string = toLower(uniqueString(subscription().id, location))

//********************************************
// Variables
//********************************************

// Define the IDs of the roles we need to assign to our managed identities.
var storageBlobDataOwnerRoleId  = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageQueueDataContributorId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var storageTableDataContributorId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'

//********************************************
// Azure resources required by your function app.
//********************************************


resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uai-data-owner-${resourceToken}'
  location: location
}


module logAppi '../../../iac-modules/bicep/logAppi/v1/logAppi.bicep' = {
  name: 'deploy-log-appi'
  params: {
    location: location
    userAssignedIdentityId: userAssignedIdentity.id
    userAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
    monitoringMetricsPublisherId: monitoringMetricsPublisherId
    resourceToken: resourceToken
  }
}

module functionApp '../../../iac-modules/bicep/function/v1/function.bicep' = {
  name: 'deploy-function-app'
  params: {
    location: location
    instanceMemoryMB: instanceMemoryMB
    maximumInstanceCount: maximumInstanceCount
    functionAppRuntime: functionAppRuntime
    functionAppRuntimeVersion: functionAppRuntimeVersion
    resourceToken: resourceToken
    userAssignedIdentityId: userAssignedIdentity.id
    userAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
    userAssignedIdentityClientId: userAssignedIdentity.properties.clientId
    applicationInsightsInstrumentationKey: logAppi.outputs.applicationInsightsInstrumentationKey
    storageBlobDataOwnerRoleId: storageBlobDataOwnerRoleId
    storageBlobDataContributorRoleId: storageBlobDataContributorRoleId
    storageQueueDataContributorId: storageQueueDataContributorId
    storageTableDataContributorId: storageTableDataContributorId
  }
}

module apim '../../../iac-modules/bicep/apim/v1/apim.bicep' = {
  name: 'deploy-apim'
  params: {
    location: location
    resourceToken: resourceToken
  }
  dependsOn: [
    functionApp
  ]
}
