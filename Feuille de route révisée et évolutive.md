Principes d’évolution recommandés
1. Ne pas construire un « super-app » avant de valider la vente de billets
La priorité commerciale reste :

un voyageur recherche → réserve → paie → reçoit son billet → embarque sans incident.

Le projet possède déjà les entités de base nécessaires à ce chemin : trips, seats et bookings, ainsi que les statuts de disponibilité des sièges et de paiement. 

Les extensions métier doivent être ajoutées par couches :

mobilité et billet ;

opérations terrain ;

règlement / commissions ;

assistance et marketplace ;

interopérabilité MaaS et données temps réel ;

innovation IoT / IA, uniquement après disponibilité de données fiables.

2. Séparer les domaines métier
Éviter une seule base logique où tous les rôles modifient directement les mêmes données. Structurer l’application autour de domaines :

Domaine	Responsabilité
Identity & Access	comptes, rôles, organisations, permissions
Catalogue transport	opérateurs, véhicules, lignes, trajets, horaires
Réservation	disponibilités, verrouillage de siège, réservation
Paiement	intention de paiement, webhook, remboursement
Billettique	billet, QR dynamique, validation, anti-rejeu
Règlement	commissions, soldes, reversements, caisse
Assistance	pannes, géolocalisation, demande, intervention
Marketplace	garagistes, packs, SLA, facturation, évaluation
Données mobilité	positions, occupation, ETA, données ouvertes/API
Cela permet d’ajouter de nouveaux acteurs sans fragiliser le cœur de réservation.

3. Concevoir « API-first » et « event-first »
Pour évoluer vers une plateforme transport, appliquer dès maintenant :

APIs versionnées et documentées avec OpenAPI ;

identifiants immuables (UUID) et horodatages en UTC ;

webhooks signés et idempotents pour les paiements ;

événements métier : booking.confirmed, ticket.issued, ticket.boarded, payment.settled, payout.released, breakdown.created ;

journal d’audit non modifiable pour les actions financières et de contrôle ;

mécanisme d’outbox pour ne pas perdre les événements lorsqu’une transaction est confirmée ;

séparation stricte entre données de production, staging et tests.

Feuille de route révisée et évolutive
Phase 0 — Cadrage, conformité et pilote terrain
Durée : 1 à 2 semaines

Objectif
Définir un pilote exploitable avec de vrais opérateurs, voyageurs, chauffeurs et agents de contrôle.

Livrables
Sélection de 1 à 3 GIE/opérateurs pilotes et de lignes limitées.

Cartographie des rôles : voyageur, agent de gare/coxeur, chauffeur, responsable flotte, garagiste, support, administrateur, super-admin.

Règles d’annulation, de remboursement, de litige, de paiement en liquide et de reversement.

Choix du ou des prestataires de paiement et validation contractuelle/juridique.

Analyse de protection des données : téléphone, position GPS, identité, paiement et historique de voyages.

Définition des SLA : disponibilité, délai de support, délai d’assistance, délai de reversement.

Garde-fous
Ne pas lancer de portefeuille interne ou de retrait de fonds avant validation réglementaire et contractuelle.

Ne pas promettre du dépannage « immédiat » sans réseau de garagistes, couverture territoriale et mécanisme d’escalade.

Phase 1 — MVP voyageurs et billet numérique
Durée : semaines 1 à 6

Objectif
Vendre, payer et contrôler un billet sur des trajets réels.

Fonctionnalités
Inscription et authentification.

Recherche : départ, destination, date, filtre d’horaire.

Résultats réels depuis Supabase.

Détail de trajet : compagnie, prix, capacité et places restantes.

Sélection d’un siège.

Verrouillage temporaire atomique du siège.

Paiement et confirmation serveur par webhook.

Billet numérique, référence et QR code.

« Mes voyages », annulation et support de premier niveau.

Back-office minimal pour publier les trajets et visualiser les réservations.

Écart à combler dans le code actuel
L’accueil contient bien les champs départ/destination, mais la navigation ne transmet pas les valeurs saisies ; l’écran de résultats est encore statique. 

Critère de sortie
Un voyageur réel peut acheter un billet, et un agent peut vérifier ce billet sur le terrain.

Phase 2 — Opérations terrain et RBAC étendu
Durée : semaines 7 à 10

