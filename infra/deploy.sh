#!/usr/bin/env bash
# =============================================================
# deploy.sh — ContosoUniversity Azure Infrastructure
# Deploys Bicep IaC and runs Service Connector post-provision
#
# Usage:
#   ./deploy.sh -g <resource-group> [-l <location>] \
#               [-e <env-name>] [-u <sql-login>] [-p <sql-password>]
#
# Example:
#   ./deploy.sh -g rg-contosouniversity -p "MyP@ssw0rd!"
# =============================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ─────────────────────────────────────────────────
RESOURCE_GROUP=""
LOCATION="centralus"
ENVIRONMENT_NAME="contosouniversity"
SQL_ADMIN_LOGIN="sqladmin"
SQL_ADMIN_PASSWORD=""

# ── Parse arguments ───────────────────────────────────────────
while getopts "g:l:e:u:p:h" opt; do
  case $opt in
    g) RESOURCE_GROUP="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    e) ENVIRONMENT_NAME="$OPTARG" ;;
    u) SQL_ADMIN_LOGIN="$OPTARG" ;;
    p) SQL_ADMIN_PASSWORD="$OPTARG" ;;
    h) echo "Usage: $0 -g <resource-group> [-l <location>] [-e <env-name>] [-u <sql-login>] [-p <sql-password>]"; exit 0 ;;
    *) echo "Unknown option: -$opt"; exit 1 ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "ERROR: -g <resource-group> is required."
  exit 1
fi

if [[ -z "$SQL_ADMIN_PASSWORD" ]]; then
  read -rsp "Enter SQL administrator password: " SQL_ADMIN_PASSWORD
  echo ""
fi

# ── Validate Azure login ──────────────────────────────────────
echo "Verifying Azure login..."
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "  Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# ── Create resource group if needed ──────────────────────────
echo ""
echo "Ensuring resource group '$RESOURCE_GROUP' in '$LOCATION'..."
if [[ $(az group exists --name "$RESOURCE_GROUP") == "false" ]]; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
  echo "  Resource group created."
else
  echo "  Resource group already exists."
fi

# ── Deploy Bicep infrastructure ───────────────────────────────
DEPLOYMENT_NAME="contosouniversity-infra-$(date +%Y%m%d%H%M%S)"
echo ""
echo "Deploying Bicep infrastructure (deployment: $DEPLOYMENT_NAME)..."

DEPLOYMENT_JSON=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$SCRIPT_DIR/main.bicep" \
  --parameters "$SCRIPT_DIR/main.parameters.json" \
  --parameters environmentName="$ENVIRONMENT_NAME" \
  --parameters location="$LOCATION" \
  --parameters sqlAdminLogin="$SQL_ADMIN_LOGIN" \
  --parameters sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
  --name "$DEPLOYMENT_NAME" \
  --output json)

CONTAINER_APP_NAME=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.containerAppName.value')
CONTAINER_APP_FQDN=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.containerAppFqdn.value')
SQL_SERVER_NAME=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.sqlServerName.value')
SQL_SERVER_FQDN=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.sqlServerFqdn.value')
SQL_DATABASE_NAME=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.sqlDatabaseName.value')
ACR_LOGIN_SERVER=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.acrLoginServer.value')
ACR_NAME=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.acrName.value')
MANAGED_IDENTITY_CLIENT_ID=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.managedIdentityClientId.value')
MANAGED_IDENTITY_NAME=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.managedIdentityName.value')
SERVICE_BUS_NAMESPACE=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.serviceBusNamespace.value')
STORAGE_ACCOUNT_NAME=$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.outputs.storageAccountName.value')

echo ""
echo "=== Bicep Deployment Complete ==="
echo "  Container App   : https://$CONTAINER_APP_FQDN"
echo "  SQL Server      : $SQL_SERVER_FQDN"
echo "  ACR             : $ACR_LOGIN_SERVER"
echo "  Service Bus     : $SERVICE_BUS_NAMESPACE"
echo "  Storage Account : $STORAGE_ACCOUNT_NAME"
echo "  Managed Identity: $MANAGED_IDENTITY_NAME (clientId: $MANAGED_IDENTITY_CLIENT_ID)"

# ── Post-provision: Service Connector for SQL + Managed Identity
echo ""
echo "Installing Service Connector extension..."
az extension add --name serviceconnector-passwordless --upgrade --only-show-errors || true

echo "Configuring SQL Database connection via Service Connector..."
CONTAINER_APP_ID=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

az containerapp connection create sql \
  --connection "contosouniversity_sql" \
  --source-id "$CONTAINER_APP_ID" \
  --tg "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --database "$SQL_DATABASE_NAME" \
  --user-identity "client-id=$MANAGED_IDENTITY_CLIENT_ID" "subs-id=$SUBSCRIPTION_ID" \
  --client-type dotnet \
  -c "contosouniversity" \
  -y || {
    echo "WARNING: Service Connector step failed. Run manually after deployment."
  }

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ContosoUniversity Infrastructure Ready "
echo "========================================"
echo "  Container App URL  : https://$CONTAINER_APP_FQDN"
echo "  SQL Server         : $SQL_SERVER_FQDN"
echo "  ACR Login Server   : $ACR_LOGIN_SERVER"
echo "  Service Bus NS     : $SERVICE_BUS_NAMESPACE"
echo "  Storage Account    : $STORAGE_ACCOUNT_NAME"
echo ""
echo "Next step: Run task 008 to build & deploy the container image."
