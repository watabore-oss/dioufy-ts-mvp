# 🚀 Guide de Déploiement en Ligne — Dioufy-TS

**Nom de domaine :** `https://dioufy-ts.sn/`  
**Hébergeur :** Access Entreprise - WANEKOO (Pack Hébergement web Setlu - 22 500 XOF/an)  
**Serveur cPanel :** `fatma.wanekoohost.com` (IP : `138.199.142.78`)  
**Utilisateur cPanel / FTP :** `dioufyt1`  
**Certificat SSL :** Déjà actif et valide (HTTPS activé)  
**Archive prête à l'emploi :** `d:\APP-PROJETS\Dioufy-TS\dioufy-ts-production.zip` (10,8 Mo)  

---

## 📋 Méthode 1 : Déploiement en 1 minute via cPanel (Recommandé)

1. **Connexion à l'espace client Wanekoo :**
   * Rendez-vous sur : [https://my.wanekoo.com/login](https://my.wanekoo.com/login)
   * **Email :** `diouf92.p@gmail.com`
   * **Mot de passe :** `Cla30ri04@`

2. **Accès au cPanel :**
   * Cliquez sur votre produit : **« Hébergement web - Pack Hébergement web Setlu (dioufy-ts.sn) »**
   * Dans le menu de gauche, cliquez sur le bouton :
     👉 **« Connexion à cPanel »** *(la connexion est automatique en 1 clic sans mot de passe)*

3. **Téléversement des fichiers :**
   * Dans cPanel, cliquez sur **« Gestionnaire de fichiers »** (*File Manager*).
   * Entrez dans le dossier **`public_html`**.
   * Cliquez sur **« Charger »** (*Upload*) dans la barre supérieure.
   * Sélectionnez et déposez l'archive :
     📁 `d:\APP-PROJETS\Dioufy-TS\dioufy-ts-production.zip`

4. **Extraction :**
   * Une fois le téléversement à 100% (barre verte), revenez dans `public_html`.
   * Faites un clic droit sur `dioufy-ts-production.zip` et sélectionnez **« Extraire »** (*Extract* $\rightarrow$ *Extract Files*).
   * Vous pouvez supprimer le fichier `.zip` après extraction.

5. **Accès direct :**
   * Ouvrez [https://dioufy-ts.sn/](https://dioufy-ts.sn/) : l'application est en ligne !

---

## 📡 Méthode 2 : Déploiement par FTP (Automatisable)

Si vous préférez un déploiement par script ou via FileZilla :

* **Hôte :** `fatma.wanekoohost.com` (ou `138.199.142.78`)
* **Port :** `21`
* **Identifiant :** `dioufyt1`
* **Mot de passe :** Votre mot de passe cPanel (configurable dans votre espace client Wanekoo sous *« Modifier le mot de passe »*)
* **Dossier de destination :** `/public_html/`
* **Fichiers sources :** Tout le contenu de `d:\APP-PROJETS\Dioufy-TS\build\web\`

---

## 🗄️ Activation de la Base de Données Supabase

Pour charger les données de démo (agences Dioufy Trans, Galsen Tour, trajets Dakar-Thiès et Dakar-Touba) :

1. Ouvrez l'éditeur SQL Supabase :
   👉 [https://supabase.com/dashboard/project/yrarlatdoulyfyjpqzlp/sql/new](https://supabase.com/dashboard/project/yrarlatdoulyfyjpqzlp/sql/new)
2. Exécutez le script contenu dans [`SUPABASE_SCHEMA_INIT.sql`](file:///d:/APP-PROJETS/Dioufy-TS/SUPABASE_SCHEMA_INIT.sql).

---

## ⚡ Optimisations Incluses dans le Build

- **Routage SPA & HTTPS :** Fichier `.htaccess` préconfiguré pour Apache/cPanel (évite les erreurs 404 lors du rafraîchissement des pages).
- **PWA Installable :** Détection automatique sur Android pour installation sur l'écran d'accueil comme une application native.
- **Affichage instantané (0 ms) :** Stratégie *Stale-While-Revalidate* avec cache local et revalidation en arrière-plan.
- **Devise officielle :** Tarifs affichés en **FCFA / XOF**.
- **Sécurité des Billets :** Signature cryptographique HMAC-SHA256 intégrée dans le QR Code.
