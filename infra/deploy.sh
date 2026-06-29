#!/usr/bin/env bash
# ============================================================
#  deploy.sh — ContosoUniversity Azure Infrastructure
#  Provisions all Azure resources via Bicep + Azure CLI
#  Runs the SQL Service Connector post-provision step
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Default parameters ─────────────────────────────────────────────────────────
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-contosouniversity}"
LOCATION="${LOCATION:-centralus}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"

# SQL Azure AD admin — auto-detected from current az login if not set
SQL_AAD_ADMIN_OBJECT_ID="${SQL_AAD_ADMIN_OBJECT_ID:-}"
SQL_AAD_ADMIN_LOGIN="${SQL_AAD_ADMIN_LOGIN:-}"

print_step() { echo -e "\n\033[36m==> $1\033[0m"; }
print_ok()   { echo -e "    \033[32m[OK] $1\033[0m"; }
print_warn() { echo -e "    \033[33m[WARN] $1\033[0m"; }

echo ""
echo "=============================================="
echo "  ContosoUniversity Infrastructure Deploy"
echo "=============================================="
echo "  Resource Group : $RESOURCE_GROUP"
echo "  Location       : $LOCATION"
echo "  Environment    : $ENVIRONMENT_NAME"
echo ""

# ── Step 1: Verify Azure CLI login ────────────────────────────────────────────
print_step "1/7  Verifying Azure CLI login"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_ok "Logged in — Subscription: $SUBSCRIPTION_ID ($SUBSCRIPTION_NAME)"

# Auto-detect SQL AAD admin if not provided
if [[ -z "$SQL_AAD_ADMIN_OBJECT_ID" ]]; then
    SQL_AAD_ADMIN_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
    SQL_AAD_ADMIN_LOGIN=$(az ad signed-in-user show --query userPrincipalName -o tsv)
    print_ok "SQL AAD Admin auto-detected: $SQL_AAD_ADMIN_LOGIN ($SQL_AAD_ADMIN_OBJECT_ID)"
fi

# ── Step 2: Validate Bicep templates ──────────────────────────────────────────
print_step "2/7  Validating Bicep templates"
az bicep build --file "$SCRIPT_DIR/main.bicep"
print_ok "Bicep validation passed"

# ── Step 3: Create resource group ─────────────────────────────────────────────
print_step "3/7  Ensuring resource group '$RESOURCE_GROUP' exists"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
print_ok "Resource group ready"

# ── Step 4: Deploy Bicep ───────────────────────────────────────────────────────
print_step "4/7  Deploying Bicep infrastructure (this may take 5-10 minutes)"
DEPLOY_JSON=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$SCRIPT_DIR/main.bicep" \
    --parameters "@$SCRIPT_DIR/main.parameters.json" \
    --parameters sqlAadAdminObjectId="$SQL_AAD_ADMIN_OBJECT_ID" \
    --parameters sqlAadAdminLogin="$SQL_AAD_ADMIN_LOGIN" \
    --parameters environmentName="$ENVIRONMENT_NAME" \
    --parameters location="$LOCATION" \
    --output json)

print_ok "Bicep deployment succeeded"

MANAGED_IDENTITY_CLIENT_ID=$(echo "$DEPLOY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['managedIdentityClientId']['value'])")
MANAGED_IDENTITY_NAME=$(echo "$DEPLOY_JSON"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['managedIdentityName']['value'])")
ACR_LOGIN_SERVER=$(echo "$DEPLOY_JSON"            | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['acrLoginServer']['value'])")
ACR_NAME=$(echo "$DEPLOY_JSON"                    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['acrName']['value'])")
SQL_SERVER_NAME=$(echo "$DEPLOY_JSON"             | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['sqlServerName']['value'])")
SQL_SERVER_FQDN=$(echo "$DEPLOY_JSON"             | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['sqlServerFqdn']['value'])")
SQL_DATABASE_NAME=$(echo "$DEPLOY_JSON"           | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['sqlDatabaseName']['value'])")
SERVICE_BUS_NAMESPACE=$(echo "$DEPLOY_JSON"       | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['serviceBusNamespace']['value'])")
SERVICE_BUS_FQDN=$(echo "$DEPLOY_JSON"            | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['serviceBusFqdn']['value'])")
STORAGE_ACCOUNT_NAME=$(echo "$DEPLOY_JSON"        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['storageAccountName']['value'])")
STORAGE_SERVICE_URI=$(echo "$DEPLOY_JSON"         | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['storageServiceUri']['value'])")
CONTAINER_APP_NAME=$(echo "$DEPLOY_JSON"          | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['containerAppName']['value'])")
CONTAINER_APP_FQDN=$(echo "$DEPLOY_JSON"          | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['containerAppFqdn']['value'])")
CONTAINER_APP_ID=$(echo "$DEPLOY_JSON"            | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['containerAppId']['value'])")