Objectif
Faire fonctionner l’activité quotidienne avec plusieurs organisations et responsabilités, sans donner des droits excessifs.

Fonctionnalités RBAC
Créer un modèle en deux niveaux :

rôle global : super-admin, support plateforme ;

rôle dans une organisation : administrateur GIE, gestionnaire flotte, chauffeur, coxeur/agent embarquement, mécanicien/garagiste.

Ne pas limiter profiles.role à un seul rôle global. Le modèle actuel contient un rôle unique (passenger, driver, admin) ; il faudra le faire évoluer vers des organisations, affiliations et permissions. 

Tables recommandées
organizations

organization_memberships

roles

permissions

vehicles

vehicle_assignments

driver_assignments

boarding_agents

audit_logs

Règles essentielles
un chauffeur ne gère que les courses et véhicules qui lui sont affectés ;

un coxeur ne valide que les billets de son trajet, de son gare ou de son opérateur ;

un gestionnaire flotte ne voit que sa flotte ;

un super-admin dispose d’un accès exceptionnel, journalisé et soumis à double contrôle pour les opérations sensibles ;

toute modification d’un tarif, d’un paiement, d’une réservation ou d’un droit est auditée.

Contrôle de billets renforcé
Implémenter trois canaux, dans cet ordre :

scan caméra temps réel ;

saisie manuelle de la référence ;

import d’image QR depuis la galerie, avec avertissement et piste d’audit.

Le scan QR et le scanner sont déjà envisagés dans les dépendances Flutter. 

Mesures de sécurité pour le QR
le QR ne doit pas contenir de données personnelles lisibles ;

le code doit être signé ou être un jeton opaque à durée limitée ;

la validation doit détecter les billets déjà embarqués ;

l’action d’embarquement doit être horodatée, associée à l’agent et synchronisée ;

un mode hors-ligne doit être limité dans le temps et resynchronisé ;

importer une image doit déclencher un contrôle plus strict, car une capture peut être réutilisée ou falsifiée.

Critère de sortie
Les agents, chauffeurs et gestionnaires peuvent opérer le pilote sans accès administrateur global.

Phase 3 — Grand livre financier, commissions et clôture de caisse
Durée : semaines 11 à 14

Objectif
Mettre en place des commissions et reversements fiables, avant de permettre tout transfert vers Mobile Money.

Principe fondamental : un portefeuille n’est pas un simple champ balance
Ne pas stocker un solde modifiable sans historique. Mettre en œuvre un grand livre comptable à double entrée :

chaque écriture est immuable ;

chaque crédit a une contrepartie ;

le solde est calculé à partir des écritures ;

les corrections sont faites par écritures compensatoires, jamais en modifiant l’historique ;

chaque écriture porte une référence de réservation, paiement, acteur, règle de commission et date.

Tables recommandées
ledger_accounts

ledger_entries

commission_rules

commission_accruals

cash_collections

cash_closures

payout_requests

payouts

reconciliations

disputes

Règles de commissions
Définir des règles versionnées :

commission chauffeur : à la fin du trajet validé ;

commission coxeur : après vente/embarquement, selon la règle choisie ;

commission plateforme ;

retenues, ajustements et remboursements ;

délai de disponibilité : instantané, H+24, hebdomadaire ou après période de contestation.

Clôture de caisse chauffeur
Le tableau de bord doit séparer explicitement :

billets payés en liquide ;

paiements digitaux confirmés ;

paiements en attente ou échoués ;

commissions acquises ;

montants dus à l’opérateur ;

solde à reverser ;

écarts de caisse ;

justificatifs de dépôt ou de transfert.

Contrôles anti-fraude
idempotence de chaque paiement et reversement ;

seuils de retrait et limites quotidiennes ;

validation renforcée pour changement de numéro Mobile Money ;

séparation des fonctions : l’utilisateur qui crée une règle de commission ne valide pas seul un reversement ;

rapprochement quotidien avec le prestataire de paiement ;

alertes d’anomalie : remboursements répétés, tickets validés plusieurs fois, encaissement espèces incohérent.

Référentiels à appliquer
PCI DSS : utiliser les pages ou SDK de paiement du prestataire ; ne jamais stocker les données de carte.

OWASP ASVS / MASVS : sécurisation web/mobile, gestion de session, secrets et stockage local.

ISO/IEC 27001 : système de management de la sécurité et gestion des risques.

