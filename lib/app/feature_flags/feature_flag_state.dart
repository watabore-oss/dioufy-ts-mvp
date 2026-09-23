/// Machine d'état à 6 niveaux pour le cycle de vie des Feature Flags (Avis CTO)
enum FeatureFlagStatus {
  /// Module totalement désactivé et invisible
  disabled,

  /// Module accessible sur un périmètre restreint (Whitelist GIE ou bêta-testeurs)
  pilot,

  /// Module actif en production pour tous
  enabled,

  /// Consultation seule : historique et reçus accessibles, nouvelles écritures bloquées
  maintenance,

  /// Clôture propre des opérations en vol avant désactivation définitive
  draining,

  /// Module archivé : aucune nouvelle donnée, intégrité historique conservée
  retired;

  /// Indique si le module peut être affiché dans l'UI
  bool get isAccessible =>
      this == FeatureFlagStatus.enabled ||
      this == FeatureFlagStatus.pilot ||
      this == FeatureFlagStatus.maintenance ||
      this == FeatureFlagStatus.draining;

  /// Indique si de nouvelles transactions/réservations peuvent être créées
  bool get allowsNewOperations =>
      this == FeatureFlagStatus.enabled || this == FeatureFlagStatus.pilot;

  /// Indique si le module est en mode lecture seule
  bool get isReadOnly => this == FeatureFlagStatus.maintenance;

  /// Parse depuis une chaîne
  static FeatureFlagStatus fromString(String? value) {
    if (value == null) return FeatureFlagStatus.disabled;
    for (final status in FeatureFlagStatus.values) {
      if (status.name == value.trim().toLowerCase()) return status;
    }
    // Rétrocompatibilité avec booléens
    if (value.toLowerCase() == 'true') return FeatureFlagStatus.enabled;
    return FeatureFlagStatus.disabled;
  }
}

/// État global des Feature Flags avec graphe de dépendances strict
class FeatureFlagState {
  // Constantes de clés techniques
  static const String flagCoreTraveler = 'FLAG_CORE_TRAVELER';
  static const String flagSeatLockEngine = 'FLAG_SEAT_LOCK_ENGINE';
  static const String flagPaymentWave = 'FLAG_PAYMENT_DIGITAL_WAVE';
  static const String flagPaymentOm = 'FLAG_PAYMENT_DIGITAL_OM';
  static const String flagTicketingHmacQr = 'FLAG_TICKETING_HMAC_QR';
  static const String flagFieldOpsCameraScan = 'FLAG_FIELD_OPS_CAMERA_SCAN';
  static const String flagFieldOpsGalleryImport = 'FLAG_FIELD_OPS_GALLERY_IMPORT';
  static const String flagCashClosureChauffeur = 'FLAG_CASH_CLOSURE_CHAUFFEUR';
  static const String flagVirtualWallet = 'FLAG_VIRTUAL_WALLET';
  static const String flagAutoMobileMoneyPayout = 'FLAG_AUTO_MOBILE_MONEY_PAYOUT';
  static const String flagMultiTenancyGie = 'FLAG_MULTI_TENANCY_GIE';
  static const String flagGarageMarketplaceSos = 'FLAG_GARAGE_MARKETPLACE_SOS';
  static const String flagMaasGtfsIntermodal = 'FLAG_MAAS_GTFS_INTERMODAL';
  static const String flagSmartFleetTelematics = 'FLAG_SMART_FLEET_TELEMATICS';

  /// Graphe de dépendances strict entre fonctionnalités (CTO Directive)
  static const Map<String, List<String>> dependencies = {
    flagSeatLockEngine: [flagCoreTraveler],
    flagPaymentWave: [flagCoreTraveler],
    flagPaymentOm: [flagCoreTraveler],
    flagTicketingHmacQr: [flagCoreTraveler],
    flagFieldOpsCameraScan: [flagTicketingHmacQr],
    flagFieldOpsGalleryImport: [flagTicketingHmacQr],
    flagCashClosureChauffeur: [flagCoreTraveler],
    flagVirtualWallet: [flagCashClosureChauffeur],
    flagAutoMobileMoneyPayout: [
      flagVirtualWallet,
      flagCashClosureChauffeur,
      flagPaymentWave
    ],
    flagGarageMarketplaceSos: [flagMultiTenancyGie],
    flagMaasGtfsIntermodal: [flagCoreTraveler, flagMultiTenancyGie],
    flagSmartFleetTelematics: [flagMultiTenancyGie],
  };

  final Map<String, FeatureFlagStatus> _flags;

  const FeatureFlagState(this._flags);

  /// Valeurs par défaut conformes au MVP Voyageurs & Opérations Terrain
  factory FeatureFlagState.defaults() {
    return const FeatureFlagState({
      flagCoreTraveler: FeatureFlagStatus.enabled,
      flagSeatLockEngine: FeatureFlagStatus.enabled,
      flagPaymentWave: FeatureFlagStatus.enabled,
      flagPaymentOm: FeatureFlagStatus.enabled,
      flagTicketingHmacQr: FeatureFlagStatus.enabled,
      flagFieldOpsCameraScan: FeatureFlagStatus.enabled,
      flagFieldOpsGalleryImport: FeatureFlagStatus.enabled,
      flagCashClosureChauffeur: FeatureFlagStatus.enabled,
      flagVirtualWallet: FeatureFlagStatus.enabled,
      flagMultiTenancyGie: FeatureFlagStatus.enabled,
      // Modules en cours d'atterrissage
      flagAutoMobileMoneyPayout: FeatureFlagStatus.disabled,
      flagGarageMarketplaceSos: FeatureFlagStatus.disabled,
      flagMaasGtfsIntermodal: FeatureFlagStatus.disabled,
      flagSmartFleetTelematics: FeatureFlagStatus.disabled,
    });
  }

  /// Récupère le statut complet d'une fonctionnalité
  FeatureFlagStatus getStatus(String flagKey) {
    return _flags[flagKey] ?? FeatureFlagStatus.disabled;
  }

  /// Vérifie si de nouvelles opérations sont autorisées (compatibilité booléenne)
  bool isEnabled(String flagKey) {
    return getStatus(flagKey).allowsNewOperations;
  }

  /// Vérifie si la fonctionnalité est accessible (y compris en lecture seule maintenance)
  bool isAccessible(String flagKey) {
    return getStatus(flagKey).isAccessible;
  }

  /// Vérifie si toutes les dépendances sont satisfaites avant activation
  bool canActivate(String flagKey) {
    final requiredDeps = dependencies[flagKey] ?? [];
    for (final dep in requiredDeps) {
      final status = getStatus(dep);
      if (!status.allowsNewOperations) {
        return false;
      }
    }
    return true;
  }

  FeatureFlagState copyWith(Map<String, FeatureFlagStatus> updates) {
    final newFlags = Map<String, FeatureFlagStatus>.from(_flags);
    newFlags.addAll(updates);
    return FeatureFlagState(newFlags);
  }

  Map<String, String> toMap() =>
      _flags.map((key, value) => MapEntry(key, value.name));
}
