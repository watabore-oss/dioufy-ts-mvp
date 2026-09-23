### Feuille de route MVP — Dioufy-TS voyageurs
# Objectif produit
Mettre en ligne rapidement une application mobile permettant à un voyageur de :

trouver un trajet ;

comparer les départs et les prix ;

choisir une place ;

payer ;

recevoir un billet numérique/QR code ;

présenter ce billet lors de l’embarquement.

Le socle actuel est cohérent pour démarrer : l’application Flutter initialise Supabase, possède un écran de recherche et un schéma de données pour les trajets, sièges et réservations. 

Priorités : ce qu’il faut livrer, et ce qu’il faut repousser
À livrer dans le MVP voyageurs
Inscription / connexion par téléphone ou e-mail.

Recherche de trajets : départ, destination, date, nombre de voyageurs.

Liste de trajets réels : heure, compagnie, prix, places restantes.

Détail d’un trajet et sélection de siège.

Création de réservation avec prévention des doubles réservations.

Paiement mobile / carte via le prestataire choisi.

Billet avec QR code, référence de réservation et statut de paiement.

Historique « Mes voyages ».

Annulation ou demande de support simple.

Interface d’administration minimale pour alimenter les trajets et suivre les réservations.

À repousser après le MVP
Carte interactive avancée.

Programme de fidélité et codes promo.

Chat en direct.

Géolocalisation temps réel des bus.

Multilingue complet.

Marketplace multi-opérateurs très avancée.

Paiement fractionné, portefeuille interne, parrainage.

Algorithmes complexes de recommandation.

La carte du Sénégal existe déjà dans l’écran d’accueil, mais elle n’est pas critique au premier lancement : l’effort doit aller vers le flux recherche → place → paiement → billet. 

Roadmap recommandée — 6 à 8 semaines
Phase 0 — Cadrage opérationnel (2 à 4 jours)
Décisions à prendre
Définir la première zone : par exemple Dakar ↔ Thiès, puis quelques lignes très demandées.

Signer avec 1 à 3 transporteurs pilotes capables de fournir :

horaires ;

tarifs ;

capacité des véhicules ;

plan des sièges ;

règles d’annulation ;

procédure d’embarquement.

Choisir le canal de paiement réellement disponible pour les voyageurs ciblés.

Désigner qui crée les trajets et qui valide les billets à la gare.

Livrables
Catalogue initial de lignes et d’horaires.

Maquettes courtes des écrans essentiels.

Règles produit écrites : délai de réservation, annulation, remboursement, siège non payé, billet utilisé.

Compte Supabase de production/staging et projet de paiement de test.

Critère de sortie
Un opérateur pilote peut fournir au moins une semaine de trajets réels, avec des sièges et prix fiables.

Phase 1 — Rendre l’infrastructure utilisable (Semaine 1)
1. Configurer correctement Supabase
Remplacer les valeurs fictives utilisées à l’initialisation par des variables de configuration distinctes pour développement et production ; elles ne doivent pas être codées en dur. 

Mettre en place :

authentification e-mail ou téléphone ;

environnements dev et prod ;

migrations SQL versionnées ;

sauvegarde et contrôle d’accès ;

journalisation des erreurs.

2. Compléter le schéma de données
Le schéma existant constitue une bonne base : profiles, trips, seats et bookings. 

À ajouter rapidement :

operators / companies : nom, logo, contacts, statut ;

vehicles : immatriculation interne, capacité, opérateur ;

trip_operator ou operator_id sur trips ;

tickets : code unique, QR payload, statut (valid, used, cancelled) ;

payments : référence prestataire, montant, devise, statut, réponse webhook ;

dates de voyage séparées de la date de création ;

règles d’annulation / remboursement ;

statut du trajet : brouillon, publié, complet, annulé, parti, terminé.

3. Sécuriser les règles métier
Les politiques RLS actuelles permettent la lecture publique des trajets et sièges, ainsi que l’accès d’un utilisateur à ses propres réservations. 

À renforcer avant les paiements :

