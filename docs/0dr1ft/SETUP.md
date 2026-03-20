# 0dr1ft — Setup Guide

## Prerequisites

- Node.js 22+
- pnpm 10+
- Docker (for containerized deployment)
- Azure CLI (for Azure deployment, optional)

## Local Development

### 1. Clone the repository

```bash
git clone https://github.com/zerodrift-io/cave-bot.git 0dr1ft
cd 0dr1ft
```

### 2. Install dependencies

```bash
pnpm install
```

### 3. Build

```bash
pnpm build
```

### 4. Configure

```bash
cp .env.0dr1ft.example .env.0dr1ft
```

Edit `.env.0dr1ft` and set at minimum:
- `OPENCLAW_GATEWAY_TOKEN` — random token for gateway auth
- One AI provider key (e.g., `GROQ_API_KEY`, `OPENAI_API_KEY`)

### 5. Run the onboarding wizard

```bash
node 0dr1ft.mjs onboard
```

This walks you through channel setup (Telegram, Discord, etc.).

### 6. Start the gateway

```bash
node 0dr1ft.mjs gateway run
```

## Docker Deployment

### Build

```bash
docker build -t 0dr1ft:local .
```

### Run

```bash
cp .env.0dr1ft.example .env.0dr1ft
# Edit .env.0dr1ft with your values

export OPENCLAW_IMAGE=0dr1ft:local
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
export OPENCLAW_CONFIG_DIR=~/.openclaw
export OPENCLAW_WORKSPACE_DIR=~/.openclaw/workspace

docker compose -f docker-compose.yml -f docker-compose.0dr1ft.yml up -d
```

### Verify

```bash
# Check containers
docker ps --filter label=app=0dr1ft

# Health check
curl http://localhost:18789/healthz

# Logs
docker logs 0dr1ft-gateway
```

## Azure Deployment

> Bicep templates coming soon. Resource prefix: `0dr1ft-*`.

Target architecture:
- **Azure Container Instance** for the gateway
- **Azure Storage Account** for persistent state
- **Azure Key Vault** for secrets
- **Azure Container Registry** for images

## Upstream Sync

To pull updates from OpenClaw:

```bash
# Add upstream (first time only)
git remote add upstream https://github.com/openclaw/openclaw.git

# Fetch and merge
git fetch upstream
git merge upstream/main
```

The 0dr1ft layer files are isolated, so merges should be conflict-free.

## Channels

Configure channels via the onboarding wizard or directly in `~/.openclaw/openclaw.json`:

| Channel | Setup |
|---------|-------|
| Telegram | `TELEGRAM_BOT_TOKEN` in `.env.0dr1ft` |
| Discord | `DISCORD_BOT_TOKEN` in `.env.0dr1ft` |
| M365 Teams | Via `extensions/msteams` |

See [OpenClaw channel docs](https://docs.openclaw.ai/channels) for full list.
