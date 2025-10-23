# APIM ❤️ AI Foundry

## [Backend pool Load Balancing lab](backend-pool-load-balancing.ipynb)

[![flow](../../images/backend-pool-load-balancing.gif)](backend-pool-load-balancing.ipynb)

Playground to try the built-in load balancing [backend pool functionality of APIM](https://learn.microsoft.com/azure/api-management/backends?tabs=bicep) to a list of Azure AI Foundry endpoints.
**This is a typical prioritized PTU with fallback consumption scenario**. The lab specifically showcases how a priority 1 (highest) backend is exhausted before gracefully falling back to two equally-weighted priority 2 backends.