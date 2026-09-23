# 🏗️ Architecture Modulaire Compilée, Moteur de Feature Flags & Feuille de Route Évolutive Unifiée — Dioufy-TS

> **Document Maître de Référence Technique & Stratégique**  
> **Plateforme :** Dioufy-TS (*Fo nek sa gare fek lafa*)  
> **Devise Standard :** **FCFA (XOF)** — Symbole monétaire : badge circulaire `XOF` *(zéro dollar `$`).*  
> **Principes Cardinaux :** **Mobile First (Android 90%+) • Offline Capable • API First • Clean Architecture • Zéro Écran Blanc.**  
> **Règle Fondamentale de Production :** **« Désactiver ≠ Supprimer »** (Découplage strict entre déploiement binaire et activation opérationnelle).

---

## 📑 TABLE DES MATIÈRES
1. [Doctrine Architecturale : Modules Compilés vs Plugins Dynamiques](#1-doctrine-architecturale--modules-compilés-vs-plugins-dynamiques)
2. [Structure Modulaire Cible (Modular Monolith) & Contrats d'Interface](#2-structure-modulaire-cible-modular-monolith--contrats-dinterface)
3. [Moteur de Feature Flags & Gouvernance Runtime](#3-moteur-de-feature-flags--gouvernance-runtime)
4. [Catalogue Exhaustif des Feature Flags & Clés Techniques](#4-catalogue-exhaustif-des-feature-flags--clés-techniques)
5. [Résilience Réseau, Zéro Écran Blanc & Offline-First](#5-résilience-réseau-zéro-écran-blanc--offline-first)
6. [Feuille de Route Stratégique Fusionnée (Phases 0 à 6)](#6-feuille-de-route-stratégique-fusionnée-phases-0-à-6)
   - [Phase 0 — Cadrage Opérationnel, Juridique & Lignes Pilotes](#phase-0--cadrage-opérationnel-juridique--lignes-pilotes-semaines-0-à-2)
   - [Phase 1 — MVP Voyageurs & Billettique Numérique Autonome](#phase-1--mvp-voyageurs--billettique-numérique-autonome-semaines-1-à-6)
   - [Phase 2 — Opérations Terrain & Contrôle d'Embarquement Tri-Canal](#phase-2--opérations-terrain--contrôle-dembarquement-tri-canal-semaines-7-à-10)
   - [Phase 3 — RBAC Organisationnel, Multi-Tenancy GIE & Gestion de Flotte](#phase-3--rbac-organisationnel-multi-tenancy-gie--gestion-de-flotte-semaines-11-à-14)
   - [Phase 4 — Grand Livre Financier (Double-Entrée), Commissions & Clôture de Caisse](#phase-4--grand-livre-financier-double-entrée-commissions--clôture-de-caisse-semaines-15-à-18)
   - [Phase 5 — Marketplace d'Assistance, SOS Panne & Pack Garagiste](#phase-5--marketplace-dassistance-sos-panne--pack-garagiste-semaines-19-à-24)
   - [Phase 6 — Industrialisation MaaS, Billettique Unifiée ABT & Smart Fleet IoT](#phase-6--industrialisation-maas-billettique-unifiée-abt--smart-fleet-iot-mois-6-à-15)
7. [Sécurité, Conformité Monétaire (UEMOA / BCEAO) & Auditabilité](#7-sécurité-conformité-monétaire-uemoa--bceao--auditabilité)
8. [Matrice d'Activation des Modules & Checklist de Déploiement](#8-matrice-dactivation-des-modules--checklist-de-déploiement)

---

## 1. DOCTRINE ARCHITECTURALE : MODULES COMPILÉS VS PLUGINS DYNAMIQUES

### 1.1. Clarification Stratégique Essentielle
Pour une plateforme critique comme Dioufy-TS combinant paiements, transports et sécurité des passagers, il est impératif de distinguer trois approches :

| Approche | Définition | Recommandation Dioufy-TS | Rationale Technique |
| :--- | :--- | :---: | :--- |
| **1. Module Compilé** | Code structuré par domaine métier, typé strictement, intégré et compilé directement dans le binaire Flutter et le schéma Supabase. | **OBLIGATOIRE (Cœur)** | Zéro latence au démarrage, sécurité du bytecode AOT, absence totale d'écrans blancs dus au téléchargement de code. |
| **2. Module Activé par Feature Flag** | Code compilé présent dans l'application, dont l'exposition dans l'UI et l'accès API sont contrôlés dynamiquement par le serveur. | **OBLIGATOIRE (Pivot)** | Permet d'activer/désactiver une fonctionnalité par région, par GIE ou par rôle, instantanément et sans republier l'application sur le Play Store. |
| **3. Plugin Téléchargé Dynamiquement** | Code tiers injecté à distance dans l'application mobile en exécution via un moteur webview ou code-push dynamique. | **STRICTEMENT PROSCRIT** | Rejet garanti sur Google Play Store / Apple App Store pour violation des règles de sécurité ; instabilité critique en cas de 3G/4G instable au Sénégal. |

### 1.2. Le Choix du « Modular Monolith » Évolutif
Plutôt que d'éparpiller le projet en dizaines de microservices précoces (coûteux en DevOps, générateurs de latence réseau et de pannes distribuées), Dioufy-TS adopte le **Monolithe Modulaire** :
- **Une seule application Flutter compilée** et **un backend PostgreSQL / Supabase unifié**, mais avec des **frontières de domaine étanches (Bounded Contexts DDD)**.
- Aucune dépendance cyclique entre modules.
- Chaque module expose un contrat public (Interface) et garde ses composants internes privés.
- Les modules les plus sensibles (Grand Livre, Webhooks Wave/OM, Télématique) pourront être extraits ultérieurement en microservices autonomes sans refonte grâce à ce découpage étanche.

### 1.3. La Règle d'Or Opérationnelle : « Désactiver ≠ Supprimer »
En environnement de production financière et logistique :
> **Lorsqu'un administrateur désactive un module (ex: module commissions ou module dépannage) :**
> 1. Le module disparaît de la navigation et des actions actives de l'interface utilisateur.
> 2. Les nouvelles transactions sont bloquées de manière élégante avec un message informatif clair.
> 3. **Aucune table, colonne ou donnée historique n'est supprimée**.
> 4. Les écritures comptables, billets émis, commissions acquises et traces d'audit restent **100% immuables et consultables**.
> 5. L'application ne génère **aucun plantage, aucune exception non rattrapée et aucun écran blanc**.

---

## 2. STRUCTURE MODULAIRE CIBLE (MODULAR MONOLITH) & CONTRATS D'INTERFACE

### 2.1. Arborescence du Codebase Flutter (`lib/`)

```
lib/
 ├ core/                         # Socle immuable transverse
 │   ├ constants.dart            # Gares, Villes, Badges XOF/FCFA, Couleurs
 │   ├ theme.dart                # Design System Mobile-First (Contraste élevé)
 │   ├ network/                  # Client HTTP, Retry exponentiel, Détection Offline
 │   ├ storage/                  # Cache local chiffré (SharedPreferences / SQLite)
 │   └ security/                 # HMAC-SHA256, Obfuscation, Validateurs Zod/Dart
 │
 ├ app/                          # Orchestration globale
 │   ├ app.dart                  # Point d'entrée MaterialApp
 │   ├ bootstrap.dart            # Initialisation asynchrone sécurisée (Try/Catch)
 │   ├ router.dart               # Navigation & Guard de routage
 │   └ feature_flags/            # Moteur local de Feature Flags
 │       ├ flag_service.dart     # Service de récupération & cache local
 │       ├ flag_provider.dart    # State notifier (activation dynamique)
 │       └ feature_guard.dart    # Widget guard empêchant l'écran blanc
 │
 └ modules/                      # Domaines métier compilés & isolés
     ├ module_traveler/          # Recherche de trajet, détails & passagers
     ├ module_booking_engine/    # Verrouillage atomique des sièges & réservations
     ├ module_ticketing/         # Billet Boarding Pass & QR Code signé HMAC
     ├ module_payment/           # Wave, Orange Money, Free Money & Webhooks
     ├ module_field_ops/         # Contrôle billets (Scan caméra, Galerie, Manuel)
     ├ module_cash_closure/      # Clôture caisse chauffeur, ventilation cash/digital
     ├ module_financial_ledger/  # Grand livre à double-entrée & portefeuilles
     ├ module_fleet_mgmt/        # Multi-tenancy GIE, véhicules, affectation chauffeurs
     ├ module_garage_assistance/ # Pack Garagiste, SOS Panne géolocalisé
     └ module_maas_iot/          # GTFS Intermodal, Billettique ABT & Télématique
```

### 2.2. Contrat Standard d'un Module (`AppModule`)
Chaque module métier implémente une interface stricte garantissant qu'il s'enregistre, s'initialise et se désactive sans impacter le reste du système :

```dart
abstract interface class AppModule {
  String get id;                         // Ex: 'module_cash_closure'
  String get name;                       // Ex: 'Clôture de Caisse & Commissions'
  String get requiredFlag;               // Ex: 'FLAG_CASH_CLOSURE'
  List<String> get dependencies;         // Ex: ['module_booking_engine', 'module_financial_ledger']
  
  /// Vérifie si le module est actif selon le contexte utilisateur et réseau
  bool isAvailable(ModuleContext context);

  /// Tâche d'initialisation (chargement cache, écouteurs de background)
  Future<void> initialize(ModuleContext context);

  /// Déclaration des routes associées au module (protégées par FeatureGuard)
  List<AppRouteDefinition> routes(ModuleContext context);

  /// Widget de repli (Fallback) affiché si le module est désactivé
  Widget buildDisabledFallback(BuildContext context);
}
```

---

## 3. MOTEUR DE FEATURE FLAGS & GOUVERNANCE RUNTIME

### 3.1. Niveaux de Portée (Scopes d'Activation)
Le moteur de Feature Flags Dioufy-TS supporte 5 niveaux d'activation granulaires :

```
[Portée 1 : PLATFORM]     -> Activé / Désactivé pour l'ensemble du Sénégal
   ↓
[Portée 2 : REGION/AXE]   -> Activé uniquement sur un axe (ex: Dakar ↔ Thiès)
   ↓
[Portée 3 : ORGANIZATION] -> Activé pour un GIE spécifique (ex: GIE Transport Thiès)
   ↓
[Portée 4 : USER ROLE]    -> Activé selon le rôle (Chauffeur, Coxeur, Garagiste, Passager)
   ↓
[Portée 5 : PILOT USER]   -> Activé pour un compte de test spécifique (Whitelist)
```

### 3.2. Schéma Relationnel PostgreSQL (Supabase)

```sql
-- 1. Répertoire des modules compilés
CREATE TABLE public.system_modules (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    is_core BOOLEAN NOT NULL DEFAULT FALSE,
    min_app_version TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Dépendances entre modules
CREATE TABLE public.system_module_dependencies (
    module_id TEXT REFERENCES public.system_modules(id) ON DELETE CASCADE,
    depends_on_id TEXT REFERENCES public.system_modules(id) ON DELETE RESTRICT,
    PRIMARY KEY (module_id, depends_on_id)
);

-- 3. Règles d'activation dynamique (Feature Flags)
CREATE TABLE public.feature_flag_activations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_key TEXT NOT NULL,
    scope_type TEXT NOT NULL CHECK (scope_type IN ('platform', 'region', 'organization', 'role', 'user')),
    scope_id TEXT NOT NULL DEFAULT '*',
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    rollout_percentage INT NOT NULL DEFAULT 100 CHECK (rollout_percentage BETWEEN 0 AND 100),
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    config_payload JSONB DEFAULT '{}'::jsonb,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour résolution ultra-rapide (< 1ms)
CREATE INDEX idx_feature_flags_lookup 
ON public.feature_flag_activations (flag_key, scope_type, scope_id, is_enabled);

-- 4. Journal d'audit des modifications de flags
CREATE TABLE public.feature_flag_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_key TEXT NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    reason TEXT NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 3.3. Règle de Sécurité Cardinal : Flag ≠ Permission
- **Un Feature Flag n'est PAS un droit d'accès (RBAC)**.
- Le Feature Flag décide si la fonctionnalité existe dans l'application au runtime.
- Si le flag est actif, la politique RLS PostgreSQL et le token JWT contrôlent **qui** a le droit de lire ou d'écrire la donnée.
- **Double Barrière Obligatoire** :
  `Accès Accordé = FeatureFlag.isEnabled(context) && User.hasPermission(action)`.

---

## 4. CATALOGUE EXHAUSTIF DES FEATURE FLAGS & CLÉS TECHNIQUES

| Clé Technique du Flag | Domaine Métier | État Pilote (Phase 1) | État Cible | Comportement en cas de Désactivation |
| :--- | :--- | :---: | :---: | :--- |
| `FLAG_CORE_TRAVELER` | Recherche, trajet, passagers | **Actif** | **Actif** | Module cœur immuable. Ne peut pas être désactivé. |
| `FLAG_SEAT_LOCK_ENGINE` | Verrouillage atomique des sièges | **Actif** | **Actif** | Si désactivé, repli sur réservation sans sélection de siège (places libres). |
| `FLAG_PAYMENT_DIGITAL_WAVE` | Passerelle de paiement Wave Sénégal | **Actif** | **Actif** | Masquage du bouton Wave ; redirection vers Orange Money ou paiement espèces. |
| `FLAG_PAYMENT_DIGITAL_OM` | Passerelle Orange Money Sénégal | **Actif** | **Actif** | Masquage du bouton OM ; redirection vers Wave ou espèces. |
| `FLAG_TICKETING_HMAC_QR` | Billetterie QR signée HMAC-SHA256 | **Actif** | **Actif** | Si désactivé, le billet affiche une référence alphanumérique sécurisée. |
| `FLAG_FIELD_OPS_CAMERA_SCAN` | Scanner QR en direct via caméra | **Actif** | **Actif** | Masquage de la caméra ; bascule sur l'import d'image ou la saisie manuelle. |
| `FLAG_FIELD_OPS_GALLERY_IMPORT` | Validation par capture d'écran galerie | **Actif** | **Actif** | Désactivable instantanément par le Super Admin en cas de suspicion de fraude. |
| `FLAG_CASH_CLOSURE_CHAUFFEUR` | Clôture de caisse & ventilation net | **Actif** | **Actif** | Masquage du récapitulatif net ; conservation des reçus papier manuels. |
| `FLAG_VIRTUAL_WALLET` | Portefeuille virtuel de commissions | **Actif** | **Actif** | Solde figé en lecture seule ; écritures du grand livre toujours calculées. |
| `FLAG_AUTO_MOBILE_MONEY_PAYOUT` | Virement automatique vers Mobile Money | **Inactif** (En cours de validation légale) | **Actif** (Phase 4) | Gel des virements automatiques ; validation manuelle par l'administrateur GIE. |
| `FLAG_MULTI_TENANCY_GIE` | Espaces partitionnés pour les GIE | **Actif** | **Actif** | Les opérateurs accèdent uniquement aux données de leur organisation. |
| `FLAG_GARAGE_MARKETPLACE_SOS` | SOS Panne & Pack Garagiste | **Inactif** (Phase 5) | **Actif** (Phase 5) | L'alerte renvoie vers le numéro vert / WhatsApp d'assistance humaine directe. |
| `FLAG_MAAS_GTFS_INTERMODAL` | Intermodalité & données ouvertes GTFS | **Inactif** (Phase 6) | **Actif** (Phase 6) | L'application fonctionne en mode réservation de ligne directe standard. |
| `FLAG_SMART_FLEET_TELEMATICS` | Télématique IoT & capteurs OBD-II | **Inactif** (Phase 6) | **Actif** (Phase 6) | Les bus opèrent sans suivi de capteurs matériels connectés. |

---

## 5. RÉSILIENCE RÉSEAU, ZÉRO ÉCRAN BLANC & OFFLINE-FIRST

### 5.1. Éradication Définitive des Écrans Blancs sur Mobile
Un écran blanc ("White Screen of Death") survient généralement pour trois raisons identifiées et résolues dans Dioufy-TS :

1. **Blocage au Bootstrap Asynchrone :**
   - *Cause :* Une tentative de connexion réseau directe (ex. `Supabase.initialize()`) bloquait avant le premier `runApp()`.
   - *Solution Dioufy-TS :* Tout appel réseau au démarrage est encapsulé dans un `try/catch` non bloquant. Si le réseau est absent ou lent, l'application démarre instantanément en **Mode Offline** et présente l'interface en **0 milliseconde**.

2. **Absence de SplashScreen / Loader Web :**
   - *Cause :* Sur mobile web/PWA, pendant le téléchargement des scripts Flutter (Dart2JS / CanvasKit), le navigateur affiche une page vierge.
   - *Solution Dioufy-TS :* Un conteneur HTML/CSS natif dans `web/index.html` affiche immédiatement le logo Dioufy-TS avec un indicateur de chargement animé et un watchdog d'erreur affichant un bouton *"Recharger"*.

3. **Incompatibilité Hot Reload sur Web avec Plugins Natifs :**
   - *Cause :* Le Hot Reload (`r`) en environnement web ne peut pas recharger les bindings de nouveaux plugins natifs (`mobile_scanner`, `image_picker`).
   - *Solution Dioufy-TS :* Règle stricte pour les développeurs : utiliser le **Hot Restart (`R`)** ou redémarrer le serveur Flutter lors de l'ajout de dépendances.

### 5.2. Architecture de Cache "Stale-While-Revalidate"
Pour opérer sereinement dans les zones à connectivité instable (autoroute à péage, gares routières saturées, zones rurales) :
- Les Feature Flags, les gares desservies et les billets achetés sont stockés dans le **cache persistant local** (SQLite / SharedPreferences).
- À l'ouverture de l'application, les données en cache sont affichées **immédiatement**.
- Une requête en arrière-plan vérifie les mises à jour sans jamais bloquer l'utilisateur.
- Si le voyageur est hors-ligne, ses billets restent consultables avec leur **QR Code HMAC intact**.

---

## 6. FEUILLE DE ROUTE STRATÉGIQUE FUSIONNÉE (PHASES 0 À 6)

```
[Phase 0 : Cadrage & Pilote] ──► [Phase 1 : MVP Voyageurs & Billets] ──► [Phase 2 : Opérations Terrain & Scan]
                                                                                       │
[Phase 5 : Marketplace Garagiste] ◄── [Phase 4 : Grand Livre & Caisses] ◄── [Phase 3 : RBAC & Flotte GIE]
           │
           ▼
[Phase 6 : MaaS Intermodal, ABT & Smart Fleet IoT]
```

---

### Phase 0 — Cadrage Opérationnel, Juridique & Lignes Pilotes (Semaines 0 à 2)
*Objectif : Valider le modèle économique et contractuel avant tout investissement technique lourd.*

- **Lignes de Démonstration Ciblées :**
  - Axe 1 : Dakar (Gare des Baux Maraîchers / Colobane) ↔ Thiès (Gare Routière).
  - Axe 2 : Dakar ↔ Mbour.
  - Axe 3 : Dakar ↔ Touba (axe à très forte affluence religieuse et commerciale).
- **Conventions Opérateurs Pilotes :**
  - Signer un accord de partenariat avec 1 à 3 GIE ou compagnies reconnues.
  - Recueil des données opérationnelles : grilles horaires réelles, tarifs en FCFA, plans de sièges (bus 50 places, minibus 14-24 places), tolérances de retard.
- **Canaux de Paiement Terrain :**
  - Intégration prioritaire de **Wave Sénégal** (taux de pénétration > 80%) et **Orange Money**.
  - Définition contractuelle des frais de transaction et du compte séquestre de cantonnement.
- **Livrables :**
  - Grille tarifaire officielle validée en **FCFA (XOF)**.
  - Charte de traitement des annulations, pannes et remboursements passagers.
- **Critère de Sortie Formel :** Un transporteur partenaire met à disposition une semaine de départs réels avec engagement ferme sur les sièges attribués.

---

### Phase 1 — MVP Voyageurs & Billettique Numérique Autonome (Semaines 1 à 6)
*Objectif : Permettre à un voyageur de trouver, réserver, payer son trajet et générer son billet QR sans incident.*

- **Parcours Utilisateur Voyageur :**
  - Écran d'accueil mobile-first avec sélecteur de villes rapides et bouton d'interversion rapide ($\rightleftharpoons$).
  - Sélecteur de date (Aujourd'hui, Demain, Calendrier) et compteur de passagers (1 à 4 places).
  - Liste de résultats temps réel avec filtrage par opérateur, durée estimée et affichage du prix en FCFA (badge `XOF`).
  - Plan de sièges interactif réaliste (configuration 2+couloir+2, cockpit conducteur identifié, places sélectionnées, réservées ou occupées).
  - Formulaire voyageur simplifié (Nom complet, Téléphone sénégalais normalisé `+221...`).
- **Moteur de Réservation Atomique (Anti-Surbooking) :**
  - Transition d'états transactionnelle : `available` $\rightarrow$ `held` (verrou 10 minutes) $\rightarrow$ `booked` (après webhook) ou retour automatique à `available` en cas d'abandon.
- **Paiement & Sécurisation Serveur :**
  - Intégration des webhooks idempotents avec signature de requête.
  - Interdiction formelle de valider un paiement sur la seule foi du client mobile.
- **Billet Boarding Pass Sécurisé :**
  - Billet avec identifiant lisible (ex: `DIOUFY-TH-82934`).
  - QR Code chiffré/signé contenant l'identifiant opaque, le timestamp UTC et une signature **HMAC-SHA256**.
  - Bouton de partage direct du justificatif certifié sur WhatsApp.
  - Espace **« Mes Billets »** 100% accessible en mode hors-ligne.
- **Critère de Sortie Formel :** Un voyageur réel achète son billet en FCFA via Mobile Money et dispose d'un QR code infalsifiable dans son téléphone.

---

### Phase 2 — Opérations Terrain & Contrôle d'Embarquement Tri-Canal (Semaines 7 à 10)
*Objectif : Fournir aux chauffeurs et coxeurs un outil d'embarquement ultra-rapide (< 5 secondes par voyageur).*

- **Espace Chauffeur & Coxeur Dédié :**
  - Écran épuré à fort contraste utilisable en plein soleil sur les quais de gare.
- **Architecture de Contrôle en 3 Canaux :**
  1. **Scan Caméra Temps Réel :** Détection automatique du QR Code dès apparition dans le viseur (`mobile_scanner`), avec bouton d'activation du flash/torche pour les départs de nuit.
  2. **Import d'Image / Capture Galerie :** Pour les voyageurs ayant l'écran de smartphone brisé ou ayant reçu leur billet par capture WhatsApp d'un tiers. Validation avec vérification anti-rejeu et trace d'audit renforcée.
  3. **Saisie Manuelle de Secours :** Clavier numérique adapté pour taper la référence du billet en cas de lentille de caméra endommagée.
- **Sécurité & Contrôle Anti-Doublon :**
  - Vérification instantanée : Statut `Valide`, `Billet Déjà Embarqué` (avec heure et nom de l'agent l'ayant validé), ou `Billet Inexistant / Annulé`.
  - Mode hors-ligne temporaire d'embarquement avec réconciliation asynchrone dès retour du réseau.
- **Critère de Sortie Formel :** Un agent de quai contrôle un bus de 50 passagers en moins de 4 minutes, sans contestation ni double embarquement.

---

### Phase 3 — RBAC Organisationnel, Multi-Tenancy GIE & Gestion de Flotte (Semaines 11 à 14)
*Objectif : Partitionner hermétiquement les données entre transporteurs concurrents au sein de la plateforme.*

- **Modèle RBAC à 2 Niveaux :**
  - *Niveau 1 (Plateforme Dioufy-TS) :* Super-Admin, Administrateur Support, Auditeur Financier.
  - *Niveau 2 (Organisation / GIE) :* Gérant GIE, Gestionnaire de Flotte, Chauffeur Titulaire, Coxeur / Agent de Gare affilié, Garagiste Agréé.
- **Schéma de Données Multi-Tenancy :**
  - Tables `organizations`, `organization_memberships`, `vehicles`, `vehicle_assignments`, `driver_assignments`.
  - Politiques RLS PostgreSQL garantissant qu'un gestionnaire du *GIE Transport Thiès* ne peut en aucun cas visualiser les recettes ou passagers du *GIE Ndiambour*.
- **Journal d'Audit Centralisé (`audit_logs`) :**
  - Traçabilité non modifiable de toute action sensible : création de ligne, modification d'horaire, changement de tarif, réattribution de bus.
- **Critère de Sortie Formel :** Deux compagnies concurrentes opèrent sur la même plateforme sans fuite de données réciproques.

---

### Phase 4 — Grand Livre Financier (Double-Entrée), Commissions & Clôture de Caisse (Semaines 15 à 18)
*Objectif : Assurer une transparence financière mathématique absolue entre chauffeurs, coxeurs, GIE et Dioufy-TS.*

- **Grand Livre Comptable Immuable (Double-Entry Ledger) :**
  - Interdiction formelle du champ mutable `balance = balance + montant`.
  - Toute transaction financière fait l'objet d'écritures immuables (Débit / Crédit) :
    * `ledger_accounts` (Comptes séquestre, comptes exploitant, comptes commissions).
    * `ledger_entries` (Montant en FCFA entiers, référence, horodatage UTC, signature).
  - Le solde d'un portefeuille est la somme calculée de ses écritures validées.
- **Moteur de Commissions Configurable :**
  - Commission Chauffeur (ex: 5% du chiffre d'affaires du voyage, versée à l'arrivée).
  - Commission Coxeur / Agent commercial (forfait par billet vendu/embarqué en gare).
  - Commission Plateforme Dioufy-TS (frais de service prélevés à la source).
- **Module Clôture de Caisse Chauffeur :**
  - Ventilation en temps réel des encaissements : **Total Billets Espèces** vs **Total Billets Digitaux (Wave/OM)**.
  - Déduction automatisée des commissions acquises par le chauffeur et des frais d'étape.
  - Calcul du **Solde Net à Reverser** au GIE.
  - Génération en 1 clic d'un **Bordereau de Caisse WhatsApp** prêt à être envoyé au régulateur de la gare.
  - Dialogue de transfert sécurisé vers le compte Mobile Money avec garde-fous d'idempotence.
- **Critère de Sortie Formel :** Chaque franc CFA collecté sur un trajet est tracé de l'encaissement passager jusqu'au reversement final au transporteur.

---

### Phase 5 — Marketplace d'Assistance, SOS Panne & Pack Garagiste (Semaines 19 à 24)
*Objectif : Réduire le temps d'immobilisation des bus en panne sur les routes nationales sénégalaises.*

- **Bouton SOS Panne Chauffeur :**
  - Déclenchement d'une alerte géolocalisée (coordonnées GPS précises, axe routier ex: RN1 ou Autoroute Ila Touba).
  - Typologie de panne (Crevaison, Surchauffe moteur, Système de freinage, Panne électrique).
  - Signalement du nombre de passagers à bord pour gestion éventuelle d'un transbordement.
- **Gestion des Formules « Pack Garagiste » :**
  - Formules gérées par le Super-Admin : *Basic*, *Standard*, *Premium*.
  - Paramétrage des plafonds d'intervention, de la franchise et du délai maximal d'intervention garanti (SLA).
- **Réseau de Garagistes Partenaires de Proximité :**
  - Application dédiée pour les garages agréés situés le long des corridors routiers.
  - Réception de la notification de panne dans un rayon de 20 km.
  - Acceptation de mission, confirmation du délai d'arrivée et devis standardisé.
  - Clôture d'intervention avec photos horodatées avant/après réparation.
- **Protection de la Vie Privée & Données Personnelles :**
  - La position GPS du véhicule n'est partagée qu'au moment précis du déclenchement du SOS.
  - Masquage des numéros de téléphone personnels via un système de proxy d'appel ou identifiant anonymisé.
- **Critère de Sortie Formel :** Une simulation de panne sur l'axe Dakar–Thiès mobilise un mécanicien partenaire agréé en moins de 30 minutes avec rapport chiffré dans l'application.

---

### Phase 6 — Industrialisation MaaS, Billettique Unifiée ABT & Smart Fleet IoT (Mois 6 à 15)
*Objectif : Transformer Dioufy-TS en plateforme nationale de mobilité multimodale intelligente.*

- **Architecture MaaS (Mobility as a Service) & Intermodalité :**
  - Modèle de données intermodal combinant plusieurs segments : Navette locale / Urbain $\rightarrow$ Bus interurbain régional $\rightarrow$ Dernier kilomètre (VTC / Taxi collectif).
  - Standardisation des flux via les spécifications internationales **GTFS Schedule** et **GTFS-Realtime**.
  - APIs ouvertes et sécurisées (OAuth 2.0 / OpenAPI) pour l'interconnexion avec les réseaux de transport publics (TER, BRT Dakar) et les plateformes partenaires.
- **Billettique Unifiée & Account-Based Ticketing (ABT) :**
  - Évolution vers le compte de mobilité centralisé où le titre de transport réside sur le serveur.
  - Support du QR Code dynamique à rafraîchissement périodique (anti-capture d'écran).
  - Intégration future du sans-contact NFC et des cartes prépayées physiques pour les voyageurs sans smartphone.
- **Smart Fleet & Télématique IoT :**
  - Connexion aux boîtiers télématiques OBD-II embarqués dans les autocars.
  - Télémétrie de base : position GPS continue, vitesse, consommation de carburant, diagnostic moteur en direct.
  - Maintenance préventive : détection anticipée des anomalies mécaniques avant rupture en cours de voyage.
- **IA Pragmatique au Service de l'Exploitation :**
  - Optimisation dynamique des grilles horaires selon la saisonnalité (Magal de Touba, Gamou de Tivaouane, vacances scolaires).
  - Interdiction stricte de toute tarification discriminatoire opaque : les tarifs restent régulés et transparents.
- **Critère de Sortie Formel :** Dioufy-TS publie un flux GTFS complet de ses lignes partenaires et traite des trajets combinés interurbains.

---

## 7. SÉCURITÉ, CONFORMITÉ MONÉTAIRE (UEMOA / BCEAO) & AUDITABILITÉ

### 7.1. Conformité Monétaire Régionale (Sénégal & Zone UEMOA)
- **Monnaie Exclusive :** Tous les montants financiers sont exprimés et stockés en **FCFA (XOF)** sous forme d'entiers stricts (`BIGINT`) ou de `DECIMAL(12, 2)` pour éviter tout problème d'arrondi à virgule flottante.
- **Interdiction Formelle du Dollar :** Aucun écran voyageur ou chauffeur ne doit comporter le symbole `$`. L'icône financière officielle est un cercle contenant la mention `XOF` ou l'abréviation textuelle `FCFA`.
- **Statut Réglementaire :** Dioufy-TS opère en qualité d'intermédiaire technique et agrégateur de flux. Les fonds collectés transitent par des établissements de monnaie électronique agréés par la BCEAO (Wave Digital Finance, Orange Finances Mobiles Sénégal). Aucun portefeuille d'épargne non cantonné n'est exploité sans licence bancaire.

### 7.2. Sécurité Applicative & Cryptographie
- **Secrets & Clés d'API :** Aucune clé privée de paiement ni secret administrateur Supabase (`service_role`) n'est embarqué dans le code Flutter. Toute opération sensible transite par des fonctions serveurs sécurisées (Edge Functions / API REST Yoga).
- **Signature Cryptographique des Billets :**
  Le QR Code généré n'expose aucune donnée personnelle en clair. Il contient un jeton condensé :
  $$\text{Payload} = \text{Base64URL}(\text{ticket\_id} \,\|\, \text{trip\_id} \,\|\, \text{seat\_number} \,\|\, \text{issue\_timestamp})$$
  $$\text{Signature} = \text{HMAC-SHA256}(\text{Payload}, \text{SecretKey})$$
  Le contrôleur vérifie la validité mathématique du billet même hors-ligne avec la clé publique correspondante.
- **Conformité OWASP MASVS (Mobile Application Security) :**
  - Chiffrement du stockage local sur l'appareil mobile.
  - Protection contre l'écoute réseau via SSL Pinning sur les endpoints financiers.
  - Détection du Root / Jailbreak sur les terminaux de contrôle des agents de gare.

---

## 8. MATRICE D'ACTIVATION DES MODULES & CHECKLIST DE DÉPLOIEMENT

### 8.1. Matrice des Modules Compilés Dioufy-TS

| Module | Flag Associé | Niveau d'Isolation | Dépendance Requise | Statut Actuel |
| :--- | :--- | :---: | :--- | :---: |
| **Traveler Search & Booking** | `FLAG_CORE_TRAVELER` | Module Cœur | Socle `core/` | **Compilé & Fonctionnel** |
| **Seat Locking Engine** | `FLAG_SEAT_LOCK_ENGINE` | Module Cœur | `module_traveler` | **Compilé & Fonctionnel** |
| **Wave / OM Payment** | `FLAG_PAYMENT_DIGITAL_WAVE` | Module Activé | `module_booking` | **Compilé & Fonctionnel** |
| **HMAC-SHA256 Boarding Pass** | `FLAG_TICKETING_HMAC_QR` | Module Activé | `module_payment` | **Compilé & Fonctionnel** |
| **Tri-Channel Field Scanner** | `FLAG_FIELD_OPS_CAMERA_SCAN` | Module Activé | `module_ticketing` | **Compilé & Fonctionnel** |
| **Chauffeur Cash Closure** | `FLAG_CASH_CLOSURE_CHAUFFEUR`| Module Activé | `module_ticketing` | **Compilé & Fonctionnel** |
| **Double-Entry Financial Ledger** | `FLAG_DOUBLE_ENTRY_LEDGER` | Module Activé | `module_cash_closure` | **Prévu (Phase 4)** |
| **Multi-Tenancy GIE Flotte** | `FLAG_MULTI_TENANCY_GIE` | Module Activé | `module_fleet_mgmt` | **Prévu (Phase 3)** |
| **Marketplace SOS Garagiste** | `FLAG_GARAGE_MARKETPLACE_SOS`| Module Activé | `module_fleet_mgmt` | **Prévu (Phase 5)** |
| **MaaS & Smart Fleet IoT** | `FLAG_MAAS_GTFS_INTERMODAL` | Module Activé | `module_fleet_mgmt` | **Prévu (Phase 6)** |

### 8.2. Checklist Qualité Avant Toute Mise en Production

```markdown
- [x] Règle Monétaire : 100% des prix et commissions affichés en FCFA / badge XOF (zéro dollar).
- [x] Navigation : Bouton retour arrière systématique sur chaque écran (Navigator.canPop).
- [x] Stabilité Mobile : Initialisation Supabase encapsulée dans try/catch (zéro écran blanc au démarrage).
- [x] Contrôle d'Embarquement : 3 canaux disponibles (Caméra, Galerie, Saisie Manuelle).
- [x] Clôture de Caisse : Déduction automatique commission 5% chauffeur et calcul solde net à reverser.
- [x] Tests Automatisés : Suite de tests unitaires et widgets validée au vert (14/14 tests passants).
- [x] Hygiène IA : Répertoire ai/error_logs purgé de tout résidu de crash.
- [x] Confidentialité Git : Zéro git push vers les dépôts distants (développement 100% local).
```

---

## 9. CONCLUSION & ENGAGEMENT TECHNIQUE
Cette feuille de route unifiée constitue la **vérité terrain et architecturale unique** pour le projet **Dioufy-TS**. En associant des **modules compilés robustes** et un **moteur de Feature Flags dynamique piloté par le serveur**, Dioufy-TS garantit :
1. La rapidité d'exécution sur le terrain pour les voyageurs et chauffeurs sénégalais.
2. La flexibilité opérationnelle pour les GIE partenaires.
3. La stabilité absolue de l'application sans risque de régression ni d'écran blanc.
4. Une évolutivité sans faille vers la mobilité multimodale connectée de demain.