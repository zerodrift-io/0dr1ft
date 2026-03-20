# 0dr1ft — Architecture

## Layer Model

```
┌─────────────────────────────────────────┐
│           0dr1ft layer                  │
│  0dr1ft.mjs  .env.0dr1ft  infra/azure/  │
│  docker-compose.0dr1ft.yml  docs/0dr1ft/│
├─────────────────────────────────────────┤
│           OpenClaw upstream             │
│  src/  extensions/  skills/  packages/  │
│  openclaw.mjs  Dockerfile               │
└─────────────────────────────────────────┘
```

The 0dr1ft layer sits above OpenClaw. Upstream files are **never modified** — all ZeroDrift customisations live in dedicated files.

## File Ownership

| File/Dir | Owner | Notes |
|---|---|---|
| `0dr1ft.mjs` | ZeroDrift | Entry point — loads `.env.0dr1ft`, delegates to `openclaw.mjs` |
| `.env.0dr1ft` | ZeroDrift | Secrets (gitignored) |
| `.env.0dr1ft.example` | ZeroDrift | Template committed to git |
| `docker-compose.0dr1ft.yml` | ZeroDrift | Overlay — renames containers to `0dr1ft-*` |
| `infra/azure/` | ZeroDrift | Azure provisioning + deploy scripts |
| `.github/workflows/deploy-azure.yml` | ZeroDrift | CI/CD pipeline |
| `docs/0dr1ft/` | ZeroDrift | This documentation |
| `src/` | Upstream | Never touch |
| `extensions/` | Upstream | Never touch |
| `skills/` | Upstream | Never touch |
| `packages/` | Upstream | Never touch |
| `openclaw.mjs` | Upstream | Never touch |
| `Dockerfile` | Upstream | Never touch |

## Azure Infrastructure

Mirrors `zerodrift-io/stk-engine` pattern:

| Resource | Name | Equivalent in stk-engine |
|---|---|---|
| Resource Group | `0dr1ft-rg` | `stk-engine-rg` |
| Container Registry | `0dr1ftacr` | `stkengineacr` |
| Storage Account | `0dr1ftdata` | `stkenginedata` |
| Log Analytics | `0dr1ft-log` | `workspace-stkenginerg*` |
| Container Apps Env | `0dr1ft-env` | `stk-engine-env` |
| Container App | `0dr1ft` | `stk-engine` |

## Upstream Merge Strategy

1. `git fetch upstream`
2. `git merge upstream/main`
3. Conflicts possible only if upstream touches: `0dr1ft.mjs`, `infra/`, `docs/0dr1ft/`, `.github/workflows/deploy-azure.yml`
4. Everything else merges cleanly

## ADRs

### ADR-001 — Rebrand as overlay, not fork

**Decision:** Keep OpenClaw source intact. Add 0dr1ft files alongside.

**Rationale:** Upstream merges must remain conflict-free. Modifying `src/` would create perpetual merge conflicts on every upstream update.

**Consequences:** 0dr1ft identity is thin (entry point + env file). Deeper customisations require PRs upstream or extension packages.

### ADR-002 — Azure as deployment target

**Decision:** Use Azure Container Apps, mirroring stk-engine pattern.

**Rationale:** Organisation already uses Azure (stk-engine-rg visible in portal). Consistent infra reduces cognitive overhead.

**Consequences:** Requires `AZURE_CREDENTIALS` secret. Free tier Container Apps scales to zero (min-replicas: 0).

### ADR-003 — GitHub as source of truth

**Decision:** All config, infra, and docs committed. `.env.0dr1ft` gitignored, `.env.0dr1ft.example` committed.

**Rationale:** ZeroDrift principle: GitHub = source of truth. No config lives only on a machine.
