<#
.SYNOPSIS
    Deploys ContosoUniversity Azure infrastructure using Bicep IaC.

.DESCRIPTION
    Provisions: Managed Identity, Log Analytics, ACR, SQL Database,
    Service Bus, Storage Account, and Azure Container Apps.
    After Bicep deployment, runs Service Connector to bind
    SQL Database to the Container App using Managed Identity.

.PARAMETER ResourceGroupName
    Name of the Azure resource group to deploy into.

.PARAMETER Location
    Azure region. Default: centralus

.PARAMETER EnvironmentName
    Environment name used in resource naming. Default: contosouniversity

.PARAMETER SqlAdminLogin
    SQL Server administrator login. Default: sqladmin

.PARAMETER SqlAdminPassword
    SQL Server administrator password. Prompted if not supplied.

.EXAMPLE
    .\deploy.ps1 -ResourceGroupName "rg-contosouniversity" -SqlAdminPassword "MyP@ssw0rd!"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "centralus",

    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "contosouniversity",

    [Parameter(Mandatory = $false)]
    [string]$SqlAdminLogin = "sqladmin",

    [Parameter(Mandatory = $false)]
    [string]$SqlAdminPassword = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

# ── Prompt for SQL password if not provided ───────────────────
if ([string]::IsNullOrEmpty($SqlAdminPassword)) {
    $securePassword = Read-Host -Prompt "Enter SQL administrator password" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $SqlAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

# ── Validate Azure login ──────────────────────────────────────
Write-Host "Verifying Azure login..." -ForegroundColor Cyan
$accountInfo = az account show --query "{id:id, name:name}" -o json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to Azure. Run 'az login' first."
    exit 1
}
$account = $accountInfo | ConvertFrom-Json
Write-Host "  Subscription: $($account.name) ($($account.id))" -ForegroundColor Gray

# ── Create resource group if needed ──────────────────────────
Write-Host "`nEnsuring resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Cyan
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    az group create --name $ResourceGroupName --location $Location --output none
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create resource group."; exit 1 }
    Write-Host "  Resource group created." -ForegroundColor Green
} else {
    Write-Host "  Resource group already exists." -ForegroundColor Gray
}

# ── Deploy Bicep infrastructure ───────────────────────────────
$deploymentName = "contosouniversity-infra-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "`nDeploying Bicep infrastructure (deployment: $deploymentName)..." -ForegroundColor Cyan

$deploymentJson = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$ScriptDir\main.bicep" `
    --parameters "$ScriptDir\main.parameters.json" `
    --parameters environmentName=$EnvironmentName `
    --parameters location=$Location `
    --parameters sqlAdminLogin=$SqlAdminLogin `
    --parameters sqlAdminPassword=$SqlAdminPassword `
    --name $deploymentName `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep deployment failed. Review the error output above."
    exit 1
}

$deployment = $deploymentJson | ConvertFrom-Json
$outputs = $deployment.properties.outputs

$containerAppName       = $outputs.containerAppName.value
$containerAppFqdn       = $outputs.containerAppFqdn.value
$sqlServerName          = $outputs.sqlServerName.value
$sqlDatabaseName        = $outputs.sqlDatabaseName.value
$sqlServerFqdn          = $outputs.sqlServerFqdn.value
$acrLoginServer         = $outputs.acrLoginServer.value
$acrName                = $outputs.acrName.value
$managedIdentityClientId = $outputs.managedIdentityClientId.value
$managedIdentityName    = $outputs.managedIdentityName.value
$serviceBusNamespace    = $outputs.serviceBusNamespace.value
$storageAccountName     = $outputs.storageAccountName.value

Write-Host "`n=== Bicep Deployment Complete ===" -ForegroundColor Green
Write-Host "  Container App   : https://$containerAppFqdn"
Write-Host "  SQL Server      : $sqlServerFqdn"
Write-Host "  ACR             : $acrLoginServer"
Write-Host "  Service Bus     : $serviceBusNamespace"
Write-Host "  Storage Account : $storageAccountName"
Write-Host "  Managed Identity: $managedIdentityName (clientId: $managedIdentityClientId)"

# ── Post-provision: Service Connector for SQL + Managed Identity
Write-Host "`nInstalling Service Connector extension..." -ForegroundColor Cyan
az extension add --name serviceconnector-passwordless --upgrade --only-show-errors
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to install serviceconnector-passwordless extension. Skipping Service Connector step."
} else {
    Write-Host "Configuring SQL Database connection via Service Connector..." -ForegroundColor Cyan

    $subscriptionId = $(az account show --query id -o tsv)
    $containerAppId = $(az containerapp show `
        --name $containerAppName `
        --resource-group $ResourceGroupName `
        --query id -o tsv)

    az containerapp connection create sql `
        --connection "contosouniversity_sql" `
        --source-id $containerAppId `
        --tg $ResourceGroupName `
        --server $sqlServerName `
        --database $sqlDatabaseName `
        --user-identity "client-id=$managedIdentityClientId" "subs-id=$subscriptionId" `
        --client-type dotnet `
        -c "contosouniversity" `
        -y

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Service Connector setup failed. You may need to run this step manually."
        Write-Warning "Command: az containerapp connection create sql --connection contosouniversity_sql --source-id <containerAppId> --tg $ResourceGroupName --server $sqlServerName --database $sqlDatabaseName --user-identity client-id=$managedIdentityClientId subs-id=<subscriptionId> --client-type dotnet -c contoso-university -y"
    } else {
        Write-Host "  SQL Service Connector configured successfully." -ForegroundColor Green
    }
}

# ── Summary ───────────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " ContosoUniversity Infrastructure Ready " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Container App URL  : https://$containerAppFqdn"
Write-Host "  SQL Server         : $sqlServerFqdn"
Write-Host "  ACR Login Server   : $acrLoginServer"
Write-Host "  Service Bus NS     : $serviceBusNamespace"
Write-Host "  Storage Account    : $storageAccountName"
Write-Host ""
Write-Host "Next step: Run task 008 to build & deploy the container image."
