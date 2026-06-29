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
| User-Assigned Managed Identity | `azidzufdbcxl752tq` | centralus | Client ID: `8338f244-ad28-4717-9f83-644bccbce6c9` |
| Azure Container Registry | `azacrzufdbcxl752tq` | centralus | Login server: `azacrzufdbcxl752tq.azurecr.io` |
| Log Analytics Workspace | `azlogzufdbcxl752tq` | centralus | Sink for Container Apps Environment logs |
| Azure Container Apps Environment | `azcaezufdbcxl752tq` | centralus | Consumption tier, connected to Log Analytics |
| Azure Container App | `azcazufdbcxl752tq` | centralus | FQDN: `azcazufdbcxl752tq.ashymushroom-e7c9520b.centralus.azurecontainerapps.io` |
| Azure SQL Server | `azsqlzufdbcxl752tq` | centralus | FQDN: `azsqlzufdbcxl752tq.database.windows.net` |
| Azure SQL Database | `ContosoUniversity` | centralus | Server: `azsqlzufdbcxl752tq`, env var: `AZURE_SQL_CONNECTIONSTRING` / `ConnectionStrings__DefaultConnection` |
| Azure Service Bus Namespace | `azsbzufdbcxl752tq` | centralus | FQDN: `azsbzufdbcxl752tq.servicebus.windows.net`, Queue: `ContosoUniversityNotifications` |
| Azure Storage Account | `azstzufdbcxl752tq` | centralus | Service URI: `https://azstzufdbcxl752tq.blob.core.windows.net`, Container: `teaching-materials` |
