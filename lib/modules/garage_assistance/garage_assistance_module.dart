import 'package:flutter/material.dart';
import '../../app/module_registry.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../app/feature_flags/feature_guard.dart';


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

/// Écran d'assistance dépannage et tableau de bord Garagiste Partenaire Agréé
class GarageAssistanceScreen extends StatelessWidget {
  const GarageAssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'SOS Assistance & Garagistes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.5, color: Color(0xFF0F172A)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 24),
            tooltip: 'Retour',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: const Text(
                'GARAGISTE AGRÉÉ',
                style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cartouche d'état du réseau
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_circle, color: Colors.amber, size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Réseau d Assistance Rapide', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          'Axes Dakar - Thiès - Touba',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // État des alertes SOS
            const Text(
              'Alertes de Dépannage en Direct',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun bus en panne signalé',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toutes les unités de la flotte circulent normalement sur les corridors routiers. En cas d appel d urgence, la notification géolocalisée s affichera ici en temps réel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Services partenaires
            const Text(
              'Contacts d Urgence Partenaires',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: Colors.white,
              child: const ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.local_shipping, color: Color(0xFF1D4ED8)),
                ),
                title: Text('Remorquage Autoroute Ila Touba', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Service de dépannage 24h/24 • Sortie Bambey'),
                trailing: Icon(Icons.phone, color: Color(0xFF059669)),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: Colors.white,
              child: const ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.build, color: Color(0xFF059669)),
                ),
                title: Text('Atelier Mécanique Central Thiès', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Pièces détachées Tata & Toyota • Dixième Thiès'),
                trailing: Icon(Icons.phone, color: Color(0xFF059669)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
