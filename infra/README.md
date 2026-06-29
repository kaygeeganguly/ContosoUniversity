# ContosoUniversity — Azure Infrastructure

## Overview

This folder contains the Bicep IaC and deployment scripts to provision all Azure infrastructure required by the modernized ContosoUniversity ASP.NET Core application.

## Architecture

```
Azure Container Apps Environment (Consumption)
  └── Container App: azca{token}
        ├── Azure Container Registry (azacr{token})   — Docker image store
        ├── Azure SQL Database (ContosoUniversity)     — school data (GP Serverless)
        ├── Azure Service Bus (azsb{token})            — ContosoUniversityNotifications queue
        ├── Azure Blob Storage (azst{token})           — teaching-materials container
        └── Managed Identity (azid{token})             → role assignments to all services
```

## Files

| File | Description |
|------|-------------|
| `main.bicep` | Root template — orchestrates all modules |
| `main.parameters.json` | Non-secret parameters (env name, location, SQL login) |
| `modules/identity.bicep` | User-Assigned Managed Identity |
| `modules/registry.bicep` | Azure Container Registry + AcrPull role |
| `modules/loganalytics.bicep` | Log Analytics Workspace |
| `modules/sql.bicep` | Azure SQL Server + Database + firewall |
| `modules/servicebus.bicep` | Service Bus Namespace + Queue + Data Owner role |
| `modules/storage.bicep` | Storage Account + Blob Container + Blob Contributor role |
| `modules/containerapp.bicep` | Container Apps Environment + Container App |
| `deploy.ps1` | Windows/PowerShell deployment script |
| `deploy.sh` | Linux/macOS Bash deployment script |
| `infra-config.md` | Machine-readable resource summary (generated post-provision) |
| `compliance.md` | IaC rules compliance report |

## Prerequisites

- Azure CLI: `az --version` (≥ 2.50)
- Bicep: `az bicep install` (auto-installed by CLI)
- Logged in: `az login`

## Deployment (Windows)

```powershell
cd infra
.\deploy.ps1 -ResourceGroupName "rg-contosouniversity" `
             -Location "centralus" `
             -EnvironmentName "dev"
# SQL AAD admin is auto-detected from current az login
```

## Deployment (Linux/macOS)

```bash
cd infra
chmod +x deploy.sh
./deploy.sh
# SQL AAD admin is auto-detected from current az login
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `environmentName` | `dev` | Short label used in resource naming |
| `location` | `centralus` | Azure region |
| `sqlAadAdminObjectId` | *(auto-detected)* | Object ID of the Azure AD SQL admin (defaults to current az login user) |
| `sqlAadAdminLogin` | *(auto-detected)* | UPN/display name of the SQL Azure AD admin |

## Resource Naming Convention

All resources follow `az{prefix}{resourceToken}` where `resourceToken = uniqueString(subscriptionId, resourceGroupId, location, environmentName)`.

| Resource | Prefix | Example |
|----------|--------|---------|
| Managed Identity | `id` | `azid{token}` |
| Container Registry | `acr` | `azacr{token}` |
| Log Analytics | `log` | `azlog{token}` |
| Container Apps Env | `cae` | `azcae{token}` |
| Container App | `ca` | `azca{token}` |
| SQL Server | `sql` | `azsql{token}` |
| Service Bus | `sb` | `azsb{token}` |
| Storage Account | `st` | `azst{token}` |

## Role Assignments

| Role | Scope | Purpose |
|------|-------|---------|
| AcrPull | Container Registry | Managed Identity pulls images |
| Azure Service Bus Data Owner | Service Bus Namespace | App sends/receives notifications |
| Storage Blob Data Contributor | Storage Account | App uploads/downloads teaching materials |
| SQL (via Service Connector) | SQL Database | Passwordless connection using Managed Identity |

## Post-Provision

After provisioning, the deployment script automatically:
1. Installs the `serviceconnector-passwordless` extension
2. Runs `az containerapp connection create sql` to configure passwordless SQL access
3. Generates `infra-config.md` with all provisioned resource details

The Container App initially uses `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`. The actual application image is pushed and deployed in the subsequent containerization/deployment task.
