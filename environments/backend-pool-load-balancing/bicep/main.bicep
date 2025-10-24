// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = [
  {
    name: 'foundry1'
    location: 'eastus'
    priority: 1
  }
  {
    name: 'foundry2'
    location: 'swedencentral'
    priority: 2
    weight: 50
  }
  {
    name: 'foundry3'
    location: 'westus'
    priority: 2
    weight: 50
  }
]

param modelsConfig array = [
  {
    name: 'gpt-4o-mini'
    publisher: 'OpenAI'
    version: '2024-07-18'
    sku: 'GlobalStandard'
    capacity: 1
  }
]

param apimSku string = 'Basicv2'
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param foundryProjectName string = 'default'

// ------------------
//    RESOURCES
// ------------------

// 1. API Management
module apimModule '../../../iac-modules/bicep/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
  }
}

// 2. AI Foundry
module foundryModule '../../../iac-modules/bicep/cognitive-services/v3/foundry.bicep' = {
    name: 'foundryModule'
    params: {
      aiServicesConfig: aiServicesConfig
      modelsConfig: modelsConfig
      apimPrincipalId: apimModule.outputs.principalId
      foundryProjectName: foundryProjectName
    }
  }

// 3. APIM Inference API
module inferenceAPIModule '../../../iac-modules/bicep/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('../policy.xml')
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
    configureCircuitBreaker: true
  }
}


// ------------------
//    OUTPUTS
// ------------------

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions
