import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../features/chauffeur/cloture_caisse_screen.dart';

/// Module Compilé : Clôture de Caisse, Commissions (5% Chauffeur) & Grand Livre
class CommissionsModule implements AppModule {
  @override
  String get id => 'module_commissions';

  @override
  String get name => 'Clôture de Caisse & Commissions';

  @override
  String get requiredFlag => FeatureFlagState.flagCashClosureChauffeur;

  @override
  List<String> get dependencies => const ['module_booking'];

  @override
  bool isAvailable() => FeatureFlagService.instance.isEnabled(requiredFlag);

  @override
  Future<void> initialize() async {}

  @override
  Widget buildEntryWidget(BuildContext context) {
    return const ClotureCaisseScreen();
  }
}
