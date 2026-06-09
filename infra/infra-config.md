# Azure Resources Config

## Environment Info

| Property | Value |
|----------|-------|
| Subscription ID | `0dc80431-5546-4681-a92a-2a799ade5139` |
| Resource Group | `rg-contosouniversity` |
| Location | `centralus` |

## Resource List

| Resource Type | Name | Region | Config Details |
|---------------|------|---------|----------------|
| User-Assigned Managed Identity | `azid3lp24kcvthyga` | centralus | clientId: `7e6223da-2364-41ae-ab88-59232bad4a8e`; principalId: `ebbd4910-c97b-4fcf-acf1-81177e3d05a7` |
| Log Analytics Workspace | `azlog3lp24kcvthyga` | centralus | workspaceId: used by Container Apps environment for log aggregation |
| Azure Container Registry | `azacr3lp24kcvthyga` | centralus | loginServer: `azacr3lp24kcvthyga.azurecr.io`; SKU: Basic |
| Azure SQL Server | `azsql3lp24kcvthyga` | centralus | FQDN: `azsql3lp24kcvthyga.database.windows.net`; TLS: 1.2 |
| Azure SQL Database | `ContosoUniversity` | centralus | Server: `azsql3lp24kcvthyga`; SKU: Serverless GP_S_Gen5; MI user: `azid3lp24kcvthyga` |
| Azure Service Bus Namespace | `azsb3lp24kcvthyga` | centralus | FQDN: `azsb3lp24kcvthyga.servicebus.windows.net`; SKU: Standard |
| Azure Service Bus Queue | `contoso-notifications` | centralus | Namespace: `azsb3lp24kcvthyga`; maxDeliveryCount: 10 |
| Azure Storage Account | `azst3lp24kcvthyga` | centralus | blobEndpoint: `https://azst3lp24kcvthyga.blob.core.windows.net/`; localAuth: disabled; anonBlob: disabled |
| Blob Container | `teaching-materials` | centralus | Storage: `azst3lp24kcvthyga`; publicAccess: None |
| Container Apps Environment | `azcae3lp24kcvthyga` | centralus | Plan: Consumption; logAnalytics: `azlog3lp24kcvthyga` |
| Azure Container App | `azca3lp24kcvthyga` | centralus | FQDN: `azca3lp24kcvthyga.happymeadow-4ef7e0a2.centralus.azurecontainerapps.io`; ingress: external port 8080; identity: `azid3lp24kcvthyga`; SQL connection env: `AZURE_SQL_CONTOSOUNIVERSITY_SQL_CONNECTIONSTRING` |
