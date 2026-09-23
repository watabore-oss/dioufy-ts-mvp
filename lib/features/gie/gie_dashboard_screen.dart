import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/permissions/app_role.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';

/// Tableau de bord d'Exploitation et Gestion GIE Transporteur
class GieDashboardScreen extends StatefulWidget {
  const GieDashboardScreen({super.key});

  @override
  State<GieDashboardScreen> createState() => _GieDashboardScreenState();
}

class _GieDashboardScreenState extends State<GieDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final int _recettesJour = 1250000;
  final int _voyagesCount = 28;
  final int _tauxRemplissage = 87;
  final int _busActifs = 17;
  int _caissesAValider = 3;

  final List<Map<String, dynamic>> _flotte = [
    {'matricule': 'DK-882-SN', 'modele': 'Tata Starbus 45p', 'chauffeur': 'Modou Diop', 'status': 'En route (Touba)'},
    {'matricule': 'TH-310-SN', 'modele': 'Toyota Coaster 36p', 'chauffeur': 'Ibrahima Fall', 'status': 'À quai (Thiès)'},
    {'matricule': 'SL-492-SN', 'modele': 'Mercedes Sprinter 22p', 'chauffeur': 'Alioune Sene', 'status': 'En maintenance'},
    {'matricule': 'DK-104-SN', 'modele': 'Tata Ultra 50p', 'chauffeur': 'Cheikh Ndiaye', 'status': 'En route (Saint-Louis)'},
  ];

  final List<Map<String, dynamic>> _caisses = [
    {'id': 'CS-01', 'chauffeur': 'Modou Diop', 'bus': 'DK-882-SN', 'montant': 145000, 'trajet': 'Dakar → Touba', 'date': 'Aujourd hui 14:30', 'statut': 'En attente'},
    {'id': 'CS-02', 'chauffeur': 'Ibrahima Fall', 'bus': 'TH-310-SN', 'montant': 85000, 'trajet': 'Dakar → Thiès', 'date': 'Aujourd hui 12:15', 'statut': 'En attente'},
    {'id': 'CS-03', 'chauffeur': 'Cheikh Ndiaye', 'bus': 'DK-104-SN', 'montant': 190000, 'trajet': 'Dakar → Saint-Louis', 'date': 'Aujourd hui 16:00', 'statut': 'En attente'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _validerCaisse(Map<String, dynamic> caisse) {
    setState(() {
      caisse['statut'] = 'Validée';
      if (_caissesAValider > 0) _caissesAValider--;
    });

    AuditService.instance.logAction(
      action: 'cash_closure.approve',
      targetType: 'cash_register',
      targetId: caisse['id'] as String,
      details: {
        'chauffeur': caisse['chauffeur'],
        'montant': caisse['montant'],
        'bus': caisse['bus'],
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Clôture de caisse de ${caisse['chauffeur']} validée (${caisse['montant']} FCFA).'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isGieAdmin = user.role == AppRole.gieAdmin || AuthService.instance.isSuperAdmin;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            isGieAdmin ? 'Supervision Flotte GIE' : 'Exploitation Flotte GIE',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.5, color: Color(0xFF0F172A)),
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
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
              ),
              child: Text(
                isGieAdmin ? 'GÉRANT GIE' : 'AGENT GIE',
                style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF1D4ED8),
            indicatorWeight: 3.5,
            labelColor: const Color(0xFF1D4ED8),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
            tabs: const [
              Tab(icon: Icon(Icons.insights), text: 'Vue Générale'),
              Tab(icon: Icon(Icons.directions_bus), text: 'Flotte & Bus'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Caisses à Valider'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(isGieAdmin),
            _buildFleetTab(),
            _buildCaissesTab(isGieAdmin),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isGieAdmin) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Cartouche GIE
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: const [
              Icon(Icons.business, color: DioufyColors.gold, size: 28),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coopérative Partenaire', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    'GIE Thiès Transports Réunis',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // KPI GRILLE
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'RECETTES DU JOUR',
                value: '1 250 000 FCFA',
                icon: Icons.payments,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'VOYAGES DU JOUR',
                value: '$_voyagesCount',
                icon: Icons.route,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'REMPLISSAGE',
                value: '$_tauxRemplissage %',
                icon: Icons.pie_chart,
                color: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'BUS EN SERVICE',
                value: '$_busActifs',
                icon: Icons.directions_bus,
                color: const Color(0xFF0891B2),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildKpiCard(
          title: 'CAISSES EN ATTENTE DE VALIDATION',
          value: '$_caissesAValider caisses',
          icon: Icons.pending_actions,
          color: _caissesAValider > 0 ? const Color(0xFFEA580C) : const Color(0xFF059669),
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isWide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            radius: 20,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _flotte.length,
      itemBuilder: (ctx, i) {
        final bus = _flotte[i];
        final isEnRoute = (bus['status'] as String).contains('route');
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEnRoute ? const Color(0xFF059669).withOpacity(0.15) : Colors.grey.shade200,
              child: Icon(Icons.directions_bus, color: isEnRoute ? const Color(0xFF059669) : Colors.grey),
            ),
            title: Text(bus['matricule'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${bus['modele']} • Chauffeur : ${bus['chauffeur']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEnRoute ? const Color(0xFF059669).withOpacity(0.15) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bus['status'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isEnRoute ? const Color(0xFF059669) : Colors.black54,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaissesTab(bool isGieAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _caisses.length,
      itemBuilder: (ctx, i) {
        final c = _caisses[i];
        final isValidated = c['statut'] == 'Validée';
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c['id'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: DioufyColors.primaryDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isValidated ? const Color(0xFF059669).withOpacity(0.15) : const Color(0xFFEA580C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c['statut'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isValidated ? const Color(0xFF059669) : const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${c['chauffeur']} • Bus ${c['bus']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Trajet : ${c['trajet']} (${c['date']})', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  '${c['montant']} FCFA',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                ),
                if (!isValidated && isGieAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _validerCaisse(c),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('VALIDER LA CLÔTURE DE CAISSE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
