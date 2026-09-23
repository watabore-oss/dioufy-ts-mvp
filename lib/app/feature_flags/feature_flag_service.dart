import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feature_flag_state.dart';

/// Service de gestion et persistance locale des Feature Flags (Stale-While-Revalidate)
class FeatureFlagService {
  static const String _storageKey = 'dioufy_feature_flags_cache_v2';
  static FeatureFlagService? _instance;
  FeatureFlagState _state = FeatureFlagState.defaults();

  FeatureFlagService._();

  static FeatureFlagService get instance {
    _instance ??= FeatureFlagService._();
    return _instance!;
  }

  FeatureFlagState get state => _state;

  /// Initialise le service depuis le cache local pour un démarrage instantané (0ms)
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_storageKey);
      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        final Map<String, FeatureFlagStatus> statusMap = {};
        decoded.forEach((key, value) {
          statusMap[key] = FeatureFlagStatus.fromString(value?.toString());
        });
        _state = FeatureFlagState.defaults().copyWith(statusMap);
      }
    } catch (e) {
      debugPrint('Mode offline / FeatureFlagService cache fallback : $e');
    }
  }

  /// Vérifie si une fonctionnalité permet de nouvelles opérations
  bool isEnabled(String flagKey) {
    return _state.isEnabled(flagKey);
  }

  /// Vérifie si une fonctionnalité est accessible (y compris en mode maintenance)
  bool isAccessible(String flagKey) {
    return _state.isAccessible(flagKey);
  }

  /// Récupère le statut complet d'une fonctionnalité
  FeatureFlagStatus getStatus(String flagKey) {
    return _state.getStatus(flagKey);
  }

  /// Définit le statut avec vérification préalable des dépendances
  Future<bool> setStatus(String flagKey, FeatureFlagStatus newStatus) async {
    // Si on cherche à activer, vérifier d'abord que les dépendances sont satisfaites
    if (newStatus.allowsNewOperations && !_state.canActivate(flagKey)) {
      debugPrint(
          'Erreur FeatureFlag : Impossible d activer $flagKey car ses dépendances ne sont pas actives.');
      return false;
    }

    _state = _state.copyWith({flagKey: newStatus});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_state.toMap()));
    } catch (e) {
      debugPrint('Erreur de persistance du feature flag $flagKey : $e');
    }
    return true;
  }

  /// Méthode d'aide pour bascule booléenne compatible
  Future<bool> setFlag(String flagKey, bool value) async {
    final targetStatus =
        value ? FeatureFlagStatus.enabled : FeatureFlagStatus.disabled;
    return setStatus(flagKey, targetStatus);
  }
}
