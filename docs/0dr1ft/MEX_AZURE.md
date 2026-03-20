# MEX — Mode d'Exploitation Azure · 0dr1ft

> **Version :** 1.0
> **Date :** 2026-03-20
> **Prérequis :** MI_AZURE.md exécuté et validé

---

## 1. Contacts et escalade

| Rôle | Action |
|---|---|
| Dev / Ops | zerodrift-io GitHub Issues |
| Azure incidents | portal.azure.com → Support |

---

## 2. Opérations courantes

### 2.1 Voir les logs

```bash
# Logs en temps réel
az containerapp logs show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --follow

# Logs récents (50 lignes)
az containerapp logs show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --tail 50
```

### 2.2 Redéployer manuellement

```bash
# Via GitHub Actions (recommandé)
# GitHub → zerodrift-io/0dr1ft → Actions → Deploy — Azure Container Apps → Run workflow

# Via az CLI (image latest existante)
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --image 0dr1ftacr.azurecr.io/0dr1ft:latest
```

### 2.3 Redémarrer le container

```bash
az containerapp revision restart \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --revision $(az containerapp revision list \
    --name 0dr1ft \
    --resource-group 0dr1ft-rg \
    --query "[0].name" -o tsv)
```

### 2.4 Mettre à jour une variable d'environnement

```bash
# Ajouter / modifier une variable
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --set-env-vars "TELEGRAM_BOT_TOKEN=<nouveau_token>"

# Supprimer une variable
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --remove-env-vars "TELEGRAM_BOT_TOKEN"
```

### 2.5 Changer le token gateway

```bash
NEW_TOKEN=$(openssl rand -hex 32)
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --set-env-vars "OPENCLAW_GATEWAY_TOKEN=${NEW_TOKEN}"
echo "Nouveau token : $NEW_TOKEN"
# ⚠ Mettre à jour aussi le secret GitHub OPENCLAW_GATEWAY_TOKEN
```

### 2.6 Scaler (activer / désactiver)

```bash
# Toujours actif (1 replica minimum)
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --min-replicas 1

# Éteindre la nuit (0 replicas minimum, scale-to-zero)
az containerapp update \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --min-replicas 0
```

---

## 3. Monitoring

### 3.1 Health check

```bash
FQDN=$(az containerapp show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)

curl -f "https://$FQDN/api/health" && echo "OK" || echo "DOWN"
```

### 3.2 État du container

```bash
az containerapp show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --query "{status:properties.runningStatus, replicas:properties.template.scale.minReplicas, fqdn:properties.configuration.ingress.fqdn}" \
  -o table
```

### 3.3 Log Analytics (portail Azure)

Dans portal.azure.com :
- `0dr1ft-log` → Logs → Kusto query
- Exemple : `ContainerAppConsoleLogs_CL | where ContainerName_s == "0dr1ft" | order by TimeGenerated desc | take 100`

---

## 4. Procédures d'incident

### P1 — Gateway inaccessible

1. Vérifier l'état : `az containerapp show --name 0dr1ft --resource-group 0dr1ft-rg --query properties.runningStatus`
2. Lire les logs : `az containerapp logs show --name 0dr1ft --resource-group 0dr1ft-rg --tail 100`
3. Redémarrer : voir §2.3
4. Si l'image est cassée : redéployer la version précédente :
   ```bash
   # Lister les images disponibles dans l'ACR
   az acr repository show-tags --name 0dr1ftacr --repository 0dr1ft --output table
   # Rollback sur un SHA précédent
   az containerapp update --name 0dr1ft --resource-group 0dr1ft-rg \
     --image 0dr1ftacr.azurecr.io/0dr1ft:<SHA_PRECEDENT>
   ```

### P2 — Perte de données / sessions

Les sessions sont stockées sur Azure Files (`/app/data`). En cas de problème :

```bash
# Vérifier le montage
az containerapp show \
  --name 0dr1ft \
  --resource-group 0dr1ft-rg \
  --query "properties.template.volumes"

# Lister les fichiers dans le share
az storage file list \
  --account-name 0dr1ftdata \
  --share-name 0dr1ftdata \
  --output table
```

### P3 — CI/CD bloqué

1. Vérifier les secrets GitHub : `AZURE_CREDENTIALS` et `OPENCLAW_GATEWAY_TOKEN` existent
2. Vérifier la validité du SP : `az ad sp show --id <clientId>`
3. Renouveler le SP si expiré (voir MI_AZURE.md §5.1)

---

## 5. Maintenance

### 5.1 Mise à jour upstream OpenClaw

```bash
git remote add upstream https://github.com/openclaw/openclaw.git
git fetch upstream
git merge upstream/main
# Résoudre les conflits uniquement sur les fichiers 0dr1ft (AGENTS.md, etc.)
# Les fichiers src/, extensions/, skills/ ne doivent pas avoir de conflits
git push origin main
# Le pipeline CI/CD se déclenche et redéploie automatiquement
```

### 5.2 Nettoyage des images ACR

```bash
# Purger les images de plus de 30 jours (garder latest + 5 derniers SHA)
az acr run \
  --registry 0dr1ftacr \
  --cmd "acr purge --filter '0dr1ft:.*' --ago 30d --keep 5 --untagged" \
  /dev/null
```

### 5.3 Rotation des secrets

Tous les 90 jours :
1. Générer un nouveau `OPENCLAW_GATEWAY_TOKEN` (voir §2.5)
2. Renouveler le Service Principal si nécessaire
3. Mettre à jour les secrets GitHub

---

## 6. Infra as Code — état de référence

```
0dr1ft-rg (westeurope)
├── 0dr1ftacr          Container Registry Basic
├── 0dr1ftdata         Storage Account Standard_LRS
│   └── 0dr1ftdata     File Share 5 Gi
├── 0dr1ft-log         Log Analytics Workspace
└── 0dr1ft-env         Container Apps Environment
    └── 0dr1ft         Container App
                           image : 0dr1ftacr.azurecr.io/0dr1ft:latest
                           cpu   : 0.5 / mem : 1 Gi
                           port  : 18789
                           mount : /app/data → 0dr1ftfiles (Azure Files)
```

Script de vérification de l'état :

```bash
az resource list --resource-group 0dr1ft-rg --output table \
  --query "[].{Nom:name, Type:type, Etat:provisioningState}"
```
