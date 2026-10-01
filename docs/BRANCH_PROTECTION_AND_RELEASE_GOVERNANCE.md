# 🛡️ Gouvernance des Branches & Protection de Production — Dioufy-TS

Ce document consigne les règles obligatoires de protection du dépôt GitHub et de déploiement de l'application **Dioufy-TS** pour préserver l'intégrité de l'application déjà en circulation sur les stores et le web.

---

## 🔒 1. Protection de la Branche `main`

Sur GitHub (Paramètres du Répertoire > *Branches* > *Branch protection rules* sur `main`) :

1. **Interdiction formelle des push directs** :
   - Tout changement de code doit transiter par une Pull Request (PR).
   - Les commandes `git push origin main --force` sont strictement verrouillées.
2. **Checks CI obligatoires avant tout merge** :
   - Le job `🧪 Quality Checks & Tests` (comprenant `flutter analyze` et `flutter test`) doit obligatoirement être au statut **SUCCESS**.
   - Si un seul warning ou test échoue, le bouton `Merge` est bloqué.
3. **Revue de code requise** :
   - Au minimum une approbation (*Review approval*) d'un mainteneur senior.
   - Les conversations de review doivent être résolues.

---

## 🚀 2. Matrice de Versioning & Déploiement

Toute nouvelle publication de version d'application sur le Play Store ou en Web PWA doit respecter le cycle :

1. **Incrémentation de la version** dans `pubspec.yaml` (ex: `1.0.1+2`).
2. **Enregistrement dans la table `public.app_releases`** de Supabase :
   ```sql
   INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
   VALUES ('android', '1.0.1', '1.0.0', false, 'https://play.google.com/store/apps/details?id=com.dioufy.transport', 'Corrections de sécurité et vitesse.');
   ```
3. Si une vulnérabilité critique est corrigée ou qu'une rupture de contrat d'API survient :
   - Mettre à jour `minimum_supported_version = '1.0.1'` ou `update_required = true`.
   - L'application existante sur le terrain affichera automatiquement le dialogue bloquant de mise à jour géré par `VersionCheckService`.

---

## 🌐 3. Stratégie Cache-Busting PWA & Web

Les clients Web et PWA appliquent la politique suivante :
- `index.html` : `Cache-Control: no-cache, no-store, must-revalidate`
- `flutter_service_worker.js` : `Cache-Control: max-age=0, no-cache, no-store, must-revalidate`
- `assets/` et `canvaskit/` : `Cache-Control: public, max-age=31536000, immutable`

Cette configuration est gérée simultanément via :
- Balises `<meta>` dans `web/index.html`
- Règles Cloudflare dans `web/_headers`
- Directives LiteSpeed / Apache dans `web/.htaccess`
