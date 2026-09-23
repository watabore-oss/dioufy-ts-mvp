# 🌍 Déploiement Dioufy-TS sur Wanekoo (cPanel / Apache)

Ce dossier contient l'ensemble des configurations et scripts dédiés à l'hébergeur **Wanekoo** pour le domaine souverain `https://dioufy-ts.sn/`.

---

## 🚀 Fonctionnement : Deux Modes de Déploiement

### 1. Mode Direct 100% Automatique (Par défaut si FTP actif)
* **Pas besoin d'extraire dans cPanel** : le script téléverse l'ensemble des fichiers décompressés (`index.html`, assets, scripts, `.htaccess`) directement dans `/public_html/`.
* **Résultat :** Dès que le script se termine, le site est **immédiatement en ligne et opérationnel** !

### 2. Mode Archive ZIP (`-UploadZipOnly` ou `-OnlyZip`)
* Génère ou téléverse l'archive `dioufy-ts-production.zip`.
* Nécessite un clic droit dans le gestionnaire de fichiers cPanel $\rightarrow$ **Extraire** (*Extract*).

---

## 📁 Contenu du dossier

| Fichier | Description |
| :--- | :--- |
| `deploy-waneko.ps1` | Script principal PowerShell d'automatisation (Build, injection `.htaccess`, téléversement direct décompressé ou ZIP). |
| `deploy-waneko.bat` | Lanceur rapide Windows CMD / Double-clic. |
| `deploy-waneko.sh` | Lanceur Bash pour Linux / macOS / Git Bash. |
| `.htaccess` | Configuration Apache (réécriture SPA 404, HTTPS obligatoire, MIME types WebAssembly, cache HTTP). |
| `waneko.env.example` | Modèle de variables pour la connexion FTP. |

---

## 💻 Exécution

```powershell
# Déploiement direct 100% automatique (tous les fichiers en ligne sans ouvrir cPanel)
.\onwaneko

# Déploiement direct avec mot de passe FTP spécifié
.\onwaneko -FtpPassword "VotreMotDePasse"

# Téléverser uniquement l'archive .zip (à extraire ensuite dans cPanel)
.\onwaneko -UploadZipOnly

# Générer uniquement l'archive locale sans téléverser
.\onwaneko -OnlyZip
```

---

## ⚙️ Paramètres Wanekoo

- **Domaine :** `https://dioufy-ts.sn/`
- **Serveur cPanel :** `fatma.wanekoohost.com` (IP `138.199.142.78`)
- **Utilisateur cPanel / FTP :** `dioufyt1`
- **Répertoire distant :** `/public_html/`