un voyageur ne peut réserver que son propre compte ;

une réservation ne peut devenir paid que par une fonction serveur / webhook de paiement ;

un siège ne peut pas être vendu deux fois ;

l’opérateur ne peut gérer que ses propres trajets ;

aucune clé administrative ou secrète ne doit être exposée dans l’application mobile.

Critère de sortie
Un utilisateur authentifié peut lire les trajets et créer une réservation de test dans une base de données sécurisée.

Phase 2 — Parcours de recherche et réservation (Semaines 2 et 3)
1. Écran de recherche
L’écran existant contient déjà les champs départ et destination, mais navigue vers les résultats sans transmettre ni exploiter les valeurs saisies. 

À implémenter :

champs départ et destination avec listes contrôlées ;

inversion départ/destination ;

sélection d’une date ;

filtre « aujourd’hui / demain » pour un lancement simple ;

validation : départ différent de destination ;

transmission des paramètres vers l’écran de résultats.

2. Résultats de recherche
L’écran actuel est un emplacement statique indiquant que Supabase doit être branché. 

À afficher pour chaque trajet :

heure de départ ;

heure d’arrivée estimée ;

départ et destination ;

compagnie ;

prix en FCFA ;

places restantes ;

indicateur complet ou dernière place ;

bouton Choisir ce trajet.

La requête doit filtrer la table trips par villes et date, puis trier les résultats par heure de départ. La structure contient déjà departure_city, arrival_city, departure_time, price_xof et total_seats. 

3. Détail du trajet et choix du siège
Créer un écran dédié avec :

résumé du trajet ;

conditions d’annulation ;

plan de sièges simple ;

sièges disponibles, réservés et temporairement bloqués ;

prix total ;

bouton Continuer vers le paiement.

4. Prévention des doubles réservations
C’est le point technique le plus important du MVP.

Mettre en œuvre une procédure serveur atomique :

vérifier que le siège est disponible ;

le verrouiller temporairement ;

créer la réservation avec le statut pending ;

lancer le paiement ;

confirmer le siège et la réservation uniquement après le succès du paiement ;

libérer automatiquement le siège si le paiement échoue ou expire.

Les statuts de siège (available, held, booked) et de paiement (pending, paid, failed) existent déjà : il faut maintenant implémenter les transitions de manière transactionnelle côté serveur. 

Critère de sortie
Un voyageur connecté peut rechercher un vrai trajet, sélectionner une place et obtenir une réservation de test sans collision avec un autre utilisateur.

Phase 3 — Paiement et billet (Semaine 4)
1. Intégrer le paiement
Le projet prévoit déjà une dépendance Flutterwave. 

Pour le MVP :

créer le paiement avec le montant et la référence de réservation ;

conserver la référence prestataire dans payments ;

traiter la confirmation via webhook côté serveur ;

ne jamais considérer la transaction payée uniquement parce que l’application mobile l’affiche ;

prévoir un écran clair : paiement en cours, réussi, échoué, à réessayer.

2. Générer le billet
Après confirmation serveur du paiement :

générer un numéro de billet lisible ;

générer un QR code signé ou associé à un identifiant non devinable ;

afficher :

voyageur ;

départ / destination ;

date et heure ;

numéro de siège ;

compagnie ;

référence de réservation ;

statut du billet.

Les packages QR sont déjà déclarés dans le projet, ce qui facilite cette étape. 

3. Écran « Mes voyages »
Prévoir deux sections :

À venir : billet, QR code, trajet, actions d’annulation/contact ;

Passés : historique et justificatif de paiement.

Critère de sortie
Un paiement de test validé produit un billet QR consultable même après redémarrage de l’application.

Phase 4 — Opérations gare et back-office minimal (Semaine 5)
Un produit de réservation ne peut pas être opérationnel sans outil pour les transporteurs et agents de gare.

Back-office web minimal
Il peut être construit en React/Next.js séparément, ou temporairement dans une interface Supabase protégée. Fonctions impératives :

créer, modifier, publier ou annuler un trajet ;

associer un véhicule et un nombre de sièges ;

