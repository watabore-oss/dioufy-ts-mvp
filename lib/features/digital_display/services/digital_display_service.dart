import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/permissions/app_role.dart';
import '../models/slide_item.dart';

/// Service gérant la source de contenu pour le Digital Display Dioufy-TS.
/// Conçu pour fonctionner 100% hors-ligne avec un catalogue local haute qualité,
/// tout en détectant dynamiquement toutes les images de /assets/slides/.
class DigitalDisplayService {
  DigitalDisplayService._();
  static final DigitalDisplayService instance = DigitalDisplayService._();

  List<SlideItem>? _autoDetectedSlides;

  /// Diapositives générales par défaut (utilisées par la Landing Screen et les invités)
  /// Retourne les slides auto-détectés si chargés, sinon la sélection voyageur par défaut.
  List<SlideItem> getSlides() {
    return _autoDetectedSlides ?? _passengerSlides;
  }

  /// Détecte automatiquement toutes les images stockées dans /assets/slides/
  /// et construit une liste enrichie de diapositives prêtes à l'affichage.
  Future<List<SlideItem>> loadAutoDetectedSlides() async {
    try {
      List<String> imagePaths = [];

      // Méthode 1 : AssetManifest API (Flutter moderne)
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final allAssets = manifest.listAssets();
        imagePaths = allAssets.where((p) {
          final lp = p.toLowerCase();
          return lp.startsWith('assets/slides/') &&
              (lp.endsWith('.jpg') || lp.endsWith('.jpeg') || lp.endsWith('.png') || lp.endsWith('.webp'));
        }).toList();
      } catch (_) {
        // Méthode 2 : Fallback sur AssetManifest.json
        try {
          final jsonStr = await rootBundle.loadString('AssetManifest.json');
          final Map<String, dynamic> manifestMap = json.decode(jsonStr);
          imagePaths = manifestMap.keys.where((p) {
            final lp = p.toLowerCase();
            return lp.startsWith('assets/slides/') &&
                (lp.endsWith('.jpg') || lp.endsWith('.jpeg') || lp.endsWith('.png') || lp.endsWith('.webp'));
          }).toList();
        } catch (_) {}
      }

      if (imagePaths.isEmpty) {
        _autoDetectedSlides = _passengerSlides;
        return _passengerSlides;
      }

      // Tri naturel pour garantir un ordre d'affichage stable
      imagePaths.sort();

      final List<SlideItem> detected = [];
      for (final path in imagePaths) {
        // Vérifier si un slide prédéfini existe déjà pour cette image
        SlideItem? matchedSlide;
        for (final s in _passengerSlides) {
          if (s.assetImage == path) {
            matchedSlide = s;
            break;
          }
        }

        if (matchedSlide != null) {
          detected.add(matchedSlide);
        } else {
          // Génération dynamique d'un slide adapté pour toute nouvelle image ajoutée
          final filename = path.split('/').last.split('.').first;
          final cleanTitle = filename
              .replaceAll('slide_', '')
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .replaceAll('Copie', 'Ligne Directe')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

          final capitalizedTitle = cleanTitle.isEmpty
              ? 'Dioufy Express'
              : cleanTitle[0].toUpperCase() + cleanTitle.substring(1);

          detected.add(
            SlideItem(
              id: 'detected_$filename',
              tag: 'RÉSEAU SÉNÉGAL',
              titlePrefix: 'Voyagez confortablement,\nsur la ligne ',
              titleHighlight: '$capitalizedTitle.',
              subtitle: 'Flotte moderne, réservations garanties et sécurité optimale sur toutes vos routes.',
              ctaText: 'Explorer les prochains départs →',
              assetImage: path,
              features: const [
                SlideFeatureBadge(
                  icon: Icons.directions_bus_rounded,
                  title: 'Bus climatisé',
                  subtitle: 'Confort garanti',
                  iconBgColor: Color(0xFF059669),
                  iconColor: Colors.white,
                ),
                SlideFeatureBadge(
                  icon: Icons.event_seat_rounded,
                  title: 'Siège réservé',
                  subtitle: 'Choix de votre place',
                  iconBgColor: Color(0xFFEA580C),
                  iconColor: Colors.white,
                ),
                SlideFeatureBadge(
                  icon: Icons.verified_user_rounded,
                  title: 'Billet sécurisé',
                  subtitle: 'Validation QR officielle',
                  iconBgColor: Color(0xFF2563EB),
                  iconColor: Colors.white,
                ),
              ],
            ),
          );
        }
      }

      _autoDetectedSlides = detected;
      return detected;
    } catch (e) {
      _autoDetectedSlides = _passengerSlides;
      return _passengerSlides;
    }
  }

  /// Fournit des diapositives hautement contextualisées selon le rôle de l'utilisateur
  /// et l'onglet actif dans l'application.
  List<SlideItem> getSlidesForRole(AppRole role, {int? tabIndex}) {
    switch (role) {
      case AppRole.driver:
        return _driverSlides;
      case AppRole.gieAdmin:
      case AppRole.gieAgent:
        return _gieSlides;
      case AppRole.coxeur:
        return _coxeurSlides;
      case AppRole.mechanic:
        return _mechanicSlides;
      case AppRole.superAdmin:
      case AppRole.platformAdmin:
        return _adminSlides;
      case AppRole.passenger:
        return getSlides();
    }
  }

  // ===========================================================================
  // 1. SLIDES VOYAGEUR (Découverte, Réservation, Expérience, Nouveautés)
  // ===========================================================================
  static const List<SlideItem> _passengerSlides = [
    SlideItem(
      id: 'senegal_serein',
      tag: 'NOUVEAU',
      titlePrefix: 'Voyagez mieux,\nvoyagez ',
      titleHighlight: 'serein.',
      subtitle: 'Dioufy-TS vous accompagne sur tous vos trajets au Sénégal.',
      ctaText: 'Découvrir nos destinations →',
      assetImage: 'assets/slides/slide_dakar_monument.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.directions_bus_rounded,
          title: 'Bus à l\'heure',
          subtitle: 'Ponctualité garantie',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.airline_seat_recline_extra_rounded,
          title: 'Confort à bord',
          subtitle: 'Voyagez confortablement',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.security_rounded,
          title: 'Sécurité assurée',
          subtitle: 'Votre sécurité d\'abord',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'confort_vip',
      tag: 'EXPÉRIENCE PREMIUM',
      titlePrefix: 'Un confort absolu,\nsur chaque ',
      titleHighlight: 'kilomètre.',
      subtitle: 'Wi-Fi haut débit, climatisation et sièges grand confort inclinables.',
      ctaText: 'Explorer la flotte VIP →',
      assetImage: 'assets/slides/slide_bus_interior.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.wifi_rounded,
          title: 'Wi-Fi & Prises USB',
          subtitle: 'Restez connecté en continu',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.event_seat_rounded,
          title: 'Sièges ergonomiques',
          subtitle: 'Espace spacieux et inclinable',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.luggage_rounded,
          title: 'Bagages protégés',
          subtitle: 'Prise en charge soute sécurisée',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'lignes_express',
      tag: 'DÉPARTS QUOTIDIENS',
      titlePrefix: 'Dakar, Touba, Thiès,\nau meilleur ',
      titleHighlight: 'tarif.',
      subtitle: 'Réservez vos places à l\'avance et évitez les files d\'attente en gare.',
      ctaText: 'Voir les horaires en direct →',
      assetImage: 'assets/slides/slide_touba_express.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.schedule_rounded,
          title: 'Départs réguliers',
          subtitle: 'Ponctualité et fréquence',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.verified_rounded,
          title: 'Tarif garanti',
          subtitle: 'Zéro frais caché à l\'achat',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.qr_code_2_rounded,
          title: 'QR Code direct',
          subtitle: 'Embarquement immédiat',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
  ];

  // ===========================================================================
  // 2. SLIDES CHAUFFEUR & CHEF DE BORD (Sécurité, Clôture de Caisse, SOS Garages)
  // ===========================================================================
  static const List<SlideItem> _driverSlides = [
    SlideItem(
      id: 'driver_safety',
      tag: 'SÉCURITÉ ROUTIÈRE',
      titlePrefix: 'Vigilance et sérénité,\nla priorité à chaque ',
      titleHighlight: 'trajet.',
      subtitle: 'Respectez les vitesses autoroutières et les pauses de récupération obligatoires.',
      ctaText: 'Consulter les règles de route →',
      assetImage: 'assets/slides/slide_dakar_monument.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.speed_rounded,
          title: 'Vitesse maîtrisée',
          subtitle: 'Max 90 km/h autoroute',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.hotel_class_rounded,
          title: 'Pause active',
          subtitle: 'Repos toutes les 2h',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.health_and_safety_rounded,
          title: 'Ceinture attachée',
          subtitle: 'Sécurité de tous à bord',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'driver_cash',
      tag: 'CLÔTURE DIGITALE',
      titlePrefix: 'Zéro écart de caisse,\nversement certifié en ',
      titleHighlight: '1 clic.',
      subtitle: 'Transférez les fonds de bord et validez votre feuille de route sans erreur manuelle.',
      ctaText: 'Voir le protocole caisse →',
      assetImage: 'assets/slides/slide_bus_interior.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.point_of_sale_rounded,
          title: 'Encaissement clair',
          subtitle: 'Rapprochement instantané',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.receipt_long_rounded,
          title: 'Feuille de route',
          subtitle: 'Historique vérifié',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.security_update_good_rounded,
          title: 'Transmission GIE',
          subtitle: 'Reçu SMS et confirmation',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'driver_sos',
      tag: 'ASSISTANCE SOS',
      titlePrefix: 'Dépannage mécanique 24/7,\nsur tous les axes du ',
      titleHighlight: 'Sénégal.',
      subtitle: 'En cas d\'avarie sur autoroute ou nationale, le réseau Dioufy intervient en urgence.',
      ctaText: 'Déclencher l\'assistance SOS →',
      assetImage: 'assets/slides/slide_touba_express.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.car_repair_rounded,
          title: 'Garages agréés',
          subtitle: 'Intervention < 45 min',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.alt_route_rounded,
          title: 'Véhicule relais',
          subtitle: 'Continuité des passagers',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.phone_in_talk_rounded,
          title: 'Hotline Chauffeur',
          subtitle: 'Assistance dédiée 24h/24',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
  ];

  // ===========================================================================
  // 3. SLIDES GIE & TRANSPORTEURS (Gestion de flotte, Recettes, Télémétrie)
  // ===========================================================================
  static const List<SlideItem> _gieSlides = [
    SlideItem(
      id: 'gie_fleet',
      tag: 'PILOTAGE DE FLOTTE',
      titlePrefix: 'Maximisez la rentabilité\nde chaque ',
      titleHighlight: 'autocar.',
      subtitle: 'Suivez le taux d\'occupation moyen et l\'optimisation des départs aux heures de pointe.',
      ctaText: 'Analyser les taux de remplissage →',
      assetImage: 'assets/slides/slide_bus_interior.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.insights_rounded,
          title: 'Taux de remplissage',
          subtitle: 'Optimisation continue',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.directions_bus_filled_rounded,
          title: 'Parc en rotation',
          subtitle: 'Disponibilité maximale',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.auto_graph_rounded,
          title: 'Rapports d\'activité',
          subtitle: 'Tableau de bord unifié',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'gie_revenue',
      tag: 'TRANSPARENCE FINANCIÈRE',
      titlePrefix: 'Commissions et recettes,\nune répartition automatique ',
      titleHighlight: 'sans litige.',
      subtitle: 'Chaque vente en ligne ou en guichet est comptabilisée et sécurisée en temps réel.',
      ctaText: 'Consulter les flux de trésorerie →',
      assetImage: 'assets/slides/slide_dakar_monument.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Encaissements Wave/OM',
          subtitle: 'Disponibilité instantanée',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.fact_check_rounded,
          title: 'Commissions claires',
          subtitle: 'Zéro contestation',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.lock_clock_rounded,
          title: 'Audit Trail',
          subtitle: 'Journal immuable',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'gie_maintenance',
      tag: 'MAINTENANCE PRÉVENTIVE',
      titlePrefix: 'Anticipez les révisions,\névitez les arrêts ',
      titleHighlight: 'techniques.',
      subtitle: 'Suivez le kilométrage et programmez l\'entretien avec notre réseau de garagistes agréés.',
      ctaText: 'Planifier un entretien de flotte →',
      assetImage: 'assets/slides/slide_touba_express.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.build_rounded,
          title: 'Contrôle périodique',
          subtitle: 'Carnet d\'entretien digital',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.verified_user_rounded,
          title: 'Pièces certifiées',
          subtitle: 'Tarifs préférentiels GIE',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.check_circle_outline_rounded,
          title: 'Conformité totale',
          subtitle: 'Visite technique à jour',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
  ];

  // ===========================================================================
  // 4. SLIDES COXEUR & RÉGULATION DE GARE (Quais, Embarquement, Scanner)
  // ===========================================================================
  static const List<SlideItem> _coxeurSlides = [
    SlideItem(
      id: 'coxeur_flow',
      tag: 'RÉGULATION DES QUAIS',
      titlePrefix: 'Départs cadencés,\nune gestion fluide des ',
      titleHighlight: 'quais.',
      subtitle: 'Éliminez les bousculades et assurez un départ ponctuel pour chaque rotation.',
      ctaText: 'Voir la grille des départs →',
      assetImage: 'assets/slides/slide_touba_express.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.departure_board_rounded,
          title: 'Planning précis',
          subtitle: 'Horaires respectés',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.groups_rounded,
          title: 'File d\'attente ordonnée',
          subtitle: 'Confort des voyageurs',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.volume_up_rounded,
          title: 'Annonces gares',
          subtitle: 'Information voyageurs',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
    SlideItem(
      id: 'coxeur_scanner',
      tag: 'CONTRÔLE EXPRESS',
      titlePrefix: 'Validation instantanée,\nun contrôle HMAC en ',
      titleHighlight: '1 seconde.',
      subtitle: 'Notre scanner décode et certifie les QR Codes de billets même sans connexion internet.',
      ctaText: 'Démarrer le scanner de quai →',
      assetImage: 'assets/slides/slide_bus_interior.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Contrôle instantané',
          subtitle: 'Zéro temps d\'attente',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.shield_rounded,
          title: 'Anti-fraude prouvé',
          subtitle: 'Détection doubles billets',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.wifi_off_rounded,
          title: 'Mode offline',
          subtitle: 'Opérationnel partout',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
  ];

  // ===========================================================================
  // 5. SLIDES GARAGISTE & MÉCANICIEN (SOS Dépannage, Interventions)
  // ===========================================================================
  static const List<SlideItem> _mechanicSlides = [
    SlideItem(
      id: 'mechanic_interventions',
      tag: 'SOS DÉPANNAGE',
      titlePrefix: 'Assistance express,\ninterventions géolocalisées en ',
      titleHighlight: 'temps réel.',
      subtitle: 'Recevez les demandes de secours des bus en détresse et sécurisez les axes nationaux.',
      ctaText: 'Consulter la carte des alertes →',
      assetImage: 'assets/slides/slide_touba_express.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.car_repair_rounded,
          title: 'Alerte immédiate',
          subtitle: 'Position GPS exacte',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.handyman_rounded,
          title: 'Outillage professionnel',
          subtitle: 'Dépannage sur place',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.check_circle_rounded,
          title: 'Validation rapide',
          subtitle: 'Paiement direct certifié',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
  ];

  // ===========================================================================
  // 6. SLIDES ADMINISTRATION & CONSOLE SUPER ADMIN (Supervision, Audit, Uptime)
  // ===========================================================================
  static const List<SlideItem> _adminSlides = [
    SlideItem(
      id: 'admin_metrics',
      tag: 'SUPERVISION NATIONALE',
      titlePrefix: 'Dioufy-TS en temps réel,\nsur l\'ensemble du ',
      titleHighlight: 'territoire.',
      subtitle: 'Surveillance des transactions, de la disponibilité des passerelles de paiement et des flux GIE.',
      ctaText: 'Ouvrir la console système →',
      assetImage: 'assets/slides/slide_dakar_monument.jpg',
      features: [
        SlideFeatureBadge(
          icon: Icons.cloud_done_rounded,
          title: 'Disponibilité 99.9%',
          subtitle: 'Haute résilience réseau',
          iconBgColor: Color(0xFF059669),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.lock_rounded,
          title: 'Sécurité HMAC',
          subtitle: 'Chiffrement bancaire',
          iconBgColor: Color(0xFFEA580C),
          iconColor: Colors.white,
        ),
        SlideFeatureBadge(
          icon: Icons.hub_rounded,
          title: 'Couverture nationale',
          subtitle: 'Toutes régions connectées',
          iconBgColor: Color(0xFF2563EB),
          iconColor: Colors.white,
        ),
      ],
    ),
  ];
}
