//****************************************************************************************
// Parameters
//****************************************************************************************

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
param resourceToken string

//****************************************************************************************
// Variables
//****************************************************************************************

var logAnalyticsName = 'log-${resourceToken}'
var applicationInsightsName = 'appi-${resourceToken}'


//**********************************************************************************************
// Log Analytics, Application Insights and RBAC
//**********************************************************************************************

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
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
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableLocalAuth: true
  }
}

//****************************************************************************************
// RBAC role assignments for the user assigned identity.
//****************************************************************************************

resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, userAssignedIdentityId, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
