# IaC Rules Compliance Report — ContosoUniversity Infrastructure

Generated for task `007-infrastructure-bicep` using `appmod-get-iac-rules` (deploymentTool=azcli, iacType=bicep).

---

## General Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 1 | Call `appmod-get-available-region-sku` before generating resources | ✅ Applied | Called before any file creation |
| 2 | Resource region set to an available region from the list | ✅ Applied | `centralus` selected |
| 3 | If current region unavailable, choose available region and add index suffix | ✅ N/A | `centralus` is available for all resources |
| 4 | Use `.ps1` for PowerShell scripts, `.sh` for Bash scripts | ✅ Applied | `deploy.ps1` and `deploy.sh` created |
| 5 | Validate PowerShell script syntax (brace matching, string termination) | ✅ Applied | Script syntax validated |
| 6 | Ensure all steps succeed; fix and rerun if any step fails | ✅ Applied | `$ErrorActionPreference = "Stop"` and `set -euo pipefail` |

---

## Bicep IaC Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 7 | Expected files: `main.bicep`, `main.parameters.json` | ✅ Applied | Both files created |
| 8 | Resource token: `uniqueString(subscription().id, resourceGroup().id, location, environmentName)` | ✅ Applied | `var resourceToken = uniqueString(...)` in `main.bicep` |
| 9 | Naming: `az{resourcePrefix}{resourceToken}` where prefix ≤ 3 chars | ✅ Applied | All resources follow pattern (e.g. `azmi`, `azlaw`, `azacr`, `azsql`, `azsb`, `azst`, `azcae`, `azca`) |

---

## Container Apps Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 10 | Attach User-Assigned Managed Identity | ✅ Applied | `identity.type = 'UserAssigned'` in `containerapp.bicep` |
| 11 | Add AcrPull role for user-assigned managed identity (one per registry) | ✅ Applied | `acrPullRoleAssignment` in `modules/acr.bicep` (defined before container app) |
| 12 | Use user-assigned identity (NOT system) to connect to container registry | ✅ Applied | `registries[].identity = managedIdentityId` |
| 13 | Registry connection via `properties.configuration.registries` | ✅ Applied | Configured even for base hello-world image |
| 14 | Container Apps MUST use base image `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` | ✅ Applied | Set as `containers[0].image` |
| 15 | Enable CORS via `properties.configuration.ingress.corsPolicy` | ✅ Applied | allowedOrigins: `['*']`, all methods & headers |
| 16 | Define all used secrets; use Key Vault if possible | ✅ N/A | No secrets exist — all auth via Managed Identity (`DefaultAzureCredential`). Key Vault skipped per rule: "Use Key Vault only when application has secrets to store." |
| 17 | Container App Environment connected to Log Analytics Workspace | ✅ Applied | `logAnalyticsConfiguration.customerId` + `sharedKey` from `listKeys()` |

---

## SQL Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 18 | Firewall rule to allow Azure Services (IP 0.0.0.0) | ✅ Applied | `AllowAllWindowsAzureIps` rule with start/end IP `0.0.0.0` |
| 19 | Using Managed Identity for DB → post-provision Service Connector step | ✅ Applied | `az containerapp connection create sql --user-identity client-id=... subs-id=...` in both deploy scripts |
| 20 | Service Connector: use `--user-identity client-id=XX subs-id=XX` | ✅ Applied | Exact parameter format followed |
| 21 | Service Connector: use `--client-type dotnet` | ✅ Applied | |
| 22 | Service Connector: use `-c containername` for container app | ✅ Applied | `-c contoso-university` |

---

## Storage Account Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 23 | Disable storage account local auth (key access) | ✅ Applied | `allowSharedKeyAccess: false` |
| 24 | Disable storage account anonymous blob access | ✅ Applied | `allowBlobPublicAccess: false` |

---

## ACR Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 25 | No additional ACR-specific rules | ✅ N/A | Admin user disabled; public network access enabled |

---

## Service Bus Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 26 | No additional Service Bus rules | ✅ N/A | Standard tier; `contoso-notifications` queue created; Data Owner role assigned |

---

## Key Vault Rules

| # | Rule | Status | Notes |
|---|------|--------|-------|
| 27 | Use Key Vault only when application has secrets to store | ✅ Applied | Key Vault **not provisioned** — application uses Managed Identity (DefaultAzureCredential) for all Azure service authentication; no secrets exist |
