# IaC Rules Compliance Report — ContosoUniversity Bicep Infrastructure

## Deployment Tool: azcli | IaC Type: bicep

---

### General Rules

| Rule | Applied | Notes |
|------|---------|-------|
| `appmod-get-available-region-sku` called first | ✅ | Region `swedencentral` selected (quota: 500 vCores, 250 SQL servers) |
| Use `.ps1` for PowerShell, `.sh` for Bash | ✅ | `deploy.ps1` and `deploy.sh` |
| All deployment steps validated; script fails fast | ✅ | `$ErrorActionPreference = "Stop"` / `set -euo pipefail` |
| Expected files: `main.bicep`, `main.parameters.json` | ✅ | Both present |
| Resource token: `uniqueString(subscription().id, resourceGroup().id, location, environmentName)` | ✅ | `var resourceToken = uniqueString(...)` in `main.bicep` |
| All resources named `az{prefix}{resourceToken}` (prefix ≤ 3 chars, alphanumeric) | ✅ | `azid`, `azacr`, `azlog`, `azcae`, `azca`, `azsql`, `azsb`, `azst` |

---

### Container App Rules

| Rule | Applied | Notes |
|------|---------|-------|
| Attach User-Assigned Managed Identity | ✅ | `identity.type = 'UserAssigned'` with `managedIdentityId` |
| AcrPull (`7f951dda`) role assigned to managed identity (before container apps) | ✅ | `registry.bicep` — role assignment defined inside registry module, `dependsOn: [registry]` in main |
| Use managed identity (NOT system) for registry connection | ✅ | `registries[].identity = managedIdentityId` |
| Use `properties.configuration.registries` for registry connection | ✅ | Set in `containerapp.bicep` |
| Base image: `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` | ✅ | `properties.template.containers[0].image` |
| CORS enabled via `properties.configuration.ingress.corsPolicy` | ✅ | All origins, methods, headers allowed |
| Container App Environment connected to Log Analytics | ✅ | `logAnalyticsConfiguration.customerId` + `sharedKey` |
| No Key Vault references (app uses Managed Identity everywhere — no secrets) | ✅ | Key Vault skipped per rule: "Use Key Vault only when application has secrets to store" |

---

### SQL Database Rules

| Rule | Applied | Notes |
|------|---------|-------|
| Firewall rule to allow Azure Services (0.0.0.0) | ✅ | `AllowAzureServices` rule: `0.0.0.0` → `0.0.0.0` |
| App uses Managed Identity → Service Connector post-provision step | ✅ | `az containerapp connection create sql` in deploy scripts |
| Service Connector uses `--user-identity client-id=XX subs-id=XX` | ✅ | `--user-identity client-id=$managedIdentityClientId subs-id=$subscriptionId` |
| Service Connector uses `--client-type dotnet` | ✅ | `.NET` application type |
| Service Connector adds `-c containername` (`contosouniversity`) | ✅ | `--container contosouniversity` |

---

### Storage Account Rules

| Rule | Applied | Notes |
|------|---------|-------|
| Disable local auth (shared key) | ✅ | `allowSharedKeyAccess: false` |
| Disable anonymous blob access | ✅ | `allowBlobPublicAccess: false` |

---

### Key Vault Rules

| Rule | Status | Notes |
|------|--------|-------|
| Key Vault skipped — no application secrets | ✅ | App uses Managed Identity for all Azure services; no passwords/keys stored |

---

### Container Registry Rules

| Rule | Applied | Notes |
|------|---------|-------|
| No additional rules required | ✅ | Standard ACR Basic SKU provisioned |

---

### Service Bus Rules

| Rule | Applied | Notes |
|------|---------|-------|
| No additional rules required | ✅ | Standard namespace + queue + Data Owner role assigned |

---

## Summary

All mandatory rules applied. No rules skipped except Key Vault (not applicable — no application secrets). Post-provision Service Connector step handles passwordless SQL access.
