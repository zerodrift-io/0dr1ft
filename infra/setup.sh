#!/usr/bin/env bash
# 0dr1ft — Azure Infrastructure Setup
# Mirrors the stk-engine pattern: Container Apps + ACR + Storage + Log Analytics
#
# Usage:
#   ./infra/setup.sh                    # Uses defaults (francecentral)
#   AZURE_LOCATION=westeurope ./infra/setup.sh
#
# Prerequisites:
#   - az cli installed and logged in (az login)
#   - Subscription selected (az account set -s <id>)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — all resources prefixed with 0dr1ft (matching stk-engine pattern)
# ---------------------------------------------------------------------------
PREFIX="0dr1ft"
RESOURCE_GROUP="${PREFIX}-rg"
LOCATION="${AZURE_LOCATION:-francecentral}"
ACR_NAME="${PREFIX}acr"
STORAGE_NAME="${PREFIX}data"
LOG_WORKSPACE="${PREFIX}-log"
CONTAINER_ENV="${PREFIX}-env"

echo "==> 0dr1ft Azure Infrastructure Setup"
echo "    Resource Group:    $RESOURCE_GROUP"
echo "    Location:          $LOCATION"
echo "    Container Registry: $ACR_NAME"
echo "    Storage Account:   $STORAGE_NAME"
echo "    Log Analytics:     $LOG_WORKSPACE"
echo "    Container Apps Env: $CONTAINER_ENV"
echo ""

# ---------------------------------------------------------------------------
# 1. Resource Group
# ---------------------------------------------------------------------------
echo "==> Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

# ---------------------------------------------------------------------------
# 2. Azure Container Registry (ACR)
# ---------------------------------------------------------------------------
echo "==> Creating container registry: $ACR_NAME"
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled true \
  --output none

# ---------------------------------------------------------------------------
# 3. Storage Account (persistent data)
# ---------------------------------------------------------------------------
echo "==> Creating storage account: $STORAGE_NAME"
az storage account create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STORAGE_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output none

# Create file share for 0dr1ft state persistence
echo "==> Creating file share: 0dr1ftdata"
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_NAME" \
  --query '[0].value' -o tsv)

az storage share create \
  --name "0dr1ftdata" \
  --account-name "$STORAGE_NAME" \
  --account-key "$STORAGE_KEY" \
  --quota 5 \
  --output none

# ---------------------------------------------------------------------------
# 4. Log Analytics Workspace
# ---------------------------------------------------------------------------
echo "==> Creating Log Analytics workspace: $LOG_WORKSPACE"
az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_WORKSPACE" \
  --location "$LOCATION" \
  --output none

LOG_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_WORKSPACE" \
  --query customerId -o tsv)

LOG_WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_WORKSPACE" \
  --query primarySharedKey -o tsv)

# ---------------------------------------------------------------------------
# 5. Container Apps Environment
# ---------------------------------------------------------------------------
echo "==> Creating Container Apps environment: $CONTAINER_ENV"
az containerapp env create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_ENV" \
  --location "$LOCATION" \
  --logs-workspace-id "$LOG_WORKSPACE_ID" \
  --logs-workspace-key "$LOG_WORKSPACE_KEY" \
  --output none

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Infrastructure created successfully!"
echo ""
echo "Resources in $RESOURCE_GROUP:"
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --output table \
  --query "[].{Name:name, Type:type}"
echo ""
echo "Next steps:"
echo "  1. Build and push image:  az acr build -r $ACR_NAME -t 0dr1ft:latest ."
echo "  2. Deploy container app:  see infra/deploy-app.sh"
echo "  3. Set secrets:           see .github/workflows/deploy.yml"
