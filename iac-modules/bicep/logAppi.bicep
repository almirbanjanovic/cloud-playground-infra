/* This Bicep file creates a function app running in a Flex Consumption plan 
that connects to Azure Storage by using managed identities with Microsoft Entra ID. */

//********************************************
// Parameters
//********************************************

@description('Primary region for all Azure resources.')
@minLength(1)
param location string

@description('User assigned identity resource ID to be used for RBAC')
@minLength(1)
param userAssignedIdentityId string

@description('User assigned identity principal ID to be used for RBAC')
@minLength(1)
param userAssignedIdentityPrincipalId string

@description('Monitoring role definition ID to be assigned to the user assigned identity')
@minLength(1)
param monitoringMetricsPublisherId string


@description('A unique token used for resource name generation.')
@minLength(1)
param resourceToken string = toLower(uniqueString(subscription().id, location))

//********************************************
// Variables
//********************************************


//********************************************
// Azure resources required by your function app.
//********************************************

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${resourceToken}'
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableLocalAuth: true
  }
}

resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, userAssignedIdentityId, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
