import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_role.dart';
import 'app_permission.dart';
import 'rbac_context.dart';

/// Service d'Autorisation Contextuelle & RBAC (Dioufy-TS)
/// Applique l'équation : Autorisé = Flag && Permission && Organisation && ContexteMétier
class RbacService extends ChangeNotifier {
  static const String _storageKey = 'dioufy_rbac_snapshot_v1';
  static RbacService? _instance;

  RbacContext _currentContext = RbacContext.passengerDefault();

  RbacService._();

  static RbacService get instance {
    _instance ??= RbacService._();
    return _instance!;
  }

  RbacContext get context => _currentContext;
  AppRole get currentRole => _currentContext.role;
  String? get currentOrganizationId => _currentContext.organizationId;

  /// Initialisation au démarrage avec lecture du snapshot scellé
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_storageKey);
      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        final loaded = RbacContext.fromJson(decoded);

        // Si le snapshot a expiré (> 30 min), on rétrograde au rôle minimal passager
        if (loaded.isExpired) {
          debugPrint('Snapshot RBAC expiré (> 30 min). Rétrogradation sécurisée au mode passager.');
          _currentContext = RbacContext.passengerDefault(userId: loaded.userId);
        } else {
          _currentContext = loaded;
        }
      }
    } catch (e) {
      debugPrint('Mode offline / Initialisation RbacService fallback passager : $e');
      _currentContext = RbacContext.passengerDefault();
    }
    notifyListeners();
  }

  /// Formule d'évaluation stricte préconisée par la Direction Technique
  bool hasPermission(
    String permissionId, {
    String? targetOrganizationId,
    bool isOnline = true,
  }) {
    // 1. Vérification de la présence de la permission dans le jeu actif
    if (!_currentContext.permissions.contains(permissionId)) {
      return false;
    }

    // 2. Si l'application est hors-ligne, vérifier si l'action est autorisée en mode dégradé
    if (!isOnline) {
      if (!_currentContext.canPerformOffline(permissionId)) {
        debugPrint('Action $permissionId rejetée : nécessite un consensus serveur en ligne.');
        return false;
      }
    }

    // 3. Le Super Admin dispose d'une portée globale transverse
    if (_currentContext.role == AppRole.superAdmin) {
      return true;
    }

    // 4. Cloisonnement Multi-Tenancy (Organisation / GIE)
    if (targetOrganizationId != null) {
      if (_currentContext.organizationId != targetOrganizationId) {
        debugPrint(
            'Action $permissionId rejetée : organisation cible $targetOrganizationId non concordante avec ${_currentContext.organizationId}');
        return false;
      }
    }

    return true;
  }

  /// Vérifie si l'utilisateur courant a le droit d'administrer un utilisateur cible
  bool canManageUser({
    required AppRole targetRole,
    String? targetOrganizationId,
  }) {
    // 1. Anti-Élévation : Personne ne peut gérer un Super Admin sauf un Super Admin
    if (targetRole == AppRole.superAdmin && _currentContext.role != AppRole.superAdmin) {
      return false;
    }

    // 2. Le Super Admin peut gérer tout le monde
    if (_currentContext.role == AppRole.superAdmin) {
      return true;
    }

    // 3. Vérification de la hiérarchie de niveau
    if (!_currentContext.role.canManageRole(targetRole)) {
      return false;
    }

    // 4. Vérification du cloisonnement d'organisation pour les GIE
    if (_currentContext.role == AppRole.gieAdmin) {
      if (targetOrganizationId != null &&
          targetOrganizationId != _currentContext.organizationId) {
        return false;
      }
    }

    return true;
  }

  /// Définir le contexte authentifié après connexion serveur
  Future<void> setAuthenticatedContext(RbacContext newContext) async {
    _currentContext = newContext;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(newContext.toJson()));
    } catch (e) {
      debugPrint('Erreur de persistance du snapshot RBAC : $e');
    }
  }

  /// Révocation immédiate (ex: déconnexion ou révocation de droits reçue)
  Future<void> clearAndResetToPassenger() async {
    _currentContext = RbacContext.passengerDefault();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Erreur réinitialisation cache RBAC : $e');
    }
  }

  /// COMMUTATEUR DE PROFIL POUR TEST & DÉVELOPPEMENT
  /// STRICTEMENT CONFINÉ EN MODE DEBUG (Ne modifie aucune donnée sur le serveur)
  void switchRoleForTesting(AppRole role, {String? organizationId}) {
    assert(() {
      final defaultPerms = AppPermission.getDefaultPermissions(role);
      _currentContext = RbacContext(
        userId: 'test_${role.id}_user',
        role: role,
        organizationId: organizationId ?? (role == AppRole.gieAdmin ? 'gie_thies_uuid' : null),
        permissions: defaultPerms,
        snapshotTimestamp: DateTime.now(),
      );
      notifyListeners();
      debugPrint('>>> RBAC TEST SWITCH : Rôle basculé vers [${role.name}] en local debug <<<');
      return true;
    }(), 'switchRoleForTesting est strictement interdit en production.');
  }
}
