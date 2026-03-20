#!/usr/bin/env bash
# 0dr1ft — Deploy Container App
# Creates or updates the 0dr1ft gateway as an Azure Container App.
#
# Usage:
#   ./infra/deploy-app.sh                          # Deploy latest
#   IMAGE_TAG=v2026.3.2 ./infra/deploy-app.sh      # Deploy specific version
#
# Prerequisites:
#   - infra/setup.sh has been run
#   - Image pushed to ACR (az acr build -r 0dr1ftacr -t 0dr1ft:latest .)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PREFIX="0dr1ft"
RESOURCE_GROUP="${PREFIX}-rg"
ACR_NAME="${PREFIX}acr"
STORAGE_NAME="${PREFIX}data"
CONTAINER_ENV="${PREFIX}-env"
APP_NAME="${PREFIX}-gateway"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE="${ACR_NAME}.azurecr.io/${PREFIX}:${IMAGE_TAG}"

# Gateway token — read from env or generate
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}"

echo "==> Deploying 0dr1ft gateway"
echo "    App:   $APP_NAME"
echo "    Image: $IMAGE"
echo ""

# ---------------------------------------------------------------------------
# Get ACR credentials
# ---------------------------------------------------------------------------
ACR_SERVER="${ACR_NAME}.azurecr.io"
ACR_USERNAME=$(az acr credential show -n "$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show -n "$ACR_NAME" --query "passwords[0].value" -o tsv)

# ---------------------------------------------------------------------------
# Get storage key for volume mount
# ---------------------------------------------------------------------------
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_NAME" \
  --query '[0].value' -o tsv)

# ---------------------------------------------------------------------------
# Add storage to Container Apps environment
# ---------------------------------------------------------------------------
echo "==> Configuring storage mount"
az containerapp env storage set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_ENV" \
  --storage-name "0dr1ftfiles" \
  --azure-file-account-name "$STORAGE_NAME" \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name "0dr1ftdata" \
  --access-mode ReadWrite \
  --output none 2>/dev/null || true

# ---------------------------------------------------------------------------
# Create or update Container App
# ---------------------------------------------------------------------------
echo "==> Creating/updating container app: $APP_NAME"
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --environment "$CONTAINER_ENV" \
  --image "$IMAGE" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 18789 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 1 \
  --memory 2Gi \
  --env-vars \
    "OPENCLAW_GATEWAY_TOKEN=secretref:gateway-token" \
    "OPENCLAW_GATEWAY_MODE=local" \
    "HOME=/home/node" \
    "TERM=xterm-256color" \
  --secrets "gateway-token=${GATEWAY_TOKEN}" \
  --command "node" "dist/index.js" "gateway" "--bind" "lan" "--port" "18789" "--allow-unconfigured" \
  --output none 2>/dev/null || \
az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --image "$IMAGE" \
  --output none

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
FQDN=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo ""
echo "==> Deployment complete!"
echo "    URL:   https://${FQDN}"
echo "    Health: https://${FQDN}/healthz"
echo ""
echo "    Gateway token: $GATEWAY_TOKEN"
echo "    (store this securely — you'll need it for CLI/channel access)"
