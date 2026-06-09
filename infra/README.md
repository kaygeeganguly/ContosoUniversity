# ContosoUniversity — Azure Infrastructure

This directory contains Bicep IaC templates to provision all required Azure infrastructure for the ContosoUniversity application.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Azure Container Apps Environment (azcae...)             │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Container App (azca...)                           │  │
│  │  ├─ Image: mcr.microsoft.com/.../helloworld:latest │  │
│  │  ├─ User-Assigned Managed Identity (azmi...)       │  │
│  │  └─ Env vars: ServiceBus, Storage, SQL (via SC)    │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
         │ AcrPull         │ Data Owner      │ Blob Contributor
         ▼                 ▼                 ▼
    ACR (azacr...)   Service Bus (azsb...)  Storage (azst...)
                               │
                         Queue: contoso-notifications
                               
    SQL Server (azsql...) / DB: ContosoUniversity
    └─ Service Connector (post-provision) → Container App
    
    Log Analytics (azlaw...) → Container App Environment
```

---

## Resources

| Module | Resource Type | Name Pattern | Notes |
|--------|--------------|--------------|-------|
| identity | `Microsoft.ManagedIdentity/userAssignedIdentities` | `azmi{token}` | Used by Container App for all auth |
| loganalytics | `Microsoft.OperationalInsights/workspaces` | `azlaw{token}` | Container App environment logging |
| acr | `Microsoft.ContainerRegistry/registries` | `azacr{token}` | Basic SKU; admin disabled |
| sql | `Microsoft.Sql/servers` | `azsql{token}` | SQL Server 12.0 |
| sql | `Microsoft.Sql/servers/databases` | `ContosoUniversity` | Serverless GP_S_Gen5 / 1 vCore |
| servicebus | `Microsoft.ServiceBus/namespaces` | `azsb{token}` | Standard tier |
| servicebus | `Microsoft.ServiceBus/namespaces/queues` | `contoso-notifications` | Static name per app config |
| storage | `Microsoft.Storage/storageAccounts` | `azst{token}` | Standard LRS; local auth disabled |
| storage | `Microsoft.Storage/storageAccounts/blobServices/containers` | `teaching-materials` | Static name per app config |
| containerapp | `Microsoft.App/managedEnvironments` | `azcae{token}` | Consumption plan |
| containerapp | `Microsoft.App/containerApps` | `azca{token}` | External ingress on port 8080 |

### Role Assignments

| Role | Scope | Principal | RBAC ID |
|------|-------|-----------|---------|
| AcrPull | ACR | Managed Identity | `7f951dda-4ed3-4680-a7ca-43fe172d538d` |
| Azure Service Bus Data Owner | Service Bus Namespace | Managed Identity | `090c5cfd-751d-6522-c04e-b6028e3b2e5c` |
| Storage Blob Data Contributor | Storage Account | Managed Identity | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |

> **SQL access** is granted via the **Service Connector** post-provision step (`az containerapp connection create sql ...`), which adds the correct Entra ID role automatically.

---

## File Structure

```
infra/
├── main.bicep              # Orchestrator — calls all modules
├── main.parameters.json    # Default parameters
├── modules/
│   ├── identity.bicep      # User-Assigned Managed Identity
│   ├── loganalytics.bicep  # Log Analytics Workspace
│   ├── acr.bicep           # Container Registry + AcrPull role
│   ├── sql.bicep           # SQL Server + Database + firewall
│   ├── servicebus.bicep    # Service Bus namespace + queue + role
│   ├── storage.bicep       # Storage Account + container + role
│   └── containerapp.bicep  # Container App Environment + App
├── deploy.ps1              # Windows deployment script
├── deploy.sh               # Linux/macOS deployment script
├── README.md               # This file
├── compliance.md           # IaC rules compliance report
└── infra-config.md         # Provisioned resource summary (generated post-deploy)
```

---

## Prerequisites

- Azure CLI (`az`) ≥ 2.50 installed and logged in (`az login`)
- Bicep CLI (installed automatically by `az bicep build`)
- `jq` (Linux/macOS deploy.sh only)
- Azure subscription with permissions to create resource groups and all resource types above

---

## Deployment

### Windows (PowerShell)

```powershell
cd infra

# Minimal — prompts for SQL password
.\deploy.ps1 -ResourceGroupName "rg-contosouniversity"

# Full parameters
.\deploy.ps1 `
  -ResourceGroupName "rg-contosouniversity" `
  -Location         "centralus" `
  -EnvironmentName  "contosouniversity" `
  -SqlAdminLogin    "sqladmin" `
  -SqlAdminPassword "MySecretP@ssw0rd!"
```

### Linux / macOS (Bash)

```bash
cd infra
chmod +x deploy.sh

# Minimal — prompts for SQL password
./deploy.sh -g rg-contosouniversity

# Full parameters
./deploy.sh \
  -g rg-contosouniversity \
  -l centralus \
  -e contosouniversity \
  -u sqladmin \
  -p "MySecretP@ssw0rd!"
```

---

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `environmentName` | Used in `uniqueString` for resource naming | `contosouniversity` |
| `location` | Azure region | `centralus` |
| `sqlAdminLogin` | SQL Server administrator login | `sqladmin` |
| `sqlAdminPassword` | SQL Server administrator password (**required**) | — |

> **Tip:** `sqlAdminPassword` is never stored in `main.parameters.json`. It is always passed at deployment time via CLI parameter.

---

## Post-Provision Step — SQL Service Connector

After Bicep deployment, the deploy scripts automatically run:

```bash
az containerapp connection create sql \
  --connection contosouniversity_sql \
  --source-id <container-app-id> \
  --tg <resource-group> \
  --server <sql-server-name> \
  --database ContosoUniversity \
  --user-identity client-id=<mi-client-id> subs-id=<subscription-id> \
  --client-type dotnet \
  -c contoso-university \
  -y
```

This step:
1. Grants the Managed Identity **db_datareader + db_datawriter** roles on the SQL Database
2. Sets the `AZURE_SQL_CONNECTIONSTRING` environment variable on the Container App

The application reads this connection string automatically via `DefaultAzureCredential`.

---

## Environment Variables Set on Container App

| Variable | Source | Value |
|----------|--------|-------|
| `AZURE_CLIENT_ID` | Bicep | Managed Identity client ID |
| `AzureServiceBus__FullyQualifiedNamespace` | Bicep | `azsb{token}.servicebus.windows.net` |
| `AzureServiceBus__QueueName` | Bicep | `contoso-notifications` |
| `Storage__ServiceUri` | Bicep | `https://azst{token}.blob.core.windows.net/` |
| `Storage__ContainerName` | Bicep | `teaching-materials` |
| `AZURE_SQL_CONNECTIONSTRING` | Service Connector | Set post-provision |
