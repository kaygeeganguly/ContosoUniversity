# Task 007 — Provision Azure Infrastructure

**TaskId**: `007-infrastructure-bicep`  
**IaC Tool**: Bicep  
**Region**: `centralus`  
**Deployment Tool**: Azure CLI (`az deployment group create`)

---

## Resources to Provision

| Resource | Azure Service | Notes |
|----------|--------------|-------|
| User-Assigned Managed Identity | `Microsoft.ManagedIdentity/userAssignedIdentities` | Shared identity for all Azure service auth |
| Log Analytics Workspace | `Microsoft.OperationalInsights/workspaces` | Required by Container Apps Environment |
| Azure Container Registry | `Microsoft.ContainerRegistry/registries` | Basic SKU; AcrPull role assigned to identity |
| Azure SQL Server | `Microsoft.Sql/servers` | Serverless Gen5; firewall allows Azure services |
| Azure SQL Database | `ContosoUniversity` | GP_S_Gen5; auto-pause after 60 min |
| Azure Service Bus Namespace | `Microsoft.ServiceBus/namespaces` | Standard tier |
| Azure Service Bus Queue | `contoso-notifications` | Per `appsettings.json` app config |
| Azure Storage Account | `Microsoft.Storage/storageAccounts` | Local auth & anonymous access disabled |
| Blob Container | `teaching-materials` | Per `appsettings.json` app config |
| Container Apps Environment | `Microsoft.App/managedEnvironments` | Consumption plan + Log Analytics |
| Container App | `Microsoft.App/containerApps` | Hello-world base image; replaced in task 008 |

---

## Role Assignments

| Role | Scope | RBAC Definition ID |
|------|-------|-------------------|
| AcrPull | ACR | `7f951dda-4ed3-4680-a7ca-43fe172d538d` |
| Azure Service Bus Data Owner | Service Bus Namespace | `090c5cfd-751d-6522-c04e-b6028e3b2e5c` |
| Storage Blob Data Contributor | Storage Account | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |
| SQL roles (db_datareader + db_datawriter) | SQL Database | Granted by Service Connector post-provision step |

---

## Execution Steps

### Step 1 — Validate Bicep files

```powershell
cd infra
az bicep build --file main.bicep
```

Expected: exit code 0, no errors.

### Step 2 — Deploy Infrastructure

```powershell
cd infra

.\deploy.ps1 `
  -ResourceGroupName "rg-contosouniversity" `
  -Location         "centralus" `
  -EnvironmentName  "contosouniversity" `
  -SqlAdminLogin    "sqladmin" `
  -SqlAdminPassword "<your-password>"
```

The script will:
1. Create resource group `rg-contosouniversity` in `centralus` if it doesn't exist
2. Run `az deployment group create` with `main.bicep` and `main.parameters.json`
3. Install `serviceconnector-passwordless` Azure CLI extension
4. Run `az containerapp connection create sql` to bind SQL DB to Container App via Managed Identity

### Step 3 — Verify deployment outputs

After success, the script prints all provisioned resource names and endpoints. Capture:
- Container App FQDN
- SQL Server FQDN
- ACR login server
- Service Bus namespace
- Storage account name
- Managed Identity client ID

### Step 4 — Generate `infra/infra-config.md`

After successful provisioning, generate `infra/infra-config.md` using the actual provisioned resource names from the deployment outputs.

---

## Success Criteria

- [ ] `az bicep build --file main.bicep` exits with code 0
- [ ] `az deployment group create` completes successfully
- [ ] All 11+ resources visible in Azure Portal under the resource group
- [ ] Container App responds at its public FQDN
- [ ] Service Connector sets `AZURE_SQL_CONNECTIONSTRING` on the Container App
- [ ] `infra-config.md` generated with actual provisioned resource details
