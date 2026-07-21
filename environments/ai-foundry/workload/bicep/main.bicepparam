using 'main.bicep'

// deployerIp is REQUIRED for FIRST deploy and any deploy that touches Cosmos
// SQL role assignments or Foundry capability hosts (both use the data plane
// and respect the IP allowlist). This bicepparam reads it from the DEPLOYER_IP
// environment variable. Set it before deploying:
//
//   $env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
//
// Then deploy:
//   az deployment group create -g rg-ai-foundry-dev-eastus2 -f main.bicep -p main.bicepparam
//
// For the HARDENING step (README Part C), pass overrides on the CLI:
//   az deployment group create ... -p deployerIp='' -p enablePublicNetworkAccess=false
param deployerIp = readEnvironmentVariable('DEPLOYER_IP', '')

// Optional overrides:
// param enablePublicNetworkAccess = true   // set to false to harden (see README Part C)
// param baseName    = 'ai-foundry'
// param environment = 'dev'
// param location    = 'eastus2'
// param allowedIpsExtra = [
//   '198.51.100.0/24'
//   '203.0.113.99'
// ]

// Individual name overrides (blank = derive from baseName/environment/location):
// param vnetName                     = 'vnet-mycompany-shared-eastus2'
// param subnetNameCognitivePep       = 'snet-mycompany-cognitive-pe'
// param subnetNameStoragePep         = 'snet-mycompany-storage-pe'
// param subnetNameCosmosPep          = 'snet-mycompany-cosmos-pe'
// param subnetNameSearchPep          = 'snet-mycompany-search-pe'
// param subnetNameAgent              = 'snet-mycompany-foundry-agent'
// param cognitiveCustomSubdomainName = 'cog-acc-mycompany-shared'

// Private DNS zone overrides -- MUST supply exactly 3 (cognitive) and 6 (storage)
// entries in the documented order; @minLength/@maxLength decorators enforce this
// at deploy time. Defaults are the required Standard Setup set.
// param cognitivePrivateDnsZoneNames = [
//   'privatelink.cognitiveservices.azure.com'
//   'privatelink.openai.azure.com'
//   'privatelink.services.ai.azure.com'
// ]
// param storagePrivateDnsZoneNames   = [
//   'privatelink.blob.core.windows.net'
//   'privatelink.file.core.windows.net'
//   'privatelink.queue.core.windows.net'
//   'privatelink.table.core.windows.net'
//   'privatelink.dfs.core.windows.net'
//   'privatelink.web.core.windows.net'
// ]
// param cosmosPrivateDnsZoneName = 'privatelink.documents.azure.com'
// param searchPrivateDnsZoneName = 'privatelink.search.windows.net'
