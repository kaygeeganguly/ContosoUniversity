#!/usr/bin/env pwsh
# ============================================================
#  deploy.ps1 — ContosoUniversity Azure Infrastructure
#  Provisions all Azure resources via Bicep + Azure CLI
#  Runs the SQL Service Connector post-provision step
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-contosouniversity",

    [Parameter(Mandatory = $false)]
    [string]$Location = "centralus",

    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "dev",

    # Azure AD admin for SQL — auto-detected from current az login if not supplied
    [Parameter(Mandatory = $false)]
    [string]$SqlAadAdminObjectId = "",

    [Parameter(Mandatory = $false)]
    [string]$SqlAadAdminLogin = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "    [WARN] $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "==============================================" -ForegroundColor Magenta
Write-Host "  ContosoUniversity Infrastructure Deploy" -ForegroundColor Magenta
Write-Host "==============================================" -ForegroundColor Magenta
Write-Host "  Resource Group : $ResourceGroupName"
Write-Host "  Location       : $Location"
Write-Host "  Environment    : $EnvironmentName"
Write-Host ""

# ── Step 1: Verify Azure CLI login ────────────────────────────────────────────
Write-Step "1/7  Verifying Azure CLI login"
$account = az account show --output json 2>&1 | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Not logged in to Azure CLI. Run 'az login' first." }
$subscriptionId = $account.id
Write-Ok "Logged in to subscription: $subscriptionId ($($account.name))"

# Auto-detect SQL AAD admin from current login if not provided
if ([string]::IsNullOrEmpty($SqlAadAdminObjectId)) {
    $currentUser = az ad signed-in-user show --output json 2>&1 | ConvertFrom-Json
    $SqlAadAdminObjectId = $currentUser.id
    $SqlAadAdminLogin    = $currentUser.userPrincipalName
    Write-Ok "SQL AAD Admin auto-detected: $SqlAadAdminLogin ($SqlAadAdminObjectId)"
}

# ── Step 2: Validate Bicep templates ──────────────────────────────────────────
Write-Step "2/7  Validating Bicep templates"
$buildResult = az bicep build --file "$ScriptDir/main.bicep" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host $buildResult -ForegroundColor Red
    throw "Bicep validation failed. Fix errors above and retry."
}
Write-Ok "Bicep validation passed"

# ── Step 3: Create resource group ─────────────────────────────────────────────
Write-Step "3/7  Ensuring resource group '$ResourceGroupName' exists"
az group create --name $ResourceGroupName --location $Location --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to create/verify resource group" }
Write-Ok "Resource group ready"