voir les réservations d’un trajet ;

rechercher une réservation par nom, téléphone ou référence ;

visualiser paiements et incidents ;

exporter une liste d’embarquement.

Contrôle à l’embarquement
Créer une vue mobile très simple pour les agents :

scanner le QR code ;

vérifier le statut du billet ;

afficher « valide », « déjà utilisé », « annulé » ou « inconnu » ;

marquer le billet comme embarqué ;

prévoir une saisie manuelle de la référence si la caméra échoue.

Le projet prévoit déjà les packages nécessaires au QR code et au scan. 

Critère de sortie
Un agent peut vérifier un billet en moins de 10 secondes, et un billet ne peut pas être embarqué deux fois.

Phase 5 — Qualité, support et lancement pilote (Semaines 6 à 8)
Qualité minimum
Tests du parcours complet : recherche, siège, paiement réussi/échoué, billet, scan.

Tests de concurrence sur une même place.

Gestion des erreurs réseau et reprise après fermeture de l’application.

Écrans de chargement et messages compréhensibles.

Validation des numéros de téléphone et des montants FCFA.

Journal des actions importantes : réservation créée, paiement confirmé, billet utilisé.

Suivi des erreurs applicatives.

Support voyageurs
Mettre à disposition dès le pilote :

bouton WhatsApp / téléphone de support ;

FAQ courte : paiement, billet, annulation, retard, changement ;

référence de réservation copiables ;

notifications SMS ou push pour confirmation, rappel avant départ et annulation de trajet.

Firebase Messaging est déjà envisagé dans les dépendances, mais il peut être ajouté après la confirmation de paiement si le délai est serré. 

Pilotage opérationnel
Lancer d’abord avec :

1 à 3 compagnies ;

2 à 5 lignes ;

des horaires limités ;

une équipe gare formée ;

un support humain disponible aux heures de départ.

Mesurer chaque semaine :

nombre de recherches ;

taux recherche → réservation ;

taux réservation → paiement ;

paiements échoués ;

billets scannés ;

annulations ;

doublons / incidents de sièges ;

demandes support ;

taux de remplissage par trajet.

Critère de sortie
Au moins un cycle complet de trajets réels fonctionne : vente, paiement, contrôle QR et assistance voyageurs.

Ordre exact de développement
Configuration Supabase et authentification.

Données réelles de trajets et interface d’administration minimale.

Recherche dynamique.

Liste de résultats et détail de trajet.

Sélection / verrouillage transactionnel d’un siège.

Création de réservation.

Paiement et webhook sécurisé.

Billet QR et espace « Mes voyages ».

Scan agent / validation embarquement.

Notifications, support et métriques.

Définition d’un produit opérationnel
Le MVP est prêt pour des voyageurs payants lorsque, sans intervention technique manuelle, il est possible de :

publier un trajet réel ;

le trouver dans l’application ;

réserver une place sans risque de double vente ;

payer avec confirmation fiable ;

recevoir un billet QR ;

faire contrôler ce billet par un agent ;

annuler ou gérer une erreur via un support identifié.

Vérifications

✅ nl -ba lib/main.dart — vérification de l’initialisation actuelle de Supabase.

✅ nl -ba lib/features/home/home_screen.dart et nl -ba lib/features/search/search_results_screen.dart — vérification du parcours de recherche actuel et de son caractère encore statique. 

✅ nl -ba supabase/schema.sql — vérification du modèle de trajets, sièges, réservations et des politiques RLS existantes. 

✅ nl -ba pubspec.yaml — vérification des dépendances déjà prévues pour paiement, QR code, scan et notifications. 
--------------------------------------------------------------------------------------
Phase 6 — Extensions Métier : Acteurs, Commissions & Assistance (Semaines 7 & 8)
1. Nouveaux Profils d'Accès (RBAC Étendu)

Partenaires Flotte / GIE Transporteurs : Espace de gestion pour piloter les véhicules engagés, suivre l'activité des chauffeurs affiliés et gérer les abonnements de leur flotte.

