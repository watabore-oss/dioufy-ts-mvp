import 'app_role.dart';

/// Catégorie de sécurité de la permission
enum PermissionCategory {
  /// Rôle souverain, règles système, grand livre comptable (non modifiables librement)
  systemLocked,

  /// Droits attribuables aux gérants de GIE par les administrateurs
  platformDelegated,

  /// Droits opérationnels locaux au sein d'une organisation/GIE
  gieLocal,
}

/// Modèle d'une permission granulaire liée à un module compilé
class AppPermission {
  final String id;
  final String moduleId;
  final String name;
  final String description;
  final PermissionCategory category;
  final bool isDangerous;

  const AppPermission({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.description,
    required this.category,
    this.isDangerous = false,
  });

  // Constantes de permissions par module

  // Module Booking
  static const String bookingSearch = 'booking.search';
  static const String bookingLockSeat = 'booking.lock_seat';
  static const String bookingManageTrips = 'booking.manage_trips';
  static const String bookingCancelTrip = 'booking.cancel_trip';

  // Module Ticketing
  static const String ticketingViewOwn = 'ticketing.view_own';
  static const String ticketingScanCamera = 'ticketing.scan_camera';
  static const String ticketingImportGallery = 'ticketing.import_gallery';
  static const String ticketingManualValidate = 'ticketing.manual_validate';

  // Module Caisse & Commissions
  static const String cashCollectCash = 'cash.collect_cash';
  static const String cashCloseSession = 'cash.close_session';
  static const String cashGenerateStatement = 'cash.generate_statement';
  static const String cashRequestPayout = 'cash.request_payout';

  // Module Flotte
  static const String fleetViewVehicles = 'fleet.view_vehicles';
  static const String fleetAssignDriver = 'fleet.assign_driver';

  // Module Assistance Garagiste
  static const String garageTriggerSos = 'garage.trigger_sos';
  static const String garageAcceptMission = 'garage.accept_mission';
  static const String garageValidateRepair = 'garage.validate_repair';

  // Module Gouvernance RBAC
  static const String rbacManagePermissions = 'rbac.manage_permissions';
  static const String rbacManageSuperAdmins = 'rbac.manage_super_admins';
  static const String rbacViewAuditLogs = 'rbac.view_audit_logs';

