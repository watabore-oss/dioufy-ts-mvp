import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../app/feature_flags/feature_guard.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

/// Module Compilé : Marketplace d'Assistance, Pack Garagiste & SOS Panne (Phase 5)
class GarageAssistanceModule implements AppModule {
  @override
  String get id => 'module_garage_assistance';

  @override
  String get name => 'Marketplace Dépannage & Pack Garagiste';

  @override
  String get requiredFlag => FeatureFlagState.flagGarageMarketplaceSos;

  @override
  List<String> get dependencies => const ['module_fleet'];

  @override
  bool isAvailable() => FeatureFlagService.instance.isEnabled(requiredFlag);

  @override
  Future<void> initialize() async {}

  @override
  Widget buildEntryWidget(BuildContext context) {
    return FeatureGuard(
      flagKey: requiredFlag,
      featureName: 'Assistance Dépannage & Pack Garagiste',
      child: const GarageAssistanceScreen(),
    );
  }
}

/// Écran d'assistance dépannage (prêt pour la Phase 5)
class GarageAssistanceScreen extends StatelessWidget {
  const GarageAssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DioufyColors.backgroundLight,
      appBar: AppBar(
        title: const Text('SOS Assistance Garagiste'),
        backgroundColor: DioufyColors.primaryDark,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  size: 64,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Marketplace Dépannage en cours de raccordement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DioufyColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le réseau de garagistes agréés sur les axes Dakar-Thiès et Autoroute Ila Touba sera activé selon la Phase 5.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
