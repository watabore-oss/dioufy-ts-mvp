# 👥 Rôles d'Expertise Ciblés — Dioufy-TS

Pour garantir la qualité sans sur-dimensionner les équipes ou les discussions, chaque intervention mobilise uniquement les expertises pertinentes selon la criticité du changement.

---

## 1. 🚍 Spécialiste Produit & Exploitation Transport
* **Périmètre** : Modélisation des lignes, gares routières sénégalaises (Baux Maraîchers, Touba, Thiès, etc.), flux passagers, coxeurs, et parcours direct sans compte.
* **Critères d'Activation** : Modifications de la recherche de trajets, de la disposition des sièges de bus, de la billettique, ou des interactions au quai.
* **Garantie** : Respect des usages réels des voyageurs et transporteurs au Sénégal (simplicité, WhatsApp, absence de friction).

---

## 2. 📱 Ingénieur Flutter & Architecture Modulaire
* **Périmètre** : Clean architecture dans `lib/`, isolation des modules dans `lib/modules/`, Feature Flags à 6 états, et navigation.
* **Critères d'Activation** : Tout développement d'interface ou de service client.
* **Garantie** : Zéro écran blanc, fluidité mobile sur Android d'entrée de gamme, bouton retour obligatoire sur chaque écran, conformité monétaire FCFA / XOF.

---

## 3. 🗄️ Architecte Données & Intégrité Supabase
* **Périmètre** : PostgreSQL, schémas relationnels, politiques RLS (*Row Level Security*), fonctions atomiques `SECURITY DEFINER` et migrations.
* **Critères d'Activation** : Toute modification de table, de colonne, de jointure ou de fonction SQL.
* **Garantie** : `search_path = pg_catalog, public`, qualification explicite des tables, et migrations idempotentes avec rollback sécurisé.

---

## 4. 🛡️ Ingénieur Sécurité & Gouvernance RBAC
* **Périmètre** : Matrice des 7 rôles, permissions granulaires par module, anti-élévation de privilèges, isolation multi-tenancy (GIE) et gestion des sessions.
* **Critères d'Activation** : Accès aux écrans d'administration, attribution de rôles, ou modifications des droits.
* **Garantie** : Protection anti-suicide du Super Admin, cloisonnement étanche des GIE, expiration TTL du snapshot hors-ligne (30 min), et exclusion du code de test en production (`assert(kDebugMode)`).

---

## 5. 💰 Auditeur Financier & Intégrité des Flux
* **Périmètre** : Passerelles de paiement (Wave Sénégal 774691379, PayDunya, Flutterwave, PayTech, Orange Money), grand livre comptable à double entrée, commissions chauffeur/GIE et clôture de caisse.
* **Critères d'Activation** : Toute manipulation monétaire, paiement, virement ou calcul de solde.
* **Garantie** : Calculs 100% côté serveur, zéro virgule flottante imprécise, idempotence des requêtes, et interdiction formelle des mutations financières hors-ligne.

---

## 6. 🧪 Ingénieur Qualité (QA) & Release
* **Périmètre** : Tests unitaires, tests d'intégration, smoke tests d'interface, absence de régression et vérification des logs.
* **Critères d'Activation** : Systématique avant toute livraison ou validation d'étape.
* **Garantie** : Couverture > 80%, 100% de réussite à `flutter test`, et purgation absolue de tout résidu de plantage dans `ai/error_logs`.
