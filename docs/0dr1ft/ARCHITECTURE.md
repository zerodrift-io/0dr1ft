# 0dr1ft — Architecture

## Overview

0dr1ft is a **rebrand layer** on top of [OpenClaw](https://github.com/openclaw/openclaw),
the open-source multi-channel AI gateway. This approach gives us:

- Full OpenClaw feature set without forking
- Clean upstream merge path (no conflicts)
- ZeroDrift-specific configuration and branding
- Independent deployment pipeline (Azure)

## Layer Model

```
┌──────────────────────────────────────────────┐
│ Layer 3: Deployment (Azure)                   │
│   docker-compose.0dr1ft.yml                   │
│   infra/0dr1ft-*.bicep (planned)              │
│   .github/workflows/deploy.yml (planned)      │
├──────────────────────────────────────────────┤
│ Layer 2: Configuration (0dr1ft)               │
│   0dr1ft.mjs — entry point                    │
│   .env.0dr1ft — environment overrides         │
│   Container labels: app=0dr1ft                │
├──────────────────────────────────────────────┤
│ Layer 1: Engine (OpenClaw — upstream)          │
│   src/ — core source (unmodified)             │
│   extensions/ — channel plugins               │
│   skills/ — agent capabilities                │
│   openclaw.mjs — original entry point         │
└──────────────────────────────────────────────┘
```

## Key Decisions

### ADR-001: Rebrand layer, not fork

**Context:** OpenClaw is a large project (~511K LOC) with active development.
Forking would create maintenance burden and drift risk.

**Decision:** Create a thin wrapper layer (`0dr1ft.mjs`, config files, Docker overlay)
that delegates to OpenClaw without modifying its source.

**Consequence:** Upstream updates merge cleanly. 0dr1ft-specific files are isolated
in dedicated paths (`0dr1ft.*`, `docs/0dr1ft/`, `docker-compose.0dr1ft.yml`).

### ADR-002: Groq Llama 3.3 70B as default provider

**Context:** ZeroDrift stack uses Groq for fast inference with Llama 3.3 70B.

**Decision:** Pre-configure Groq as the default provider in `.env.0dr1ft.example`.
Other providers (OpenAI, Anthropic) remain available via OpenClaw's multi-provider support.

### ADR-003: Azure deployment with 0dr1ft prefix

**Context:** Production deployment targets Azure, following stk-engine patterns.

**Decision:** All Azure resources prefixed with `0dr1ft-` for clear identification.
Infrastructure defined as Bicep templates (planned).

**Resource naming:**
| Resource | Name |
|----------|------|
| Resource Group | `0dr1ft-rg` |
| Container Instance | `0dr1ft-gateway` |
| Storage Account | `0dr1ftstorage` |
| Key Vault | `0dr1ft-kv` |
| Container Registry | `0dr1ftcr` |

## File Ownership

| Path | Owner | Modify? |
|------|-------|---------|
| `0dr1ft.mjs` | ZeroDrift | Yes |
| `.env.0dr1ft*` | ZeroDrift | Yes |
| `docker-compose.0dr1ft.yml` | ZeroDrift | Yes |
| `docs/0dr1ft/` | ZeroDrift | Yes |
| `README.md` | ZeroDrift | Yes |
| `src/` | OpenClaw upstream | No |
| `extensions/` | OpenClaw upstream | No |
| `skills/` | OpenClaw upstream | No |
| `openclaw.mjs` | OpenClaw upstream | No |
