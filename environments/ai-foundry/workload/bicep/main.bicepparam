using 'main.bicep'

// deployerIp is REQUIRED for FIRST deploy and any deploy that touches Cosmos
// SQL role assignments or Foundry capability hosts (both use the data plane
// and respect the IP allowlist). This bicepparam reads it from the DEPLOYER_IP
// environment variable. Set it before deploying:
//
//   $env:DEPLOYER_IP = (Invoke-RestMethod https://api.ipify.org).Trim()
//
// Then deploy:
//   az deployment group create -g rg-ai-foundry-workload-dev-westus3 -f main.bicep -p main.bicepparam
//
// For the HARDENING step (README Part C), pass overrides on the CLI:
//   az deployment group create ... -p deployerIp='' -p enablePublicNetworkAccess=false
param deployerIp = readEnvironmentVariable('DEPLOYER_IP', '')

// Optional overrides:
// param enablePublicNetworkAccess = true   // set to false to harden (see README Part C)
// param baseName    = 'ai-foundry'
// param environment = 'dev'
// param location    = 'westus3'
// param allowedIpsExtra = [
//   '198.51.100.0/24'
//   '203.0.113.99'
// ]

// ============================================================================
// BRING YOUR OWN BASE NETWORKING
//
// This workload template looks base resources up by NAME via `existing`
// references -- it does NOT read base's ARM outputs. That means you can point
// it at ANY pre-existing VNet + subnets + private DNS zones (a central platform
// VNet, an ALZ spoke, a prior run with custom names) by uncommenting the
// matching overrides below. All are optional; unset values fall back to the
// base stack's naming convention. Mix and match as needed.
// ============================================================================

// --- 1. Cross-RG lookup (CAF landing-zone pattern) ---
// Point at a base stack in a DIFFERENT RG than the one you deploy this workload
// into. Default in main.bicep is the CAF landing-zone networking RG
// (`rg-ai-foundry-network-dev-westus3`). Override to the workload RG to collapse
// into a single-RG topology, or to another RG name (e.g. a shared platform RG
// owned by a central team).
// param baseResourceGroupName = 'rg-shared-networking-westus3'

// --- 2. Separate DNS zones RG (enterprise CAF pattern) ---
// In classic CAF the private DNS zones for privatelink FQDNs live in a central
// connectivity / hub RG owned by a platform team, DISTINCT from the spoke
// VNet's RG. Set this when your 11 privatelink zones are consolidated there.
// Leave blank ('') to reuse `baseResourceGroupName` (default: base owns both
// the VNet and the DNS zones together). Applies uniformly to all 11 zones.
// param dnsResourceGroupName = 'rg-connectivity-hub-dns'

// --- 3. Individual name overrides (blank = derive from baseName/environment/location) ---
// Use these when base's resources don't follow the `<baseName>-<environment>-
// <location>` convention (e.g. a shared platform VNet).
// param vnetName                     = 'vnet-mycompany-shared-westus3'
// param subnetNameCognitivePep       = 'snet-mycompany-cognitive-pe'
// param subnetNameStoragePep         = 'snet-mycompany-storage-pe'
// param subnetNameCosmosPep          = 'snet-mycompany-cosmos-pe'
// param subnetNameSearchPep          = 'snet-mycompany-search-pe'
// param subnetNameAgent              = 'snet-mycompany-foundry-agent'
// param cognitiveCustomSubdomainName = 'cog-acc-mycompany-shared'

// --- 4. Private DNS zone name overrides ---
// MUST supply exactly 3 (cognitive) and 6 (storage) entries in the documented
// order; @minLength/@maxLength decorators enforce this at deploy time. Defaults
// are the required Standard Setup set for Azure public cloud -- override only
// for sovereign clouds (Gov / China) or when a platform team runs custom
// privatelink zone names.
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