# ── Step 4: Deploy Bicep ───────────────────────────────────────────────────────
Write-Step "4/7  Deploying Bicep infrastructure (this may take 5-10 minutes)"
$deployJson = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$ScriptDir/main.bicep" `
    --parameters "@$ScriptDir/main.parameters.json" `
    --parameters sqlAadAdminObjectId="$SqlAadAdminObjectId" `
    --parameters sqlAadAdminLogin="$SqlAadAdminLogin" `
    --parameters environmentName="$EnvironmentName" `
    --parameters location="$Location" `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host $deployJson -ForegroundColor Red
    throw "Bicep deployment failed. See errors above."
}

$deploy = $deployJson | ConvertFrom-Json
$outputs = $deploy.properties.outputs

$managedIdentityClientId = $outputs.managedIdentityClientId.value
$managedIdentityName      = $outputs.managedIdentityName.value
$acrLoginServer           = $outputs.acrLoginServer.value
$acrName                  = $outputs.acrName.value
$sqlServerName            = $outputs.sqlServerName.value
$sqlServerFqdn            = $outputs.sqlServerFqdn.value
$sqlDatabaseName          = $outputs.sqlDatabaseName.value
$serviceBusNamespace      = $outputs.serviceBusNamespace.value
$serviceBusFqdn           = $outputs.serviceBusFqdn.value
$storageAccountName       = $outputs.storageAccountName.value
$storageServiceUri        = $outputs.storageServiceUri.value
$containerAppName         = $outputs.containerAppName.value
$containerAppFqdn         = $outputs.containerAppFqdn.value
$containerAppId           = $outputs.containerAppId.value

Write-Ok "Bicep deployment succeeded"

# ── Step 5: Install Service Connector extension ───────────────────────────────
Write-Step "5/7  Setting up SQL Service Connector (Managed Identity)"
Write-Host "     Installing serviceconnector-passwordless extension..."
az extension add --name serviceconnector-passwordless --upgrade --output none 2>&1
if ($LASTEXITCODE -ne 0) { Write-Warn "Extension install returned non-zero; continuing..." }

Write-Host "     Creating SQL Service Connector for Container App..."
az containerapp connection create sql `
    --connection "sqldb_contosouniversity" `
    --source-id $containerAppId `
    --target-resource-group $ResourceGroupName `
    --server $sqlServerName `
    --database $sqlDatabaseName `
    --user-identity client-id=$managedIdentityClientId subs-id=$subscriptionId `
    --client-type dotnet `
    --container contosouniversity `
    -y 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warn "SQL Service Connector failed. Run manually after confirming container app is running:"
    Write-Warn "az containerapp connection create sql --connection sqldb_contosouniversity --source-id $containerAppId --target-resource-group $ResourceGroupName --server $sqlServerName --database $sqlDatabaseName --user-identity client-id=$managedIdentityClientId subs-id=$subscriptionId --client-type dotnet --container contosouniversity -y"
} else {
    Write-Ok "SQL Service Connector configured"
}

# ── Step 6: Write infra-config.md ─────────────────────────────────────────────
Write-Step "6/7  Writing infra-config.md"
$infraConfigContent = @"
# Azure Resources Config

## Environment Info

| Property | Value |
|----------|-------|
| Subscription ID | ``$subscriptionId`` |
| Resource Group | ``$ResourceGroupName`` |
| Location | ``$Location`` |

## Resource List

| Resource Type | Name | Region | Config Details |
|---------------|------|---------|----------------|
| User-Assigned Managed Identity | ``$managedIdentityName`` | $Location | Client ID: ``$managedIdentityClientId`` |
| Azure Container Registry | ``$acrName`` | $Location | Login server: ``$acrLoginServer`` |
| Azure SQL Server | ``$sqlServerName`` | $Location | FQDN: ``$sqlServerFqdn`` |
| Azure SQL Database | ``$sqlDatabaseName`` | $Location | Server: ``$sqlServerName``, DB: ``$sqlDatabaseName`` |
| Azure Service Bus Namespace | ``$serviceBusNamespace`` | $Location | FQDN: ``$serviceBusFqdn``, Queue: ContosoUniversityNotifications |
| Azure Storage Account | ``$storageAccountName`` | $Location | Service URI: ``$storageServiceUri``, Container: teaching-materials |
| Azure Container App | ``$containerAppName`` | $Location | FQDN: ``$containerAppFqdn`` |
"@

Set-Content -Path "$ScriptDir/infra-config.md" -Value $infraConfigContent -Encoding UTF8
Write-Ok "infra-config.md written"

# ── Step 7: Summary ────────────────────────────────────────────────────────────
Write-Step "7/7  Deployment complete!"
Write-Host ""
Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "  Container App URL  : https://$containerAppFqdn" -ForegroundColor White
Write-Host "  ACR Login Server   : $acrLoginServer" -ForegroundColor White
Write-Host "  SQL Server FQDN    : $sqlServerFqdn" -ForegroundColor White
Write-Host "  Service Bus NS     : $serviceBusNamespace" -ForegroundColor White
Write-Host "  Storage Account    : $storageAccountName" -ForegroundColor White
Write-Host "  Managed Identity   : $managedIdentityName (clientId: $managedIdentityClientId)" -ForegroundColor White
Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: Build and push the ContosoUniversity Docker image to $acrLoginServer" -ForegroundColor Yellow
