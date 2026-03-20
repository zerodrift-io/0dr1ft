# 0dr1ft — ZeroDrift AI Automation

> Zero Error. Zero Drift. Built on [OpenClaw](https://github.com/openclaw/openclaw).

**0dr1ft** is ZeroDrift's AI automation platform — a custom layer on top of OpenClaw
that powers autonomous agent crews for specialized tasks.

## Architecture

```
┌─────────────────────────────────────────────┐
│                  0dr1ft                      │
│  ┌───────────┐  ┌──────────┐  ┌───────────┐ │
│  │ Telegram  │  │ Discord  │  │  M365     │ │
│  │ Channel   │  │ Channel  │  │  Graph    │ │
│  └─────┬─────┘  └────┬─────┘  └─────┬─────┘ │
│        └──────┬──────┘──────────────┘        │
│         ┌─────▼──────┐                       │
│         │  OpenClaw   │  (upstream engine)    │
│         │  Gateway    │                       │
│         └─────┬──────┘                       │
│         ┌─────▼──────┐                       │
│         │ Groq Llama │  (default provider)   │
│         │   3.3 70B  │                       │
│         └────────────┘                       │
└─────────────────────────────────────────────┘
```

## Stack

| Component | Technology |
|-----------|-----------|
| Engine | [OpenClaw](https://github.com/openclaw/openclaw) (upstream, unmodified) |
| Default LLM | Groq Llama 3.3 70B |
| Runtime | Node.js 22+, Docker |
| Channels | Telegram, Discord, M365 Graph API |
| Infra | Azure (prefixed `0dr1ft-*`) |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/zerodrift-io/cave-bot.git 0dr1ft
cd 0dr1ft

# 2. Configure
cp .env.0dr1ft.example .env.0dr1ft
# Edit .env.0dr1ft with your API keys

# 3. Install & build
pnpm install
pnpm build

# 4. Run
node 0dr1ft.mjs onboard
# or via Docker:
docker compose -f docker-compose.yml -f docker-compose.0dr1ft.yml up -d
```

## Docker Deployment

```bash
# Build the image
docker build -t 0dr1ft:local .

# Run with 0dr1ft overlay
OPENCLAW_IMAGE=0dr1ft:local \
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32) \
OPENCLAW_CONFIG_DIR=~/.openclaw \
OPENCLAW_WORKSPACE_DIR=~/.openclaw/workspace \
docker compose -f docker-compose.yml -f docker-compose.0dr1ft.yml up -d
```

## Azure Deployment

> Infrastructure-as-Code coming soon (Bicep templates, prefixed `0dr1ft-*`).
> Reference: stk-engine deployment pattern.

Resource naming convention:
- Resource Group: `0dr1ft-rg`
- Container Instance: `0dr1ft-gateway`
- Storage Account: `0dr1ftstorage`
- Key Vault: `0dr1ft-kv`

## Project Structure

```
.
├── 0dr1ft.mjs                 # 0dr1ft entry point (wraps openclaw.mjs)
├── .env.0dr1ft.example         # 0dr1ft-specific environment template
├── docker-compose.0dr1ft.yml   # Docker overlay for 0dr1ft deployment
├── docs/                       # Documentation
│   └── 0dr1ft/                 # 0dr1ft-specific docs
│       ├── ARCHITECTURE.md     # Architecture decisions
│       └── SETUP.md            # Setup guide
├── openclaw.mjs                # OpenClaw entry point (upstream)
├── src/                        # OpenClaw source (upstream, unmodified)
├── extensions/                 # OpenClaw extensions (upstream)
└── skills/                     # OpenClaw skills (upstream)
```

## Upstream Sync

0dr1ft is a rebrand layer — the OpenClaw core (`src/`, `extensions/`, `skills/`) stays
unmodified. To pull upstream updates:

```bash
git remote add upstream https://github.com/openclaw/openclaw.git
git fetch upstream
git merge upstream/main
```

The 0dr1ft layer (`0dr1ft.mjs`, `docker-compose.0dr1ft.yml`, `.env.0dr1ft.*`, `docs/0dr1ft/`)
is isolated from upstream, so merges should be conflict-free.

## Contributing

- GitHub is the source of truth
- All changes documented via issues and PRs
- Follow [OpenClaw contribution guidelines](CONTRIBUTING.md) for core changes

## License

MIT — see [LICENSE](LICENSE)

---

**ZeroDrift** — Paris, France | [zerodrift-io](https://github.com/zerodrift-io)
