# deploy.ps1 — Build, push to ACR, and deploy to Azure Container App
# ContosoUniversity — Task 008-deployment-containerapp

param(
    [string]$SubscriptionId  = "0dc80431-5546-4681-a92a-2a799ade5139",
    [string]$ResourceGroup   = "rg-contosouniversity",
    [string]$AcrName         = "azacr3lp24kcvthyga",
    [string]$AcrLoginServer  = "azacr3lp24kcvthyga.azurecr.io",
    [string]$ImageName       = "contosouniversity",
    [string]$ImageTag        = "latest",
    [string]$ContainerAppName = "azca3lp24kcvthyga",
    [string]$ManagedIdentityClientId = "7e6223da-2364-41ae-ab88-59232bad4a8e",
    [string]$ManagedIdentityResourceId = "/subscriptions/0dc80431-5546-4681-a92a-2a799ade5139/resourceGroups/rg-contosouniversity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azid3lp24kcvthyga"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path "$PSScriptRoot\..\..\..\..\..\.."

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ContosoUniversity — Azure Container App Deployment" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ── Step 1: Set subscription ───────────────────────────────────────────
Write-Host "`n[1/4] Setting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
Write-Host "  ✅ Subscription set: $SubscriptionId"

# ── Step 2: Build and push image to ACR ───────────────────────────────
$FullImageRef = "$AcrLoginServer/${ImageName}:${ImageTag}"
Write-Host "`n[2/4] Building and pushing image to ACR: $FullImageRef" -ForegroundColor Yellow
Write-Host "  Using 'az acr build' (no local Docker required)"

az acr build `
    --registry $AcrName `
    --image "${ImageName}:${ImageTag}" `
    --file "$RepoRoot\Dockerfile" `
    "$RepoRoot"

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ ACR build failed."
    exit 1
}
Write-Host "  ✅ Image built and pushed: $FullImageRef"

# ── Step 3: Update Container App with new image + env vars ─────────────
Write-Host "`n[3/4] Updating Container App: $ContainerAppName" -ForegroundColor Yellow

$SqlConnStr = "Data Source=azsql3lp24kcvthyga.database.windows.net,1433;Initial Catalog=ContosoUniversity;User ID=7e6223da-2364-41ae-ab88-59232bad4a8e;Authentication=ActiveDirectoryManagedIdentity"

az containerapp update `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --image $FullImageRef `
    --set-env-vars `
        "AZURE_CLIENT_ID=$ManagedIdentityClientId" `
        "ASPNETCORE_ENVIRONMENT=Production" `
        "ASPNETCORE_URLS=http://+:8080" `
        "ConnectionStrings__DefaultConnection=$SqlConnStr" `
        "AzureServiceBus__FullyQualifiedNamespace=azsb3lp24kcvthyga.servicebus.windows.net" `
        "AzureServiceBus__QueueName=contoso-notifications" `
        "Storage__ServiceUri=https://azst3lp24kcvthyga.blob.core.windows.net/" `
        "Storage__ContainerName=teaching-materials"

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Container App update failed."
    exit 1
}
Write-Host "  ✅ Container App updated"

# ── Step 4: Verify deployment ─────────────────────────────────────────
Write-Host "`n[4/4] Verifying deployment..." -ForegroundColor Yellow
$app = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup -o json | ConvertFrom-Json
$fqdn = $app.properties.configuration.ingress.fqdn
$state = $app.properties.runningStatus

Write-Host "  ✅ Container App Status : $state"
Write-Host "  ✅ Application URL      : https://$fqdn"

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " Deployment Complete!" -ForegroundColor Green
Write-Host " URL: https://$fqdn" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
