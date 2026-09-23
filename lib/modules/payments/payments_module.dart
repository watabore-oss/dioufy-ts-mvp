import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';

/// Module Compilé : Paiements Digitaux Mobile Money (Wave, OM, Free Money)
class PaymentsModule implements AppModule {
  @override
  String get id => 'module_payments';

  @override
  String get name => 'Paiements Digitaux Mobile Money';

  @override
  String get requiredFlag => FeatureFlagState.flagPaymentWave;

  @override
  List<String> get dependencies => const ['module_booking'];

  @override
  bool isAvailable() =>
      FeatureFlagService.instance.isEnabled(FeatureFlagState.flagPaymentWave) ||
      FeatureFlagService.instance.isEnabled(FeatureFlagState.flagPaymentOm);

  @override
  Future<void> initialize() async {}

  @override
  Widget buildEntryWidget(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Passerelle de Paiement Dioufy-TS'),
      ),
    );
  }
}