# ── Step 5: Service Connector — SQL Managed Identity ─────────────────────────
print_step "5/7  Setting up SQL Service Connector (Managed Identity)"
az extension add --name serviceconnector-passwordless --upgrade --output none 2>/dev/null || true

az containerapp connection create sql \
    --connection "sqldb_contosouniversity" \
    --source-id "$CONTAINER_APP_ID" \
    --target-resource-group "$RESOURCE_GROUP" \
    --server "$SQL_SERVER_NAME" \
    --database "$SQL_DATABASE_NAME" \
    --user-identity client-id="$MANAGED_IDENTITY_CLIENT_ID" subs-id="$SUBSCRIPTION_ID" \
    --client-type dotnet \
    --container contosouniversity \
    -y || print_warn "SQL Service Connector failed. Run manually after deployment."

print_ok "SQL Service Connector configured"

# ── Step 6: Write infra-config.md ─────────────────────────────────────────────
print_step "6/7  Writing infra-config.md"
cat > "$SCRIPT_DIR/infra-config.md" << EOF
# Azure Resources Config

## Environment Info

| Property | Value |
|----------|-------|
| Subscription ID | \`$SUBSCRIPTION_ID\` |
| Resource Group | \`$RESOURCE_GROUP\` |
| Location | \`$LOCATION\` |

## Resource List

| Resource Type | Name | Region | Config Details |
|---------------|------|---------|----------------|
| User-Assigned Managed Identity | \`$MANAGED_IDENTITY_NAME\` | $LOCATION | Client ID: \`$MANAGED_IDENTITY_CLIENT_ID\` |
| Azure Container Registry | \`$ACR_NAME\` | $LOCATION | Login server: \`$ACR_LOGIN_SERVER\` |
| Azure SQL Server | \`$SQL_SERVER_NAME\` | $LOCATION | FQDN: \`$SQL_SERVER_FQDN\` |
| Azure SQL Database | \`$SQL_DATABASE_NAME\` | $LOCATION | Server: \`$SQL_SERVER_NAME\`, DB: \`$SQL_DATABASE_NAME\` |
| Azure Service Bus Namespace | \`$SERVICE_BUS_NAMESPACE\` | $LOCATION | FQDN: \`$SERVICE_BUS_FQDN\`, Queue: ContosoUniversityNotifications |
| Azure Storage Account | \`$STORAGE_ACCOUNT_NAME\` | $LOCATION | Service URI: \`$STORAGE_SERVICE_URI\`, Container: teaching-materials |
| Azure Container App | \`$CONTAINER_APP_NAME\` | $LOCATION | FQDN: \`$CONTAINER_APP_FQDN\` |
EOF
print_ok "infra-config.md written"

# ── Step 7: Summary ────────────────────────────────────────────────────────────
print_step "7/7  Deployment complete!"
echo ""
echo "─────────────────────────────────────────────"
echo "  Container App URL  : https://$CONTAINER_APP_FQDN"
echo "  ACR Login Server   : $ACR_LOGIN_SERVER"
echo "  SQL Server FQDN    : $SQL_SERVER_FQDN"
echo "  Service Bus NS     : $SERVICE_BUS_NAMESPACE"
echo "  Storage Account    : $STORAGE_ACCOUNT_NAME"
echo "  Managed Identity   : $MANAGED_IDENTITY_NAME (clientId: $MANAGED_IDENTITY_CLIENT_ID)"
echo "─────────────────────────────────────────────"
echo ""
echo "Next step: Build and push the ContosoUniversity Docker image to $ACR_LOGIN_SERVER"
