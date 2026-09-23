import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../features/ticket/my_tickets_screen.dart';

/// Module Compilé : Billettique Numérique, QR Signé HMAC-SHA256 & Portefeuille Hors-Ligne
class TicketingModule implements AppModule {
  @override
  String get id => 'module_ticketing';

  @override
  String get name => 'Billettique & QR Code Sécurisé';

  @override
  String get requiredFlag => FeatureFlagState.flagTicketingHmacQr;

  @override
  List<String> get dependencies => const ['module_booking'];

  @override
  bool isAvailable() => FeatureFlagService.instance.isEnabled(requiredFlag);

  @override
  Future<void> initialize() async {}

  @override
  Widget buildEntryWidget(BuildContext context) {
    return const MyTicketsScreen();
  }
}