  /// Catalogue de toutes les permissions du système
  static const List<AppPermission> allPermissions = [
    // Booking
    AppPermission(
      id: bookingSearch,
      moduleId: 'module_booking',
      name: 'Rechercher des trajets',
      description: 'Accéder aux grilles horaires publiques',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: bookingLockSeat,
      moduleId: 'module_booking',
      name: 'Verrouiller un siège',
      description: 'Sélectionner et réserver temporairement une place',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: bookingManageTrips,
      moduleId: 'module_booking',
      name: 'Gérer les trajets',
      description: 'Créer et ajuster les départs d un GIE',
      category: PermissionCategory.platformDelegated,
    ),
    AppPermission(
      id: bookingCancelTrip,
      moduleId: 'module_booking',
      name: 'Annuler un voyage',
      description: 'Annulation officielle d un départ',
      category: PermissionCategory.platformDelegated,
      isDangerous: true,
    ),

    // Ticketing
    AppPermission(
      id: ticketingViewOwn,
      moduleId: 'module_ticketing',
      name: 'Voir ses billets',
      description: 'Consulter ses titres de transport personnels',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: ticketingScanCamera,
      moduleId: 'module_ticketing',
      name: 'Scan QR par caméra',
      description: 'Contrôle optique direct à l embarquement',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: ticketingImportGallery,
      moduleId: 'module_ticketing',
      name: 'Import QR galerie',
      description: 'Contrôle secours en cas d écran client brisé',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: ticketingManualValidate,
      moduleId: 'module_ticketing',
      name: 'Saisie référence manuelle',
      description: 'Validation de secours sans caméra',
      category: PermissionCategory.gieLocal,
    ),

    // Caisse & Commissions
    AppPermission(
      id: cashCollectCash,
      moduleId: 'module_cash_closure',
      name: 'Encaisser espèces',
      description: 'Vente directe de billets à bord ou au guichet',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: cashCloseSession,
      moduleId: 'module_cash_closure',
      name: 'Clôturer la caisse',
      description: 'Ventilation cash/digital et calcul solde net chauffeur',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: cashGenerateStatement,
      moduleId: 'module_cash_closure',
      name: 'Générer bordereau WhatsApp',
      description: 'Production du récapitulatif certifié',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: cashRequestPayout,
      moduleId: 'module_cash_closure',
      name: 'Demander reversement',
      description: 'Transfert Mobile Money des commissions acquises',
      category: PermissionCategory.platformDelegated,
      isDangerous: true,
    ),

    // Flotte
    AppPermission(
      id: fleetViewVehicles,
      moduleId: 'module_fleet',
      name: 'Consulter les véhicules',
      description: 'Affichage des bus du GIE',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: fleetAssignDriver,
      moduleId: 'module_fleet',
      name: 'Affecter un chauffeur',
      description: 'Attribution d un bus à un chauffeur titulaire',
      category: PermissionCategory.gieLocal,
    ),

    // Assistance Garagiste
    AppPermission(
      id: garageTriggerSos,
      moduleId: 'module_garage_assistance',
      name: 'Déclencher SOS Panne',
      description: 'Alerte géolocalisée d urgence pour assistance',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: garageAcceptMission,
      moduleId: 'module_garage_assistance',
      name: 'Accepter dépannage',
      description: 'Prise en charge de mission par le garagiste',
      category: PermissionCategory.gieLocal,
    ),
    AppPermission(
      id: garageValidateRepair,
      moduleId: 'module_garage_assistance',
      name: 'Valider réparation',
      description: 'Preuve photographique et clôture d intervention',
      category: PermissionCategory.gieLocal,
    ),

    // Gouvernance RBAC (Système Verrouillé)
    AppPermission(
      id: rbacManagePermissions,
      moduleId: 'module_rbac',
      name: 'Gérer la matrice RBAC',
      description: 'Modification des droits et associations par rôle',
      category: PermissionCategory.systemLocked,
      isDangerous: true,
    ),
    AppPermission(
      id: rbacManageSuperAdmins,
      moduleId: 'module_rbac',
      name: 'Gérer les Super Admins',
      description: 'Collège souverain de la plateforme Dioufy-TS',
      category: PermissionCategory.systemLocked,
      isDangerous: true,
    ),
    AppPermission(
      id: rbacViewAuditLogs,
      moduleId: 'module_rbac',
      name: 'Consulter journal d audit',
      description: 'Traçabilité immuable des actions sensibles',
      category: PermissionCategory.systemLocked,
    ),
  ];

  /// Matrice par défaut des permissions par rôle
  static Set<String> getDefaultPermissions(AppRole role) {
    switch (role) {
      case AppRole.superAdmin:
        return allPermissions.map((p) => p.id).toSet();

      case AppRole.platformAdmin:
        return {
          bookingSearch,
          bookingManageTrips,
          bookingCancelTrip,
          fleetViewVehicles,
          rbacViewAuditLogs,
        };

      case AppRole.gieAdmin:
        return {
          bookingSearch,
          bookingManageTrips,
          bookingCancelTrip,
          fleetViewVehicles,
          fleetAssignDriver,
          cashCloseSession,
          cashGenerateStatement,
          cashRequestPayout,
        };

      case AppRole.gieAgent:
        return {
          bookingSearch,
          bookingManageTrips,
          fleetViewVehicles,
          cashGenerateStatement,
        };

      case AppRole.driver:
        return {
          bookingSearch,
          cashCollectCash,
          cashCloseSession,
          cashGenerateStatement,
          fleetViewVehicles,
          garageTriggerSos,
        };

      case AppRole.coxeur:
        return {
          bookingSearch,
          ticketingScanCamera,
          ticketingImportGallery,
          ticketingManualValidate,
          cashCollectCash,
        };

      case AppRole.mechanic:
        return {
          garageAcceptMission,
          garageValidateRepair,
        };

      case AppRole.passenger:
        return {
          bookingSearch,
          bookingLockSeat,
          ticketingViewOwn,
        };
    }
  }
}