Garagistes / Mécaniciens Partenaires : Interface dédiée pour recevoir les demandes de dépannage en urgence, consulter la localisation de la panne et valider les interventions effectuées.

2. Système de Commissions Instantanées & Clôture de Caisse

Portefeuille Virtuel (Chauffeurs & Coxeurs) : Crédit immédiat des commissions dès la validation d'une mission (fin de trajet pour le chauffeur, vente/embarquement d'un billet pour le coxeur).

Option de Transfert Direct : Possibilité de retirer/transférer instantanément ces commissions vers leur compte Mobile Money ou portefeuille dédié.

Clôture de Caisse Chauffeur : Tableau de bord récapitulant les encaissements en liquide, les paiements digitaux et les commissions perçues, calculant automatiquement le solde net à reverser.

3. Contrôle des Billets Optimisé (Scanner & Import QR)

Lecture Caméra en Temps Réel : Scan rapide du QR code du billet via l'objectif du téléphone.

Import d'Image / QR Code : Module permettant d'uploader une capture d'écran ou une image de QR code depuis la galerie pour validation si l'écran du client est endommagé.

Saisie Manuel en Secours : Alternative conservée uniquement en cas d'impossibilité de lecture optique.

4. Module Marketplace Dépannage & Abonnement Garagiste

Intermédiaire Dioufy-TS : Dioufy-TS agit comme plateforme de mise en relation de confiance entre les chauffeurs de la flotte et les garagistes souscrits.

Offre « Pack Garagiste » : Les chauffeurs (ou gestionnaires de flotte) souscrivent un pack d'assistance auprès de Dioufy-TS.

Signalement d'Urgence Géolocalisé : En cas de panne durant le trajet, le chauffeur déclenche une alerte via son application.

Mise en Relation Locale : Notification transmise aux garagistes partenaires abonnés situés dans la zone/localité traversée pour un dépannage prioritaire sur le réseau.
---------------------------------------------------------
Module Super Admin & Vision Transports du Futur
1. Paramétrage dynamique par le Super Admin

Gestion des Paliers « Pack Garagiste » : Interface de configuration permettant de définir les formules (ex. Basic, Standard, Premium), les plafonds d'intervention, les zones de couverture autorisées et la récurrence de facturation (mensuelle/annuelle).

Règles des Reversements & Mobile Money : Définition des délais de libération des fonds (instantané, H+24, hebdomadaire), des seuils d'encaissement minimum et des commissions retenues par la plateforme avant transfert vers Wave, Orange Money ou compte bancaire.

Gestion centralisée de la Marketplace : Activation, suspension ou modération des comptes Garagistes, GIE et Chauffeurs.

2. Architecture scalable & Préparation aux Transports du Futur

Architecture MaaS (Mobility as a Service) & Intermodalité :   

Modèle de données conçu pour la combinaison de trajets (ex. Navette locale + Bus interurbain + VTC / Micro-mobilité).

API ouverte pour intégrer de futurs modes de transport (trains express, navettes autonomes, taxis volants eVTOL).

Paiement Universel & Billettique Unifiée (Account-Based Ticketing - ABT) :

Support du QR Code dynamique, du NFC (tap-to-pay via smartphone ou carte sans contact) et de l'intégration des Pass Mobilité régionaux.

Tarification dynamique automatisée par IA en fonction de la demande, du profil passager et de la période.

IoT, Télématique & Gestion Intelligent de Flotte (Smart Fleet) :   

Prise en charge des données télématiques des véhicules (niveau de batterie pour flottes électriques, usure mécanique, diagnostic moteur en temps réel).

Maintenance prédictive : Déclenchement automatique d'alertes dépannage avant la panne sèche ou la casse mécanique en analysant les capteurs IoT du véhicule.   

Optimisation des flux & Smart Routing :   

Gestion des arrêts à la demande (Demand-Responsive Transport - DRT) et ajustement temps réel des itinéraires selon le trafic et les données météo/route.

Suivi du taux d'occupation des véhicules en temps réel via comptage automatique des passagers (APC).