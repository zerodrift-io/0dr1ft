# 0dr1ft — High-Level Design

> **Repo :** https://github.com/zerodrift-io/0dr1ft
> **Upstream :** https://github.com/openclaw/openclaw (OpenClaw)
> **Stratégie :** rebrand layer — upstream inchangé, couche ZeroDrift isolée

---

## 1. Vue d'ensemble

0dr1ft est le gateway IA multi-canal de ZeroDrift. Il expose les LLMs (Groq Llama 3.3 70B, Claude) sur Telegram, Discord, Slack, Signal, iMessage, WhatsApp et toute extension tiers.

Il est bâti sur [OpenClaw](https://github.com/openclaw/openclaw) — la couche 0dr1ft ajoute uniquement l'identité ZeroDrift, la config Azure et les secrets spécifiques, sans modifier le code source upstream.

---

## 2. Architecture déployée

```
Internet (HTTPS)
       │
       ▼
Azure Container Apps — ingress external
       │
       ├── 0dr1ft gateway (Node 22, port 18789)
       │       │
       │       ├── Telegram Bot API
       │       ├── Discord Gateway
       │       ├── Slack Events API
       │       ├── Signal (via SignalD)
       │       └── Web / WhatsApp Web
       │
       └── /app/data  ──▶  Azure Files (0dr1ftfiles)
                               SQLite sessions + config
```

**Ressources Azure — Resource Group `0dr1ft-rg` :**

| Ressource | Nom | Type |
|---|---|---|
| Container Registry | `0dr1ftacr` | Basic ACR |
| Storage Account | `0dr1ftdata` | Standard_LRS |
| File Share | `0dr1ftdata` | Azure Files (5 Gi) |
| Log Analytics | `0dr1ft-log` | Workspace |
| Container Apps Env | `0dr1ft-env` | - |
| Container App | `0dr1ft` | 0.5 vCPU / 1 Gi, 0-1 replicas |

---

## 3. Couches logicielles

```
┌────────────────────────────────────────────┐
│  0dr1ft layer (ZeroDrift)                  │
│  ─────────────────────────────────────     │
│  0dr1ft.mjs          Entry point           │
│  .env.0dr1ft         Secrets ZeroDrift     │
│  infra/azure/        Scripts az CLI        │
│  .github/workflows/deploy-azure.yml        │
│  docs/0dr1ft/        Cette documentation   │
├────────────────────────────────────────────┤
│  OpenClaw upstream (non modifié)           │
│  ─────────────────────────────────────     │
│  src/                Core gateway          │
│  extensions/         Plugins canaux        │
│  skills/             Compétences IA        │
│  packages/           Librairies partagées  │
│  openclaw.mjs        Entry point upstream  │
│  Dockerfile          Image Docker          │
└────────────────────────────────────────────┘
```

**Principe de non-modification :** tous les fichiers upstream (`src/`, `extensions/`, `skills/`, `packages/`, `openclaw.mjs`, `Dockerfile`) ne sont jamais touchés. Les merges upstream se font sans conflit sur la couche 0dr1ft.

---

## 4. Flux de démarrage

```
node 0dr1ft.mjs
    │
    ├── charge .env.0dr1ft  (OPENCLAW_GATEWAY_TOKEN, GROQ_API_KEY, ...)
    ├── charge .env          (si présent, variables upstream)
    └── délègue à openclaw.mjs
            │
            └── openclaw gateway run --bind lan --port 18789
```

---

## 5. CI/CD

```
git push main
    │
    ▼
.github/workflows/deploy-azure.yml
    │
    ├── [1] Docker lint (hadolint)
    ├── [2] az login (AZURE_CREDENTIALS)
    ├── [3] az acr build → 0dr1ftacr
    ├── [4] az containerapp update (YAML patch — préserve volume mount)
    └── [5] health check https://<fqdn>/api/health
```

**Secrets GitHub requis :**
- `AZURE_CREDENTIALS` — JSON service principal (`az ad sp create-for-rbac`)
- `OPENCLAW_GATEWAY_TOKEN` — Token d'auth du gateway

---

## 6. Décisions architecturales (ADR)

| ADR | Décision | Raison |
|---|---|---|
| ADR-001 | Rebrand en couche, pas fork | Merges upstream sans conflit |
| ADR-002 | Azure Container Apps | Pattern stk-engine, scaling 0→1 |
| ADR-003 | SQLite + Azure Files | Simplicité, pas de PostgreSQL à gérer |
| ADR-004 | ACR Basic | Coût minimal, usage interne uniquement |
| ADR-005 | Groq Llama 3.3 70B | Vitesse + coût vs OpenAI |
| ADR-006 | CI = hadolint only | Évite le CI OpenClaw complet (iOS/macOS/Android) |

---

## 7. Principes ZeroDrift

- **GitHub = source de vérité** — toute décision dans un commit ou une issue
- **Zero drift from upstream** — patches isolés, jamais dans `src/`
- **IaC** — tout provisionnable depuis `infra/` avec az CLI
- **Docs obligatoires** — HLD, MI, MEX à jour avant tout déploiement
