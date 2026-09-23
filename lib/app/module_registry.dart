import 'package:flutter/material.dart';
import 'feature_flags/feature_flag_service.dart';

/// Contrat standard de module compilé pour Dioufy-TS
abstract interface class AppModule {
  String get id;
  String get name;
  String get requiredFlag;
  List<String> get dependencies;

  bool isAvailable();
  Future<void> initialize();
  Widget buildEntryWidget(BuildContext context);
}

/// Registre central des modules compilés
class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._();
  final Map<String, AppModule> _modules = {};

  ModuleRegistry._();

  void register(AppModule module) {
    _modules[module.id] = module;
  }

  AppModule? getModule(String id) => _modules[id];

  List<AppModule> getAllModules() => _modules.values.toList();

  /// Initialise tous les modules enregistrés de manière asynchrone et résiliente
  Future<void> initializeAll() async {
    for (final module in _modules.values) {
      try {
        if (module.isAvailable()) {
          await module.initialize();
        }
      } catch (e) {
        debugPrint('Avertissement initialisation module ${module.id} : $e');
      }
    }
  }

  /// Vérifie si un module peut être exécuté (flag actif + dépendances satisfaites)
  bool canExecute(String moduleId) {
    final module = _modules[moduleId];
    if (module == null) return false;

    // 1. Vérification du flag propre au module
    if (!FeatureFlagService.instance.isEnabled(module.requiredFlag)) {
      return false;
    }

    // 2. Vérification des dépendances requises
    for (final depId in module.dependencies) {
      if (!canExecute(depId)) {
        debugPrint('Module $moduleId bloqué : dépendance manquante $depId');
        return false;
      }
    }

    return true;
  }
}
