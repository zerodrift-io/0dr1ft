# MI — Mise en Oeuvre Azure · 0dr1ft

> **Version :** 1.0
> **Date :** 2026-03-20
> **Statut :** Draft
> **Prérequis :** compte Azure actif, az CLI installé, accès GitHub zerodrift-io/0dr1ft

---

## 1. Objectif

Déployer 0dr1ft sur Microsoft Azure Container Apps pour la première fois.
Ce document couvre le provisionnement complet de l'infrastructure et la configuration du pipeline CI/CD.

---

## 2. Architecture cible

```
┌─────────────────────────────────────────────────────┐
│            Resource Group : 0dr1ft-rg               │
│                                                     │
│  ┌─────────────┐    ┌──────────────────┐            │
│  │  0dr1ftacr  │───▶│  Container Apps  │            │
│  │  (ACR)      │    │  0dr1ft-env      │            │
│  └─────────────┘    │  ┌────────────┐  │            │
│                     │  │  0dr1ft    │  │            │
│  ┌─────────────┐    │  │  gateway   │  │            │
│  │  0dr1ftdata │◀───│  │  :18789    │  │            │
│  │  (Storage)  │    │  └────────────┘  │            │
│  │  0dr1ftdata │    └──────────────────┘            │
│  │  (FileShare)│                                    │
│  └─────────────┘    ┌──────────────────┐            │
│                     │  0dr1ft-log      │            │
│  Montage Azure Files│  (Log Analytics) │            │
│  → /app/data        └──────────────────┘            │
└─────────────────────────────────────────────────────┘
```

---

## 3. Prérequis

```bash
# 1. Azure CLI
az --version  # >= 2.57

# 2. Connexion
az login
az account show  # vérifier la subscription active

# 3. Optionnel : fixer la subscription
az account set --subscription <SUBSCRIPTION_ID>
```

---

## 4. Provisionnement infra (une seule fois)

### Option A — Script automatique (recommandé)

```bash
cd zerodrift-io/0dr1ft
chmod +x infra/azure/deploy.sh
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
./infra/azure/deploy.sh
```

Le script crée en séquence :
1. Resource Group `0dr1ft-rg` (westeurope)
2. Container Registry `0dr1ftacr` (Basic, admin enabled)
3. Build et push de l'image Docker
4. Storage Account `0dr1ftdata` + File Share `0dr1ftdata` (5 Gi)
5. Log Analytics `0dr1ft-log`
6. Container Apps Environment `0dr1ft-env`
7. Container App `0dr1ft` (0.5 vCPU / 1 Gi, 0-1 replicas)

### Option B — Étapes séparées (setup + deploy)

```bash
# Étape 1 : infra seulement
chmod +x infra/setup.sh
./infra/setup.sh

# Étape 2 : déployer l'app
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
chmod +x infra/deploy-app.sh
./infra/deploy-app.sh
```

---

## 5. Configuration GitHub Actions

### 5.1 Créer le Service Principal

```bash
# Récupérer l'ID de la subscription
SUB_ID=$(az account show --query id -o tsv)

# Créer le SP avec droits Contributor sur le RG
az ad sp create-for-rbac \
  --name "0dr1ft-github-actions" \
  --role Contributor \
  --scopes /subscriptions/${SUB_ID}/resourceGroups/0dr1ft-rg \
  --sdk-auth
```

Copier le JSON retourné (format `{"clientId":...,"clientSecret":...,...}`).

### 5.2 Ajouter les secrets GitHub

Dans `https://github.com/zerodrift-io/0dr1ft/settings/secrets/actions` :

| Secret | Valeur |
|---|---|
| `AZURE_CREDENTIALS` | JSON complet du SP ci-dessus |
| `OPENCLAW_GATEWAY_TOKEN` | Token généré (`openssl rand -hex 32`) |

### 5.3 Vérifier le pipeline

```bash
# Depuis GitHub : onglet Actions → Deploy — Azure Container Apps (0dr1ft)
# → Run workflow (manuel) pour tester sans push
```

---

## 6. Vérification post-déploiement

```bash
# URL de l'app
FQDN=$(az containerapp show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)
echo "https://$FQDN"

# Health check
curl -f "https://$FQDN/api/health"

# Logs en temps réel
az containerapp logs show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --follow
```

---

## 7. Configuration des canaux (post-déploiement)

Une fois le gateway déployé, configurer les tokens de canaux via variables d'env sur la Container App :

```bash
# Exemple : ajouter Telegram
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --set-env-vars "TELEGRAM_BOT_TOKEN=<token>"
```

Ou via `.env.0dr1ft` localement + rebuild :

```bash
cp .env.0dr1ft.example .env.0dr1ft
# Éditer .env.0dr1ft avec les vrais tokens
az acr build --registry 0dr1ftacr --image 0dr1ft:latest .
# Le workflow CI/CD redéploie automatiquement
```

---

## 8. Coût estimé (westeurope)

| Ressource | SKU | Coût/mois estimé |
|---|---|---|
| Container Apps | 0.5 vCPU / 1 Gi, 0-1 replicas | ~5–15 € |
| Container Registry | Basic | ~5 € |
| Storage Account | Standard_LRS 5 Gi | < 1 € |
| Log Analytics | Pay-as-you-go | ~2–5 € |
| **Total** | | **~15–25 €/mois** |

> Avec `min-replicas=0` le gateway s'éteint quand il n'est pas utilisé.
> Pour un usage continu, passer à `min-replicas=1`.
