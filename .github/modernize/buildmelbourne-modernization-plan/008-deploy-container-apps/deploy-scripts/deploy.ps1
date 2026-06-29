# deploy.ps1 — ContosoUniversity Azure Container App Deployment
# Builds and pushes the Docker image to ACR, then deploys to Azure Container App.

$ErrorActionPreference = "Stop"

# ── Configuration ─────────────────────────────────────────────────────────────
$SUBSCRIPTION_ID      = "0dc80431-5546-4681-a92a-2a799ade5139"
$RESOURCE_GROUP       = "rg-contosouniversity"
$ACR_NAME             = "azacrzufdbcxl752tq"
$ACR_LOGIN_SERVER     = "azacrzufdbcxl752tq.azurecr.io"
$IMAGE_NAME           = "contosouniversity"
$IMAGE_TAG            = "latest"
$CONTAINER_APP_NAME   = "azcazufdbcxl752tq"
$MANAGED_IDENTITY_ID  = "/subscriptions/0dc80431-5546-4681-a92a-2a799ade5139/resourceGroups/rg-contosouniversity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azidzufdbcxl752tq"

# ── Env vars for the Container App ────────────────────────────────────────────
$AZURE_CLIENT_ID                  = "8338f244-ad28-4717-9f83-644bccbce6c9"
$SQL_CONNECTION_STRING            = "Server=tcp:azsqlzufdbcxl752tq.database.windows.net;Database=ContosoUniversity;Authentication=Active Directory Default;TrustServerCertificate=True"
$SERVICE_BUS_FQDN                 = "azsbzufdbcxl752tq.servicebus.windows.net"
$STORAGE_SERVICE_URI              = "https://azstzufdbcxl752tq.blob.core.windows.net"
$STORAGE_CONTAINER_NAME           = "teaching-materials"

# ── Resolve paths ─────────────────────────────────────────────────────────────
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$REPO_ROOT   = Resolve-Path (Join-Path $SCRIPT_DIR "..\..\..\..\..\..") 
# Repo root is 6 levels up from deploy-scripts/
$APP_DIR     = Join-Path $REPO_ROOT "ContosoUniversity"

Write-Host ""
Write-Host "================================================"
Write-Host " ContosoUniversity — Container App Deployment  "
Write-Host "================================================"
Write-Host "Subscription : $SUBSCRIPTION_ID"
Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "ACR          : $ACR_LOGIN_SERVER"
Write-Host "Image        : ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
Write-Host "Container App: $CONTAINER_APP_NAME"
Write-Host ""

# ── Step 1: Set subscription ──────────────────────────────────────────────────
Write-Host "[1/3] Setting active subscription..."
az account set --subscription $SUBSCRIPTION_ID
Write-Host "  ✅ Subscription set."

# ── Step 2: Build + push with az acr build ────────────────────────────────────
Write-Host ""
Write-Host "[2/3] Building and pushing Docker image to ACR..."
Write-Host "  Build context : $APP_DIR"
Write-Host "  Dockerfile    : $APP_DIR\Dockerfile"

az acr build `
  --registry $ACR_NAME `
  --resource-group $RESOURCE_GROUP `
  --image "${IMAGE_NAME}:${IMAGE_TAG}" `
  --file "$APP_DIR\Dockerfile" `
  --platform linux/amd64 `
  "$APP_DIR"

if ($LASTEXITCODE -ne 0) {
    Write-Error "  ❌ ACR build failed. Check output above."
    exit 1
}
Write-Host "  ✅ Image built and pushed: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

# ── Step 3: Update Container App ─────────────────────────────────────────────
Write-Host ""
Write-Host "[3/3] Updating Container App with new image and configuration..."

az containerapp update `
  --name $CONTAINER_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --image "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" `
  --set-env-vars `
    "AZURE_CLIENT_ID=$AZURE_CLIENT_ID" `
    "ConnectionStrings__DefaultConnection=$SQL_CONNECTION_STRING" `
    "AzureServiceBus__FullyQualifiedNamespace=$SERVICE_BUS_FQDN" `
    "Storage__ServiceUri=$STORAGE_SERVICE_URI" `
    "Storage__ContainerName=$STORAGE_CONTAINER_NAME" `
    "ASPNETCORE_ENVIRONMENT=Production" `
    "ASPNETCORE_URLS=http://+:8080" `
  --cpu 0.5 `
  --memory 1.0Gi `
  --min-replicas 0 `
  --max-replicas 3

if ($LASTEXITCODE -ne 0) {
    Write-Error "  ❌ Container App update failed. Check output above."
    exit 1
}
Write-Host "  ✅ Container App updated successfully."

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================"
Write-Host " Deployment Complete!"
Write-Host " App URL: https://azcazufdbcxl752tq.ashymushroom-e7c9520b.centralus.azurecontainerapps.io"
Write-Host "================================================"