exigences locales de paiement, de monnaie électronique, de protection des données et obligations de lutte contre la fraude, à valider avec un conseil spécialisé avant ouverture des transferts.

Critère de sortie
Chaque franc lié à un billet peut être tracé : encaissement, commission, remboursement, reversement ou écart.

Phase 4 — Marketplace d’assistance et Pack Garagiste
Durée : semaines 15 à 20

Objectif
Ajouter l’assistance sans confondre mise en relation, assurance, dépannage et gestion de flotte.

Fonctionnalités
Côté chauffeur / flotte
bouton d’alerte panne ;

type de panne et niveau d’urgence ;

position GPS volontaire, précise et horodatée ;

véhicule, trajet, nombre de passagers concernés ;

pièces jointes facultatives ;

suivi du statut : signalée, assignée, en route, sur place, résolue, annulée ;

solution de continuité : information voyageurs, véhicule de remplacement, annulation.

Côté garagiste
profil professionnel ;

zones couvertes, horaires, compétences et équipements ;

disponibilité active ;

réception d’une demande ;

acceptation/refus avec délai estimé ;

navigation vers le point d’intervention ;

devis, photos avant/après et validation d’intervention ;

notation réciproque et gestion de litige.

Côté super-admin
création de formules Basic / Standard / Premium ;

plafonds de couverture et exclusions ;

zones de couverture ;

facturation mensuelle ou annuelle ;

activation, suspension et vérification des partenaires ;

suivi SLA, qualité, litiges et fraude.

Protection des utilisateurs
demander la permission GPS seulement au moment nécessaire ;

afficher clairement qui reçoit la localisation et pendant combien de temps ;

réduire la précision ou supprimer la localisation après résolution selon la politique de rétention ;

ne pas exposer le numéro personnel du chauffeur sans mécanisme de relais ;

prévoir un canal d’escalade humain pour les situations dangereuses ;

ne pas automatiser une décision de sécurité routière à partir d’une simple prédiction.

Critère de sortie
Une panne réelle peut être signalée, affectée, suivie et clôturée avec preuve, délai et audit.

Phase 5 — Industrialisation, interopérabilité et données transport
Durée : mois 6 à 9

Objectif
Passer d’un pilote d’opérateurs à une plateforme multi-opérateurs intégrable.

Standards d’échange recommandés
Domaine	Standard / pratique
Horaires, arrêts, lignes et calendriers	GTFS Schedule
Positions véhicules, perturbations et prévisions	GTFS-Realtime
APIs partenaires	OpenAPI, versionnement et OAuth 2.0 / OpenID Connect
Accessibilité web	WCAG 2.2 au niveau AA comme cible
Devise et montants	montants entiers en devise mineure ; code ISO 4217
Dates et temps	UTC dans le stockage, ISO 8601 dans les APIs
Qualité et traçabilité	SLO, journalisation structurée, métriques et alertes
Architecture MaaS
Concevoir les données autour de :

arrêt (stop) ;

segment de trajet (leg) ;

itinéraire (itinerary) ;

correspondance ;

opérateur ;

mode de transport ;

produit tarifaire ;

titre de transport ;

règle tarifaire ;

événement de mobilité.

Ainsi, un voyage ne devient pas seulement « Dakar → Thiès », mais une composition : navette locale → bus interurbain → dernier kilomètre. Les tables actuelles de trajets et sièges peuvent rester le cœur de la première étape, puis être enrichies progressivement. 

Billettique unifiée et ABT
Introduire l’Account-Based Ticketing progressivement :

QR signé pour le MVP ;

compte voyageur et droits de voyage gérés côté serveur ;

QR dynamique avec durée courte ;

support NFC seulement si les terminaux, cartes ou appareils terrain le justifient ;

pass régional / interopérabilité seulement après accords institutionnels et techniques.

Ne pas commencer par le NFC ou des cartes physiques : le QR dynamique est plus rapide à lancer et plus simple à déployer sur les smartphones existants.

Critère de sortie
Un partenaire peut importer des horaires ou consommer une API versionnée sans accès direct à la base de données.

Phase 6 — Smart Fleet, télématique et optimisation
Durée : mois 9 à 15

Objectif
Exploiter des données de flotte réelles pour améliorer la ponctualité, la sécurité et la maintenance.

