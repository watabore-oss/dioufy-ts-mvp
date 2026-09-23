import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../features/home/home_screen.dart';

/// Module Compilé : Recherche de Trajets, Réservation et Sélection des Sièges
class BookingModule implements AppModule {
  @override
  String get id => 'module_booking';

  @override
  String get name => 'Recherche & Réservation Voyageurs';

  @override
  String get requiredFlag => FeatureFlagState.flagCoreTraveler;

  @override
  List<String> get dependencies => const [];

  @override
  bool isAvailable() => FeatureFlagService.instance.isEnabled(requiredFlag);

  @override
  Future<void> initialize() async {
    // Pré-chargement éventuel des lignes fréquentes
  }

  @override
  Widget buildEntryWidget(BuildContext context) {
    return const HomeScreen();
  }
}
