# GitHub Issues — Source de vérité · 0dr1ft

> Ce fichier recense les issues à créer / suivre sur GitHub.
> **GitHub Issues fait foi.** Ce fichier est une vue de synchronisation uniquement.
> Lien : https://github.com/zerodrift-io/0dr1ft/issues

---

## Convention de labels

### Priorité
| Label | Couleur | Description |
|---|---|---|
| `P0-critical` | `#d73a4a` | Bloquant production |
| `P1-high` | `#e99695` | Sprint suivant |
| `P2-medium` | `#fbca04` | Backlog planifié |
| `P3-low` | `#c5def5` | Nice-to-have / V2 |

### Type
| Label | Couleur | Description |
|---|---|---|
| `feat` | `#0e8a16` | Nouvelle fonctionnalité |
| `bug` | `#d73a4a` | Anomalie |
| `docs` | `#0075ca` | Documentation |
| `infra` | `#006b75` | Azure / CI / Docker |
| `upstream` | `#bfd4f2` | Merge OpenClaw |
| `security` | `#b60205` | Sécurité |

---

## Backlog initial

### P1 — Activation Azure

- [ ] **INFRA-01** — Provisionner l'infra Azure (`./infra/azure/deploy.sh`)
  - Labels : `infra`, `P1-high`
  - Checklist : RG, ACR, Storage, Log Analytics, Container App
  - Critère : `curl https://<fqdn>/api/health` retourne 200

- [ ] **INFRA-02** — Configurer les secrets GitHub Actions
  - Labels : `infra`, `P1-high`
  - `AZURE_CREDENTIALS` + `OPENCLAW_GATEWAY_TOKEN`
  - Critère : workflow `deploy-azure.yml` passe en vert sur push main

- [ ] **INFRA-03** — Valider le premier déploiement automatique
  - Labels : `infra`, `P1-high`
  - Push sur main → pipeline CI/CD → Container App mise à jour
  - Critère : image SHA visible dans les logs Azure

### P1 — Canaux actifs

- [ ] **CHAN-01** — Configurer Telegram bot token
  - Labels : `feat`, `P1-high`
  - `TELEGRAM_BOT_TOKEN` dans les env vars de la Container App
  - Critère : bot répond sur Telegram

- [ ] **CHAN-02** — Configurer Discord bot token (optionnel)
  - Labels : `feat`, `P2-medium`

### P2 — Observabilité

- [ ] **OPS-01** — Créer une alerte Azure Monitor sur les erreurs 5xx
  - Labels : `infra`, `P2-medium`
  - Alert rule sur `ContainerAppConsoleLogs_CL` avec erreurs

- [ ] **OPS-02** — Configurer les notifications d'alerte (email / Telegram)
  - Labels : `infra`, `P2-medium`
  - Action Group Azure → webhook ou email

### P2 — Documentation

- [ ] **DOCS-01** — Valider et compléter MI_AZURE.md post-premier déploiement
  - Labels : `docs`, `P2-medium`

- [ ] **DOCS-02** — Ajouter runbook de mise à jour upstream OpenClaw
  - Labels : `docs`, `upstream`, `P2-medium`

### P3 — Améliorations futures

- [ ] **FEAT-01** — Passer de SQLite à Azure DB PostgreSQL si charge > 10 users
  - Labels : `feat`, `infra`, `P3-low`

- [ ] **FEAT-02** — Ajouter staging environment (0dr1ft-staging)
  - Labels : `infra`, `P3-low`

- [ ] **FEAT-03** — Custom domain pour le gateway
  - Labels : `infra`, `P3-low`

---

## Processus

1. Toute nouvelle décision ou tâche → ouvrir une issue GitHub
2. Référencer l'issue dans les commits : `fix(infra): ... refs #N`
3. Fermer l'issue dans le PR qui la résout
4. Ce fichier mis à jour à chaque sprint (optionnel — GitHub fait foi)
