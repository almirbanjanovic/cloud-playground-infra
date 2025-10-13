# APIM MCP Environment

This environment demonstrates Azure API Management (APIM) integration with Model Context Protocol (MCP) APIs, specifically using a Colors API as an example.

## Overview

This setup provisions an Azure API Management instance and configures it to expose the Colors API through APIM. The Colors API is an MCP server that provides color data and demonstrates how MCP servers can be integrated with Azure API Management for enterprise-grade API governance.

## Architecture

The environment includes:

- **Azure API Management (BasicV2)**: Acts as an API gateway, providing security, rate limiting, analytics, and monitoring
- **Colors API Backend**: An MCP-based API service that provides color data operations
- **OpenAPI Integration**: Automatic API definition import from the backend Swagger specification

## Resources Deployed

### API Management Instance

- **SKU**: BasicV2 (1 unit)
- **Location**: Central US
- **Publisher**: MCP
- **Base Name**: mcp-dev

### Colors API

- **Display Name**: Colors API
- **Path**: `/colors`
- **Protocol**: HTTPS only
- **Backend URL**: `https://colors-api.azurewebsites.net/`
- **API Definition**: Imported from OpenAPI/Swagger specification

## Usage

Once deployed, the Colors API is accessible through APIM as an MCP server in Visual Studio Code with GitHub Copilot.

### MCP Integration

To use this API through MCP, configure your `.vscode/mcp.json` file with the appropriate APIM subscription key. Once configured, GitHub Copilot can interact with the Colors API directly through the MCP protocol.

Example `mcp.json` configuration:

```json
{
    "servers": {
        "colors-mcp-server": {
            "url": "https://apim-mcp-dev-centralus.azure-api.net/colors-mcp/mcp",
            "type": "http",
            "headers": {
                "Ocp-Apim-Subscription-Key": "your-subscription-key-here",
                "Ocp-Apim-Trace": "true"
            }
        }
    },
    "inputs": []
}
```

With this configuration, you can ask GitHub Copilot to interact with the Colors API, such as "get all colors" or "show me the available colors", and it will use the MCP server through APIM.

## Testing with APIM Features

### Test Rate Limiting

APIM allows you to configure rate limiting policies to protect your backend:

```xml
<policies>
    <inbound>
        <rate-limit calls="10" renewal-period="60" />
    </inbound>
</policies>
```

### Test Transformation

You can transform responses using APIM policies:

```xml
<policies>
    <outbound>
        <set-header name="X-Powered-By" exists-action="override">
            <value>Azure APIM</value>
        </set-header>
    </outbound>
</policies>
```

## APIM Developer Portal

After deployment, access the developer portal at:

```text
https://mcp-dev-apim.developer.azure-api.net
```

The developer portal provides:

- Interactive API documentation
- API testing console
- Subscription key management
- Analytics and usage metrics

## Related Environments

- [apim-lab](../apim-lab/README.md): General APIM learning environment with detailed concepts and examples

## References

- [Azure API Management Documentation](https://learn.microsoft.com/en-us/azure/api-management/)
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [APIM Policies Reference](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
- [APIM Best Practices](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-deploy-multi-region)

## Notes

- The BasicV2 SKU is suitable for development and testing workloads
- For production scenarios, consider using Standard or Premium SKUs for enhanced features like VNet integration, multi-region deployment, and higher SLA
- The Colors API backend is publicly accessible; in production scenarios, implement proper authentication and network security
