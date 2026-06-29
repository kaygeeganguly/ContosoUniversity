# Task 007 – Generate Bicep IaC and Provision Azure Infrastructure

## Objective

Generate and provision all Azure infrastructure required by the modernized ContosoUniversity application using Bicep IaC and Azure CLI.

## Region

**swedencentral** — selected based on quota availability for all required resource types.

## Resources to Provision

| Resource Type                | Bicep Name Pattern         | SKU / Tier         | Purpose                                       |
|------------------------------|----------------------------|--------------------|-----------------------------------------------|
| User-Assigned Managed Identity | `azid{token}`            | N/A                | Passwordless auth to all Azure services       |
| Azure Container Registry     | `azacr{token}`             | Basic              | Store and serve Docker container images       |
| Log Analytics Workspace      | `azlog{token}`             | PerGB2018          | Telemetry and Container Apps log sink         |
| Container Apps Environment   | `azcae{token}`             | Consumption        | Hosting environment for container apps        |
| Container App                | `azca{token}`              | Consumption        | Run the ASP.NET Core web application          |
| Azure SQL Server             | `azsql{token}`             | N/A (hosts DB)     | Logical SQL server for school database        |
| Azure SQL Database           | `ContosoUniversity`        | GP_S_Gen5 (1 vCore)| Persistent school database (serverless)       |
| Azure Service Bus Namespace  | `azsb{token}`              | Standard           | Cloud-native notification messaging           |
| Service Bus Queue            | `ContosoUniversityNotifications` | Standard      | Notification queue (replaces MSMQ)            |
| Azure Storage Account        | `azst{token}`              | Standard_LRS       | Teaching material blob storage                |
| Blob Container               | `teaching-materials`       | Hot                | Store course teaching material images         |

## Role Assignments

| Identity              | Scope              | Role                         | GUID                                     |
|-----------------------|--------------------|------------------------------|------------------------------------------|
| Managed Identity      | Container Registry | AcrPull                      | `7f951dda-4ed3-4680-a7ca-43fe172d538d`   |
| Managed Identity      | Service Bus NS     | Azure Service Bus Data Owner | `090c5cfd-751d-490a-894a-3ce6f1109419`   |
| Managed Identity      | Storage Account    | Storage Blob Data Contributor| `ba92f5b4-2d11-453d-a403-e96b0029c9fe`   |
| Managed Identity      | SQL Database       | (via Service Connector)      | post-provision step                      |

## Execution Steps

1. **Validate prerequisites**: `az --version`, `az bicep version`
2. **Create resource group** in `swedencentral`
3. **Run `deploy.ps1`** (Windows) or `deploy.sh` (Linux/macOS) from `./infra/`
4. **Service Connector** post-provision step configures SQL Managed Identity access
5. **Verify** all resources in Azure Portal

## Files Generated

```
infra/
├── main.bicep              # Orchestrates all modules
├── main.parameters.json    # Non-secret parameters
├── modules/
│   ├── identity.bicep      # User-Assigned Managed Identity
│   ├── registry.bicep      # Azure Container Registry + AcrPull role
│   ├── loganalytics.bicep  # Log Analytics Workspace
│   ├── sql.bicep           # Azure SQL Server + Database + firewall
│   ├── servicebus.bicep    # Service Bus Namespace + Queue + role
│   ├── storage.bicep       # Storage Account + Blob Container + role
│   └── containerapp.bicep  # Container Apps Environment + Container App
├── deploy.ps1              # Windows deployment script
├── deploy.sh               # Linux/macOS deployment script
├── README.md               # Infrastructure documentation
├── compliance.md           # Rules compliance report
└── infra-config.md         # Machine-readable resource summary (post-provision)
```
