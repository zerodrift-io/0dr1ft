# 0dr1ft — Setup & Deployment Guide

## Prerequisites

- Node 22+, pnpm, git
- Azure CLI (`az`) — for cloud deployment
- Docker — for local container testing

## Local Development

```bash
# 1. Clone
git clone https://github.com/zerodrift-io/cave-bot.git
cd cave-bot

# 2. Install deps
pnpm install

# 3. Configure
cp .env.0dr1ft.example .env.0dr1ft
# Fill in at minimum: GROQ_API_KEY or ANTHROPIC_API_KEY

# 4. Run
node 0dr1ft.mjs
```

The `0dr1ft.mjs` entry point loads `.env.0dr1ft` (non-overriding — shell env vars win), then starts the OpenClaw gateway.

## Docker (local)

```bash
# Build + start with 0dr1ft overlay
docker compose -f docker-compose.yml -f docker-compose.0dr1ft.yml up --build

# Containers:
#   0dr1ft-gateway   (gateway process)
#   0dr1ft-db        (database, if applicable)
```

## Azure — First Deploy

Run once to provision all Azure resources.

```bash
# Login
az login

# Required
export OPENCLAW_GATEWAY_TOKEN=<random-secret>

# Optional overrides (defaults shown)
export DRIFT_RG=0dr1ft-rg
export DRIFT_LOCATION=westeurope
export DRIFT_ACR=0dr1ftacr
export DRIFT_APP=0dr1ft
export DRIFT_ENV=0dr1ft-env
export DRIFT_STORAGE=0dr1ftdata

chmod +x infra/azure/deploy.sh
./infra/azure/deploy.sh
```

This provisions (in order):
1. Resource Group `0dr1ft-rg`
2. Container Registry `0dr1ftacr` (Basic, admin enabled)
3. Docker build + push via ACR Tasks
4. Storage Account `0dr1ftdata` + File Share `0dr1ftdata`
5. Log Analytics Workspace `0dr1ft-log`
6. Container Apps Environment `0dr1ft-env`
7. Container App `0dr1ft` (0.5 vCPU / 1 Gi, scale-to-zero)
8. Azure Files volume mounted at `/app/data`

## Azure — CI/CD Setup

After the first deploy, subsequent deploys run automatically via GitHub Actions.

### 1. Create Service Principal

```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "0dr1ft-github-actions" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/0dr1ft-rg \
  --sdk-auth
```

Copy the JSON output.

### 2. Add GitHub Secrets

In `Settings > Secrets and variables > Actions`:

| Secret | Value |
|---|---|
| `AZURE_CREDENTIALS` | JSON from step 1 |
| `OPENCLAW_GATEWAY_TOKEN` | Your gateway token |

### 3. Push to main

The workflow `.github/workflows/deploy-azure.yml` triggers automatically on push to `main`/`master` when app or infra files change.

Pipeline: CI checks → ACR build → Container App update → health check

## Updating from OpenClaw Upstream

```bash
# Add upstream remote (once)
git remote add upstream https://github.com/openclaw/openclaw.git

# Merge upstream changes
git fetch upstream
git merge upstream/main

# Push (conflicts are rare — only if upstream touches 0dr1ft-owned files)
git push
```

## Troubleshooting

**Gateway not starting:**
```bash
# Check logs
az containerapp logs show --name 0dr1ft --resource-group 0dr1ft-rg --follow
```

**Health check:**
```bash
FQDN=$(az containerapp show --name 0dr1ft --resource-group 0dr1ft-rg --query "properties.configuration.ingress.fqdn" -o tsv)
curl https://$FQDN/api/health
```

**Re-deploy without reprovisioning:**
```bash
az acr build --registry 0dr1ftacr --image 0dr1ft:latest --file Dockerfile .
az containerapp update --name 0dr1ft --resource-group 0dr1ft-rg \
  --image 0dr1ftacr.azurecr.io/0dr1ft:latest
```
