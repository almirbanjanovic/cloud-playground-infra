//********************************************
// Parameters
//********************************************
@description('A unique token used for resource name generation.')
@minLength(1)
param resourceToken string

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'publisherEmail@ms.io'

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'MS'

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param sku string = 'Developer'

@description('The instance size of this API Management service.')
@allowed([
  0
  1
  2
])
param skuCount int = 1

@description('Location for all resources.')
param location string = resourceGroup().location

//********************************************
// Variables
//********************************************
var apiManagementServiceName = 'apim-${resourceToken}'

//**************************************************
// Log Analytics, Application Insights and RBAC
//**************************************************



resource apiManagementService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}