Étapes
Télématique de base

GPS, vitesse, position, kilométrage, état de connexion ;

consentement, politique de conservation et visibilité par rôle ;

alertes simples de déviation ou arrêt prolongé.

Opérations

ETA calculée ;

information voyageurs sur retard ou annulation ;

supervision flotte ;

taux de remplissage issu des billets validés.

Maintenance

historique des incidents ;

échéancier de maintenance préventive ;

alertes de seuils ;

intégration capteurs/OBD lorsque les véhicules et données le permettent.

Optimisation

ajustement d’offre fondé sur la demande réelle ;

planification des capacités ;

DRT limité à des zones/pilotes spécifiques ;

analyse météo et trafic uniquement avec sources fiables.

IA : règles de prudence
L’IA ne doit pas être le point de départ. Elle devient utile après accumulation de données fiables, complètes et représentatives.

Commencer par :

prévision explicable de demande ;

détection d’anomalies ;

estimation d’ETA ;

suggestion de maintenance.

Éviter au départ :

tarification personnalisée opaque selon le « profil passager » ;

décisions automatiques de sécurité ;

suppression d’itinéraires sans validation humaine ;

modèle de maintenance prédictive sans données capteurs vérifiées.

Critère de sortie
Les données de flotte améliorent concrètement la ponctualité ou la disponibilité des véhicules, avec des indicateurs mesurés.

Exigences transverses à appliquer à chaque phase
Sécurité et confidentialité
chiffrement en transit ;

secrets hors du code source ;

contrôle d’accès minimal ;

authentification renforcée pour les rôles sensibles ;

audit immuable des actions financières ;

tests de sécurité avant mise en production ;

sauvegardes testées et plan de reprise ;

limitation de conservation des données personnelles ;

mécanismes pour exporter, corriger ou supprimer les données lorsque requis.

Le code actuel initialise Supabase avec des valeurs de démonstration ; la configuration réelle devra être injectée de manière sécurisée selon l’environnement. 

Fiabilité opérationnelle
indicateurs de disponibilité ;

alertes de paiement échoué et de webhook non traité ;

tableau de suivi des réservations bloquées ;

plan de support hors ligne lors des départs ;

procédure de gestion manuelle d’un billet en cas d’incident réseau ;

sauvegarde et reprise des actions critiques.

Accessibilité et inclusion
libellés simples en français et, si possible, langues locales prioritaires ;

contraste suffisant ;

zones tactiles larges ;

parcours adapté aux appareils Android modestes et connexions instables ;

montant et devise visibles ;

confirmation explicite avant paiement ou annulation ;

possibilité de retrouver un billet via téléphone/référence, pas uniquement via smartphone récent.

Décision de priorisation
À développer immédiatement après le MVP
RBAC organisations / GIE / chauffeurs / agents.

Scanner QR caméra + mode manuel audité.

Back-office flotte et contrôle de départ.

Journal d’audit.

Grand livre de commissions sans retrait instantané initialement.

À développer seulement après validation opérationnelle
Reversement Mobile Money automatisé.

Clôture de caisse avec rapprochement.

Pack Garagiste et marketplace d’assistance.

Géolocalisation de pannes.

APIs partenaires et GTFS.

NFC, pass mobilité et ABT avancé.

IoT, maintenance prédictive, DRT et IA tarifaire.

Cette séquence permet d’obtenir rapidement un produit opérationnel sans faire porter au premier lancement le risque combiné des paiements, de la caisse, de l’assistance d’urgence et de la télématique.

Vérifications

✅ nl -ba lib/main.dart — vérification du point d’initialisation Supabase et des valeurs de configuration à remplacer. 

✅ nl -ba lib/features/home/home_screen.dart et nl -ba lib/features/search/search_results_screen.dart — vérification que le flux de recherche reste à connecter aux données réelles. 

✅ nl -ba supabase/schema.sql — vérification du modèle actuel pour profils, trajets, sièges, réservations et politiques d’accès. 

✅ nl -ba pubspec.yaml — vérification de la présence des dépendances prévues pour le paiement, les QR codes, le scan, la carte et les notifications. 

⚠️ curl -L ... pcisecuritystandards.org, owasp.org, w3.org, gtfs.org, iso.org — recherches externes bloquées par le proxy réseau de l’environnement (CONNECT tunnel failed, response 403).