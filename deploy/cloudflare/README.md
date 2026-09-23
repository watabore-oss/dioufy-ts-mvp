# ⚡ Déploiement Dioufy-TS sur Cloudflare (Pages & Workers)

Ce dossier contient l'ensemble des configurations et scripts d'automatisation pour le déploiement sur le réseau mondial **Cloudflare**.

---

## 📁 Contenu du dossier

| Fichier | Description |
| :--- | :--- |
| `deploy-cloudflare.ps1` | Script principal PowerShell (Build, injection `_redirects` & `_headers`, déploiement via Wrangler). |
| `deploy-cloudflare.bat` | Lanceur rapide Windows CMD / Double-clic. |
| `deploy-cloudflare.sh` | Lanceur Bash pour Linux / macOS / CI. |
| `_redirects` | Règles de routage SPA Cloudflare (`/* /index.html 200`). |
| `_headers` | En-têtes HTTP de sécurité et stratégie de cache CDN. |
| `wrangler.toml` | Définition du projet Pages et de l'environnement Worker Proxy. |
| `cloudflare.env.example`| Modèle des variables d'environnement Cloudflare. |

---

## 🚀 Utilisation Rapide

Depuis la racine du projet, lancez :

```powershell
.\onflare
```

Ou via npm :

```bash
npm run onflare
```

### Options disponibles :

```powershell
# Déployer sans recompiler (si build/web est déjà compilé)
.\onflare -SkipBuild

# Déployer également le Worker Proxy d'authentification (auth.dioufy-ts.sn)
.\onflare -DeployWorker

# Spécifier une branche spécifique
.\onflare -Branch staging
```

---

## ⚙️ Configuration Cloudflare

- **Nom du Projet Pages :** `dioufy-ts`
- **Account ID :** `e3c497545f251d34b6286c39a578a40f`
- **URL Pages :** `https://dioufy-ts.pages.dev`
- **Worker Auth Proxy :** `cloudflare/worker_auth_proxy.js` -> `auth.dioufy-ts.sn`
