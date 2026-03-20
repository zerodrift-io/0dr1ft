#!/usr/bin/env bash
# ── 0dr1ft — Azure Container Apps Deployment ─────────────────────────────────
# Déploie le gateway 0dr1ft sur Azure Container Apps
# Pattern calqué sur stk-engine (zerodrift-io/stk-engine)
#
# Prérequis :
#   - Azure CLI installé et connecté (az login)
#   - Dockerfile présent à la racine du repo
#
# Usage :
#   chmod +x infra/azure/deploy.sh
#   ./infra/azure/deploy.sh
#
# Variables d'environnement optionnelles :
#   DRIFT_RG        — Resource Group name        (default: 0dr1ft-rg)
#   DRIFT_LOCATION  — Azure region               (default: westeurope)
#   DRIFT_ACR       — Container Registry name    (default: 0dr1ftacr)
#   DRIFT_APP       — Container App name         (default: 0dr1ft)
#   DRIFT_ENV       — Container App Env name     (default: 0dr1ft-env)
#   DRIFT_STORAGE   — Storage Account name       (default: 0dr1ftdata)
#   OPENCLAW_GATEWAY_TOKEN — API token (required)

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
RG="${DRIFT_RG:-0dr1ft-rg}"
LOCATION="${DRIFT_LOCATION:-westeurope}"
ACR="${DRIFT_ACR:-0dr1ftacr}"
APP="${DRIFT_APP:-0dr1ft}"
ENV_NAME="${DRIFT_ENV:-0dr1ft-env}"
STORAGE_ACCOUNT="${DRIFT_STORAGE:-0dr1ftdata}"
SHARE_NAME="0dr1ftdata"
IMAGE="${ACR}.azurecr.io/0dr1ft:latest"

echo "╔══════════════════════════════════════════════════╗"
echo "║  0dr1ft — Azure Container Apps Deploy            ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Resource Group : $RG"
echo "║  Location       : $LOCATION"
echo "║  ACR            : $ACR"
echo "║  App            : $APP"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── 1. Resource Group ─────────────────────────────────────────────────────────
echo "▶ [1/7] Creating Resource Group..."
az group create --name "$RG" --location "$LOCATION" --output none

# ── 2. Container Registry ─────────────────────────────────────────────────────
echo "▶ [2/7] Creating Container Registry..."
az acr create --resource-group "$RG" --name "$ACR" --sku Basic --admin-enabled true --output none

# ── 3. Build & Push image ─────────────────────────────────────────────────────
echo "▶ [3/7] Building and pushing Docker image..."
az acr build --registry "$ACR" --image 0dr1ft:latest --file Dockerfile .

# ── 4. Storage Account + File Share (config persistence) ──────────────────────
echo "▶ [4/7] Creating Storage Account + File Share..."
az storage account create \
    --resource-group "$RG" \
    --name "$STORAGE_ACCOUNT" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --output none

STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RG" \
    --account-name "$STORAGE_ACCOUNT" \
    --query "[0].value" -o tsv)

az storage share create \
    --name "$SHARE_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --output none

# ── 5. Log Analytics Workspace ────────────────────────────────────────────────
echo "▶ [5/7] Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
    --resource-group "$RG" \
    --workspace-name "0dr1ft-log" \
    --location "$LOCATION" \
    --output none

LOG_WS_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG" \
    --workspace-name "0dr1ft-log" \
    --query customerId -o tsv)

LOG_WS_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "$RG" \
    --workspace-name "0dr1ft-log" \
    --query primarySharedKey -o tsv)

# ── 5b. Container Apps Environment ────────────────────────────────────────────
az containerapp env create \
    --name "$ENV_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --logs-workspace-id "$LOG_WS_ID" \
    --logs-workspace-key "$LOG_WS_KEY" \
    --output none

# Mount Azure Files for config/data persistence
az containerapp env storage set \
    --name "$ENV_NAME" \
    --resource-group "$RG" \
    --storage-name 0dr1ftfiles \
    --azure-file-account-name "$STORAGE_ACCOUNT" \
    --azure-file-account-key "$STORAGE_KEY" \
    --azure-file-share-name "$SHARE_NAME" \
    --access-mode ReadWrite \
    --output none

# ── 6. Get ACR credentials ────────────────────────────────────────────────────
ACR_USER=$(az acr credential show --name "$ACR" --query "username" -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR" --query "passwords[0].value" -o tsv)

# ── 7. Deploy Container App ───────────────────────────────────────────────────
echo "▶ [6/7] Deploying Container App..."

GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"
if [ -z "$GATEWAY_TOKEN" ]; then
    echo "⚠ OPENCLAW_GATEWAY_TOKEN not set — gateway will start unauthenticated"
fi

az containerapp create \
    --name "$APP" \
    --resource-group "$RG" \
    --environment "$ENV_NAME" \
    --image "$IMAGE" \
    --registry-server "${ACR}.azurecr.io" \
    --registry-username "$ACR_USER" \
    --registry-password "$ACR_PASS" \
    --target-port 3000 \
    --ingress external \
    --min-replicas 0 \
    --max-replicas 1 \
    --cpu 0.5 \
    --memory 1Gi \
    --env-vars \
        "OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}" \
        "NODE_ENV=production" \
    --output none

# Patch: add Azure Files volume mount for /app/data persistence
YAML_PATH=$(mktemp /tmp/0dr1ft-containerapp-XXXXXX.yaml)
cat > "$YAML_PATH" <<YAMLEOF
properties:
  template:
    volumes:
      - name: 0dr1ftdata
        storageName: 0dr1ftfiles
        storageType: AzureFile
    containers:
      - name: 0dr1ft
        image: $IMAGE
        resources:
          cpu: 0.5
          memory: 1Gi
        env:
          - name: OPENCLAW_GATEWAY_TOKEN
            value: "${GATEWAY_TOKEN}"
          - name: NODE_ENV
            value: "production"
        volumeMounts:
          - volumeName: 0dr1ftdata
            mountPath: /app/data
YAMLEOF

az containerapp update \
    --name "$APP" \
    --resource-group "$RG" \
    --yaml "$YAML_PATH" \
    --output none
rm -f "$YAML_PATH"
echo "  ✓ Azure Files mounted at /app/data (config persistence)"

# ── 7. Get URL ────────────────────────────────────────────────────────────────
echo "▶ [7/7] Getting application URL..."
FQDN=$(az containerapp show \
    --name "$APP" \
    --resource-group "$RG" \
    --query "properties.configuration.ingress.fqdn" -o tsv)

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  ✅ Deployment complete!                         ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  URL: https://$FQDN"
echo "║"
echo "║  Set OPENCLAW_GATEWAY_TOKEN to restrict access.  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Test: curl https://$FQDN/api/health"
