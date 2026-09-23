import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../features/chauffeur/chauffeur_screen.dart';

/// Module Compilé : Opérations Terrain, Chauffeurs, Flotte & Scanner d'Embarquement
class FleetModule implements AppModule {
  @override
  String get id => 'module_fleet';

  @override
  String get name => 'Opérations Flotte & Embarquement';

  @override
  String get requiredFlag => FeatureFlagState.flagMultiTenancyGie;

  @override
  List<String> get dependencies => const ['module_booking', 'module_ticketing'];

  @override
  bool isAvailable() => FeatureFlagService.instance.isEnabled(requiredFlag);

  @override
  Future<void> initialize() async {}

  @override
  Widget buildEntryWidget(BuildContext context) {
    return const ChauffeurScreen();
  }
}
