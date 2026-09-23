import 'app_role.dart';
import 'app_permission.dart';

/// Snapshot de sécurité scellé avec durée de validité (TTL) stricte
class RbacContext {
  final String userId;
  final AppRole role;
  final String? organizationId;
  final Set<String> permissions;
  final DateTime snapshotTimestamp;
  final int ttlMinutes;

  const RbacContext({
    required this.userId,
    required this.role,
    this.organizationId,
    required this.permissions,
    required this.snapshotTimestamp,
    this.ttlMinutes = 30, // 30 minutes max pour le cache local
  });

  /// Contexte passager anonyme ou par défaut
  factory RbacContext.passengerDefault({String? userId}) {
    return RbacContext(
      userId: userId ?? 'anon_passenger',
      role: AppRole.passenger,
      permissions: AppPermission.getDefaultPermissions(AppRole.passenger),
      snapshotTimestamp: DateTime.now(),
    );
  }

  /// Vérifie si le snapshot local est expiré (> 30 min)
  bool get isExpired {
    return DateTime.now().difference(snapshotTimestamp) >
        Duration(minutes: ttlMinutes);
  }

  /// Permissions explicitement autorisées en mode dégradé hors-ligne
  static const Set<String> _offlineWhitelistedPermissions = {
    AppPermission.bookingSearch,
    AppPermission.ticketingViewOwn,
    AppPermission.ticketingScanCamera,
    AppPermission.ticketingImportGallery,
    AppPermission.ticketingManualValidate,
    AppPermission.fleetViewVehicles,
  };

  /// Vérifie si une permission peut être exercée hors-ligne
  bool canPerformOffline(String permissionId) {
    if (!permissions.contains(permissionId)) return false;
    // Les actions financières critiques et la gouvernance RBAC exigent impérativement le réseau
    return _offlineWhitelistedPermissions.contains(permissionId);
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'role': role.id,
        'organizationId': organizationId,
        'permissions': permissions.toList(),
        'snapshotTimestamp': snapshotTimestamp.toIso8601String(),
        'ttlMinutes': ttlMinutes,
      };

  factory RbacContext.fromJson(Map<String, dynamic> json) {
    return RbacContext(
      userId: json['userId'] as String? ?? 'unknown',
      role: AppRole.fromId(json['role'] as String?),
      organizationId: json['organizationId'] as String?,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      snapshotTimestamp: DateTime.tryParse(
              json['snapshotTimestamp'] as String? ?? '') ??
          DateTime.now(),
      ttlMinutes: json['ttlMinutes'] as int? ?? 30,
    );
  }
}
