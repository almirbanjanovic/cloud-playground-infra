// ============================================================================
// Cognitive Services / AI Foundry account — v1
//
// AIServices-kind Cognitive account with project management enabled, MI,
// optional agent-subnet network injection, IP allowlist on the public
// endpoint, and one private endpoint for the `account` subresource.
// Mirrors the Terraform cognitive_account/v1 module for AI Foundry workload.
// ============================================================================

@description('Short project identifier.')
param baseName string

@description('Environment suffix.')
param environment string

@description('Azure location.')
param location string = resourceGroup().location

@description('Cognitive Services kind. Use "AIServices" for AI Foundry.')
param kind string = 'AIServices'

@description('SKU name.')
param skuName string = 'S0'

@description('Custom subdomain / privatelink hostname prefix for the account. Required for Entra ID / MI auth and for a PE to be attachable.')
param customSubdomainName string

@description('Enable Foundry project management on the account.')
param projectManagementEnabled bool = true

@description('Enable public network access. Combine with networkAclsDefaultAction=Deny + networkAclsIpRules for the deployer-IP allowlist pattern.')
param publicNetworkAccessEnabled bool = true

@description('Default action for network ACLs on the public endpoint.')
@allowed(['Allow', 'Deny'])
param networkAclsDefaultAction string = 'Deny'

@description('Bypass setting for network ACLs. Foundry needs AzureServices bypass so Microsoft-managed control-plane can reach the account.')
@allowed(['AzureServices', 'None'])
param networkAclsBypass string = 'AzureServices'

@description('IPv4 addresses allowed on the public endpoint. Bare IPs only -- Cognitive Services rejects /31 and /32 CIDR notation.')
param networkAclsIpRules array = []

@description('Enable local (key) auth. Defaults to false.')
param localAuthEnabled bool = false

@description('Subnet ID where the account PE lives.')
param subnetId string

@description('Private DNS zone IDs for the "account" subresource PE (3 zones: cognitiveservices, openai, services.ai).')
param privateDnsZoneIds array

@description('Optional subnet ID for Foundry Agent Service network injection. When set, agent-runtime compute is injected into this subnet. Must be delegated to Microsoft.App/environments.')
param agentSubnetId string = ''

@description('Tags applied to the account and PE.')
param tags object = {}

// ------------------------------------------------------------------
// Cognitive account
// ------------------------------------------------------------------

var accountName = toLower('ais-${baseName}-${environment}-${location}')

// Pre-computed IP-rule set (avoids BCP138 -- can't nest for-expressions inside union()).
var cognitiveIpRules = [for ip in networkAclsIpRules: {
  value: ip
}]

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  tags: tags
  kind: kind
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: union({
    customSubDomainName: customSubdomainName
    allowProjectManagement: projectManagementEnabled
    disableLocalAuth: !localAuthEnabled
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: networkAclsDefaultAction
      bypass: networkAclsBypass
      ipRules: cognitiveIpRules
      virtualNetworkRules: []
    }
  }, empty(agentSubnetId) ? {} : {
    // Foundry Agent Service network injection into the caller's VNet.
    // Emit `networkInjections` ONLY when agentSubnetId is provided; some ARM
    // RPs reject `null` on optional array properties.
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetId
        useMicrosoftManagedNetwork: false
      }
    ]
  })
}

// ------------------------------------------------------------------
// Private endpoint (account subresource)
// ------------------------------------------------------------------

module pe '../../private_endpoint/v1/private_endpoint.bicep' = {
  name: take('pe-${accountName}', 64)
  params: {
    name: 'pe-${accountName}'
    location: location
    targetResourceId: account.id
    subresourceNames: ['account']
    subnetId: subnetId
    privateDnsZoneIds: privateDnsZoneIds
    tags: tags
  }
}

output id string = account.id
output name string = account.name
output endpoint string = account.properties.endpoint
output principalId string = account.identity.principalId
