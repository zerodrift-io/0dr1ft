# 0dr1ft

> ZeroDrift's AI gateway — multi-channel, self-hosted, zero vendor lock-in.

Built on [OpenClaw](https://github.com/openclaw/openclaw) (upstream). The `0dr1ft` layer adds ZeroDrift-specific config, Azure deployment, and identity — without modifying upstream source code.

## Quick Start

```bash
# Install deps
pnpm install

# Configure
cp .env.0dr1ft.example .env.0dr1ft
# Edit .env.0dr1ft with your API keys

# Run
node 0dr1ft.mjs
# or: pnpm 0dr1ft
```

## Docker

```bash
docker compose -f docker-compose.yml -f docker-compose.0dr1ft.yml up
```

Containers are named `0dr1ft-gateway` and `0dr1ft-db`.

## Azure Deployment

### First deploy (provision infra + app)

```bash
az login
export OPENCLAW_GATEWAY_TOKEN=<your-token>
chmod +x infra/azure/deploy.sh
./infra/azure/deploy.sh
```

Provisions:
| Resource | Name | Type |
|---|---|---|
| Resource Group | `0dr1ft-rg` | - |
| Container Registry | `0dr1ftacr` | Basic ACR |
| Storage Account | `0dr1ftdata` | Standard_LRS |
| File Share | `0dr1ftdata` | Azure Files |
| Log Analytics | `0dr1ft-log` | Workspace |
| Container Apps Env | `0dr1ft-env` | - |
| Container App | `0dr1ft` | 0.5 vCPU / 1 Gi |

### CI/CD (automatic on push to main)

The workflow `.github/workflows/deploy-azure.yml` triggers on every push to `main`/`master` that touches app or infra files.

**Required GitHub secrets:**
- `AZURE_CREDENTIALS` — Service principal JSON (`az ad sp create-for-rbac`)
- `OPENCLAW_GATEWAY_TOKEN` — Gateway API token

### Pattern

Mirrors `zerodrift-io/stk-engine` exactly:
- ACR build → Container App update → health check
- Azure Files volume at `/app/data` for persistence across restarts

## Architecture

```
0dr1ft.mjs          ← ZeroDrift entry point (loads .env.0dr1ft)
openclaw.mjs        ← Upstream OpenClaw entry point (unchanged)
src/                ← Upstream source (unchanged)
extensions/         ← Upstream extensions (unchanged)
infra/azure/        ← ZeroDrift Azure deployment
  deploy.sh         ← Provision + deploy script
.github/workflows/
  deploy-azure.yml  ← CI/CD pipeline
docs/0dr1ft/        ← ZeroDrift documentation
```

**Principle:** upstream files are never modified. ZeroDrift changes live in dedicated files. Merges from upstream remain conflict-free.

## Updating from Upstream

```bash
git remote add upstream https://github.com/openclaw/openclaw.git
git fetch upstream
git merge upstream/main
# Resolve only if upstream touches our files (0dr1ft.mjs, infra/, docs/0dr1ft/)
```

## Docs

- [Architecture](docs/0dr1ft/ARCHITECTURE.md)
- [Setup & Deployment](docs/0dr1ft/SETUP.md)
- [OpenClaw docs](https://docs.openclaw.ai)
