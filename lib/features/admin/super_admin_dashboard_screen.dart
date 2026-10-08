import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/permission_guard.dart';
import '../../services/payment_config_service.dart';
import '../../services/trip_management_service.dart';
import '../../services/organization_service.dart';
import '../../services/kpi_service.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import 'rbac_management_screen.dart';
import '../../services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/booking_service.dart';
import '../search/trip.dart';

/// Grand Tableau de Bord Centralisé Super Administrateur (Dioufy-TS)
/// Console d'exploitation et de gouvernance globale :
/// - Cockpit Exécutif & KPIs d'Exploitation (CA Encaissé, Taux d'Utilisation des Billets, Départs Actifs)
/// - Gestion et Enregistrement Souverain des Coopératives GIE
/// - Passerelles de Paiement paramétrables dynamiquement
/// - Trajets & Tarifs en FCFA avec badge XOF
/// - Activation des Modules Compilés (Feature Flags)
/// - Matrice de Gouvernance RBAC
/// - Journal d'Audit Système
class SuperAdminDashboardScreen extends StatefulWidget {
  final int initialTab;

  const SuperAdminDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<PlatformKpiReport>? _kpiFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 7),
    );
    _refreshKpis();
  }

  void _refreshKpis() {
    setState(() {
      _kpiFuture = KpiService.instance.fetchPlatformKpis();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleBackNavigation(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permissionId: AppPermission.rbacManagePermissions,
      actionLabel: "Console d'Administration Dioufy-TS",
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _handleBackNavigation(context);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 24),
              tooltip: 'Retour',
              onPressed: () => _handleBackNavigation(context),
            ),
            title: const Text(
              "Super Administration",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // BOUTON VERT D'ACTION RAPIDE : + CRÉER COMPTE
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: () => RbacManagementScreen.showCreateUserDialog(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.white),
                  label: const Text(
                    '+ Créer Compte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.storefront_outlined, color: Color(0xFF1D4ED8), size: 22),
                tooltip: "Espace Voyageur Public",
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF1D4ED8),
              indicatorWeight: 3.5,
              labelColor: const Color(0xFF1D4ED8),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Cockpit & KPIs'),
                Tab(icon: Icon(Icons.verified_outlined), text: 'Validation Paiements'),
                Tab(icon: Icon(Icons.corporate_fare_outlined), text: 'Coopératives GIE'),
                Tab(icon: Icon(Icons.payments_outlined), text: 'Passerelles Paiement'),
                Tab(icon: Icon(Icons.directions_bus_outlined), text: 'Trajets & Prix FCFA'),
                Tab(icon: Icon(Icons.toggle_on_outlined), text: 'Modules & Flags'),
                Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: 'Gouvernance RBAC'),
                Tab(icon: Icon(Icons.history_outlined), text: 'Journal d\'Audit'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildKpiTab(),
              _buildPendingPaymentsTab(),
              _buildGieTab(),
              _buildPaymentsTab(),
              _buildTripsTab(),
              _buildModulesTab(),
              _buildRbacTab(),
              _buildAuditLogTab(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => RbacManagementScreen.showCreateUserDialog(context),
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(
              'Créer Compte',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. ONGLET COCKPIT EXÉCUTIF & KPIS OPÉRATIONNELS SERVEUR
  // ===========================================================================
  Widget _buildKpiTab() {
    return FutureBuilder<PlatformKpiReport>(
      future: _kpiFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final report = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bandeau d'action rapide souverain : Création de compte utilisateur (TOUJOURS visible)
            _buildKpiCreateAccountBanner(),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: DioufyColors.primaryDark),
                      SizedBox(height: 16),
                      Text("Agrégation des métriques d'exploitation...", style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              )
            else if (report == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text("Données KPI non disponibles"),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _refreshKpis,
                        child: const Text("Réessayer"),
                      ),
                    ],
                  ),
                ),
              )
            else ...[

            // Bandeau de synchronisation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Indicateurs Clés d'Exploitation (KPIs)",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: DioufyColors.primaryDark),
                    ),
                    Text(
                      "Calculs serveurs réels • Mis à jour à ${_formatTime(report.generatedAt)}",
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: DioufyColors.primaryDark),
                  tooltip: "Actualiser les métriques",
                  onPressed: _refreshKpis,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grille des 4 Métriques Principales
            Row(
              children: [
                // 1. CA Encaissé en FCFA avec badge XOF
                Expanded(
                  child: _buildMetricCard(
                    title: "CA ENCAISSÉ",
                    formulaSubtitle: "Transactions complétées",
                    customValue: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            "${report.totalRevenueCollected} FCFA",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const XofCurrencyBadge(size: 16),
                      ],
                    ),
                    icon: Icons.account_balance_wallet,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 12),
                // 2. Taux d'utilisation des billets
                Expanded(
                  child: _buildMetricCard(
                    title: "TAUX D'UTILISATION",
                    formulaSubtitle: "Billets utilisés / vendus",
                    value: "${report.ticketUsageRate} %",
                    icon: Icons.qr_code_scanner,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    footerText: "${report.totalTicketsUsed} validés / ${report.totalTicketsSold} vendus",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // 3. Départs Actifs du Jour
                Expanded(
                  child: _buildMetricCard(
                    title: "DÉPARTS DU JOUR",
                    formulaSubtitle: "Trajets programmés actifs",
                    value: "${report.activeTripsToday}",
                    icon: Icons.directions_bus,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 12),
                // 4. Billets Vendus Encaissés
                Expanded(
                  child: _buildMetricCard(
                    title: "BILLETS ENCAISSÉS",
                    formulaSubtitle: "Volume total validé",
                    value: "${report.totalTicketsSold}",
                    icon: Icons.confirmation_number_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Métriques d'infrastructure opérationnelle réelle
            AnimatedBuilder(
              animation: OrganizationService.instance,
              builder: (context, _) {
                final orgService = OrganizationService.instance;
                final totalVehicles = orgService.organizations.fold<int>(0, (sum, g) => sum + g.vehicleCount);
                return Row(
                  children: [
                    // 5. Coopératives GIE Actives
                    Expanded(
                      child: _buildMetricCard(
                        title: "COOPÉRATIVES GIE",
                        formulaSubtitle: "Opérateurs partenaires actifs",
                        value: "${orgService.activeOrganizations.length}",
                        icon: Icons.corporate_fare,
                        iconColor: const Color(0xFF1D4ED8),
                        bgColor: const Color(0xFFEFF6FF),
                        footerText: "${orgService.organizations.length} coopérative(s) au total",
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 6. Flotte de Véhicules Enregistrés
                    Expanded(
                      child: _buildMetricCard(
                        title: "FLOTTE ENREGISTRÉE",
                        formulaSubtitle: "Bus de transport rattachés",
                        value: "$totalVehicles",
                        icon: Icons.directions_bus_filled,
                        iconColor: const Color(0xFF0F766E),
                        bgColor: const Color(0xFFF0FDFA),
                        footerText: "Véhicules aptes aux lignes interurbaines",
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Répartition du Chiffre d'Affaires par Passerelle de Paiement
            if (report.totalRevenueCollected == 0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.point_of_sale_outlined, size: 36, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Plateforme Prête • 0 FCFA Encaissé",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Les indicateurs de chiffre d'affaires et la répartition par passerelle (Wave, Orange Money, Free Money, Espèces) s'actualiseront en direct dès les premières réservations validées.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildGatewayBadge('Wave Sénégal', const Color(0xFF00B2FE)),
                        _buildGatewayBadge('Orange Money', const Color(0xFFFF7900)),
                        _buildGatewayBadge('Free Money', const Color(0xFFDC2626)),
                        _buildGatewayBadge('Espèces (Gare)', const Color(0xFF059669)),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_outline, size: 20, color: DioufyColors.primaryDark),
                        SizedBox(width: 8),
                        Text(
                          "Répartition des Encaissements par Moyen de Paiement",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DioufyColors.primaryDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...report.revenueByGateway.entries.map((entry) {
                      final gatewayName = _formatGatewayLabel(entry.key);
                      final amount = entry.value;
                      final pct = report.totalRevenueCollected > 0
                          ? (amount / report.totalRevenueCollected) * 100
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(gatewayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "$amount FCFA",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 4),
                                    const XofCurrencyBadge(size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      "(${pct.toStringAsFixed(1)}%)",
                                      style: const TextStyle(color: Colors.black54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade200,
                              color: _getGatewayColor(entry.key),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ],
      );
    },
  );
}

  Widget _buildKpiCreateAccountBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Nouveau compte utilisateur",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Provisionner chauffeur, coxeur, GIE, garagiste...",
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => RbacManagementScreen.showCreateUserDialog(context),
            icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
            label: const Text(
              "+ Créer un Compte",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String formulaSubtitle,
    String? value,
    Widget? customValue,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    String? footerText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: iconColor, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 22, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          if (customValue != null) customValue else Text(
            value ?? "0",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: iconColor),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(formulaSubtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (footerText != null) ...[
            const SizedBox(height: 8),
            Text(footerText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ],
      ),
    );
  }

  String _formatGatewayLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'wave':
        return 'Wave Sénégal';
      case 'orange_money':
        return 'Orange Money';
      case 'free_money':
        return 'Free Money';
      case 'cash':
        return 'Espèces (Gare)';
      default:
        return raw.toUpperCase();
    }
  }

  Color _getGatewayColor(String raw) {
    switch (raw.toLowerCase()) {
      case 'wave':
        return const Color(0xFF00B2FE);
      case 'orange_money':
        return const Color(0xFFFF7900);
      case 'free_money':
        return const Color(0xFFDC2626);
      case 'cash':
        return const Color(0xFF059669);
      default:
        return DioufyColors.primaryDark;
    }
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildGatewayBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1.BIS. ONGLET VALIDATION DES PAIEMENTS EN ATTENTE (CONSOLE DE RECOUVREMENT)
  // ===========================================================================
  Widget _buildPendingPaymentsTab() {
    final client = Supabase.instance.client;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: client
          .from('bookings')
          .select('id, user_id, trip_id, seats, status, lock_expires_at, passenger_name, passenger_phone, created_at, trips(price, from_loc, to_loc, depart_at, agencies(name))')
          .inFilter('status', ['pending', 'payment_pending'])
          .order('created_at', ascending: false)
          .limit(50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: DioufyColors.primaryDark),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    "Erreur de chargement des réservations : ${snapshot.error}",
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Réessayer"),
                  ),
                ],
              ),
            ),
          );
        }

        final bookings = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: const Color(0xFF1D4ED8),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Bandeau explicatif administratif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B2FE).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_outlined, color: Color(0xFF0084BA), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "File des Paiements en Attente",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: bookings.isEmpty ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${bookings.length} en attente",
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Vérifiez le reçu marchand ou l'encaissement guichet, puis certifiez la transaction pour émettre instantanément le billet du voyageur.",
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1D4ED8)),
                      tooltip: "Actualiser la file",
                      onPressed: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (bookings.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 48),
                      SizedBox(height: 12),
                      Text(
                        "Aucun paiement en attente",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Toutes les réservations sont soldées ou confirmées automatiquement par les webhooks.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...bookings.map((b) => _buildPendingBookingCard(b)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingBookingCard(Map<String, dynamic> b) {
    final bookingId = b['id']?.toString() ?? '';
    final passengerName = b['passenger_name']?.toString() ?? 'Voyageur Direct';
    final passengerPhone = b['passenger_phone']?.toString() ?? 'N/A';
    final trip = b['trips'] as Map<String, dynamic>?;
    final agency = trip?['agencies'] as Map<String, dynamic>?;
    final company = agency?['name']?.toString() ?? 'GIE Partenaire';
    final dep = trip?['from_loc']?.toString() ?? 'Départ';
    final arr = trip?['to_loc']?.toString() ?? 'Arrivée';
    final int unitPrice = (trip?['price'] as num?)?.toInt() ?? 0;

    List<dynamic> seatsList = [];
    if (b['seats'] is List) {
      seatsList = b['seats'] as List;
    }
    final seatsStr = seatsList.isNotEmpty ? seatsList.join(', ') : '1 place';
    final int totalAmount = unitPrice * (seatsList.isNotEmpty ? seatsList.length : 1);
    final createdAt = DateTime.tryParse(b['created_at']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B2FE).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0084BA), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              passengerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Tél: $passengerPhone",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        "En attente",
                        style: TextStyle(color: Color(0xFF92400E), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              children: [
                const Icon(Icons.directions_bus_outlined, size: 15, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$company • $dep → $arr",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_seat_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text("Siège(s) : $seatsStr", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 2),
                    Text(
                      "Réf : ${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}",
                      style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                if (createdAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text("Créé à ${_formatTime(createdAt)}", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Montant à encaisser :", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Row(
                      children: [
                        Text(
                          "$totalAmount FCFA",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const XofCurrencyBadge(size: 16),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showValidatePaymentDialog(
                    bookingId: bookingId,
                    passengerName: passengerName,
                    passengerPhone: passengerPhone,
                    totalAmount: totalAmount,
                    seatsStr: seatsStr,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                  label: const Text(
                    "Valider le Paiement",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showValidatePaymentDialog({
    required String bookingId,
    required String passengerName,
    required String passengerPhone,
    required int totalAmount,
    required String seatsStr,
  }) {
    final formKey = GlobalKey<FormState>();
    String selectedProvider = 'Wave';
    final refController = TextEditingController(
      text: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    bool isConfirming = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFF059669)),
              SizedBox(width: 10),
              Text(
                "Certifier l'Encaissement",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Voyageur : $passengerName ($passengerPhone)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text("Siège(s) : $seatsStr", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        const SizedBox(height: 3),
                        Text(
                          "Montant vérifié : $totalAmount FCFA",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("Moyen d'encaissement constaté :", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProvider,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Wave', child: Text('Wave (Transfert / QR Marchand)')),
                      DropdownMenuItem(value: 'Orange Money', child: Text('Orange Money')),
                      DropdownMenuItem(value: 'Free Money', child: Text('Free Money')),
                      DropdownMenuItem(value: 'Cash', child: Text('Espèces / Guichet (Cash)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedProvider = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text("Référence du reçu / Transaction :", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: refController,
                    decoration: const InputDecoration(
                      hintText: "Ex: WAVE-TX-998243 ou RECU-CAISSE-12",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Veuillez renseigner une référence de reçu";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isConfirming ? null : () => Navigator.pop(dlgCtx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: isConfirming
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isConfirming = true);

                      try {
                        final bookingService = BookingService();
                        await bookingService.confirmPayment(
                          bookingIds: [bookingId],
                          provider: selectedProvider,
                          providerRef: refController.text.trim(),
                          amount: totalAmount,
                        );

                        if (!dlgCtx.mounted) return;
                        Navigator.pop(dlgCtx);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Paiement certifié avec succès pour $passengerName ! Le billet est émis."),
                              backgroundColor: const Color(0xFF059669),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          setState(() {});
                          _refreshKpis();
                        }
                      } catch (e) {
                        setDlgState(() => isConfirming = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Erreur validation paiement : $e"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              child: isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("CONFIRMER LE PAIEMENT"),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1.TER. ONGLET COOPÉRATIVES GIE (PRIORITÉ 1)
  // ===========================================================================
  Widget _buildGieTab() {
    return AnimatedBuilder(
      animation: OrganizationService.instance,
      builder: (context, _) {
        final orgService = OrganizationService.instance;
        final orgs = orgService.organizations;
        final activeCount = orgService.activeOrganizations.length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bandeau d'actions et synthèse GIE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.corporate_fare, color: Color(0xFF1D4ED8), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Coopératives & GIE Partenaires",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "$activeCount active(s) sur ${orgs.length} enregistrée(s)",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddGieDialog(context),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text(
                      "+ Enregistrer GIE",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (orgService.isLoading && orgs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: DioufyColors.primaryDark),
                ),
              )
            else if (orgs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_outlined, size: 54, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 14),
                    const Text(
                      "Aucune coopérative GIE enregistrée",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Enregistrez les coopératives de transport pour leur permettre d'administrer leur flotte, leurs bus et de programmer leurs départs.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddGieDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Enregistrer le premier GIE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...orgs.map((org) => _buildGieCard(org)),
          ],
        );
      },
    );
  }

  Widget _buildGieCard(GieOrganization org) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: org.isActive ? const Color(0xFF1D4ED8).withOpacity(0.35) : Colors.black12,
          width: org.isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: org.isActive ? const Color(0xFFEFF6FF) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: org.isActive ? const Color(0xFF1D4ED8) : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              org.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: org.isActive ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              org.isActive ? 'ACTIF' : 'SUSPENDU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: org.isActive ? const Color(0xFF059669) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Code: ${org.code.isNotEmpty ? org.code : org.id} • Coopérative GIE",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: org.isActive,
                  activeThumbColor: const Color(0xFF059669),
                  onChanged: (val) async {
                    try {
                      await OrganizationService.instance.toggleOrganizationStatus(org.id, val);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Échec de la modification du statut GIE."),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (org.contactPhone != null && org.contactPhone!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(org.contactPhone!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ],
                  ),
                if (org.contactEmail != null && org.contactEmail!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(org.contactEmail!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ],
                  ),
                if (org.licenseNumber != null && org.licenseNumber!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text("Licence: ${org.licenseNumber}", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_bus_filled_outlined, size: 14, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 4),
                    Text(
                      "${org.vehicleCount} bus rattaché(s)",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGieDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.corporate_fare, color: Color(0xFF1D4ED8)),
              SizedBox(width: 10),
              Text("Enregistrer un GIE / Coopérative", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Création de la coopérative de transport dans Supabase. Les gérants et chauffeurs pourront ensuite y être rattachés.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nom officiel de la coopérative *",
                      hintText: "Ex: GIE Ndiambour Louga",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    onChanged: (v) {
                      if (codeCtrl.text.isEmpty || codeCtrl.text.startsWith('gie_')) {
                        final autoCode = v
                            .trim()
                            .toLowerCase()
                            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                            .replaceAll(RegExp(r'^_+|_+$'), '');
                        codeCtrl.text = autoCode.isEmpty ? '' : 'gie_$autoCode';
                      }
                    },
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Le nom est obligatoire" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: "Code identifiant unique *",
                      hintText: "Ex: gie_ndiambour",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "L'identifiant unique est obligatoire" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Téléphone de contact",
                      hintText: "Ex: +221 77 123 45 67",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email officiel de contact",
                      hintText: "Ex: contact@gie-ndiambour.sn",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: licenseCtrl,
                    decoration: const InputDecoration(
                      labelText: "Numéro de licence transport",
                      hintText: "Ex: LIC-TR-2026-SN",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      try {
                        final created = await OrganizationService.instance.createOrganization(
                          name: nameCtrl.text.trim(),
                          code: codeCtrl.text.trim(),
                          contactPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                          contactEmail: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                          licenseNumber: licenseCtrl.text.trim().isNotEmpty ? licenseCtrl.text.trim() : null,
                        );

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Coopérative '${created.name}' enregistrée avec succès !"),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      } catch (err) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Erreur lors de l'enregistrement de la coopérative: $err"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("ENREGISTRER"),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. ONGLET PASSERELLES DE PAIEMENT (ZÉRO DONNÉE EN DUR)
  // ===========================================================================
  Widget _buildPaymentsTab() {
    return AnimatedBuilder(
      animation: PaymentConfigService.instance,
      builder: (context, _) {
        final gateways = PaymentConfigService.instance.allGateways;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWaveOfficialCard(),
            const SizedBox(height: 16),
            const Text(
              'Catalogue des Passerelles de Paiement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DioufyColors.primaryDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paramétrage dynamique des passerelles. Les identifiants marchands et QR codes sont modifiables sans recompilation.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            ...gateways.map((gateway) => _buildGatewayTile(gateway)),
          ],
        );
      },
    );
  }

  Widget _buildWaveOfficialCard() {
    final waveConfig = PaymentConfigService.instance.getGateway('wave');
    final isEnabled = waveConfig?.isEnabled ?? true;
    final merchantIdentifier = waveConfig?.merchantCode ?? 'Compte Marchand Non Configuré';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00B2FE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B2FE).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF00B2FE),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Wave Sénégal (Officiel)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Switch(
                  value: isEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF0F172A),
                  onChanged: (val) {
                    PaymentConfigService.instance.toggleGateway('wave', val);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showFullImageDialog(context, 'assets/wave_merchant_qr.jpg'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 90,
                      height: 125,
                      color: Colors.grey.shade100,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Image.asset(
                            'assets/wave_merchant_qr.jpg',
                            fit: BoxFit.cover,
                            width: 90,
                            height: 125,
                            errorBuilder: (c, e, s) => const Icon(Icons.qr_code, size: 48, color: Color(0xFF00B2FE)),
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: const Text(
                              'Zoomer',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identifiant Marchand Configuré :',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B2FE).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          merchantIdentifier,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00B2FE),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Paiement direct sans frais. Déclenché par QR Code officiel ou push automatique sur le terminal du voyageur.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      if (waveConfig != null)
                        ElevatedButton.icon(
                          onPressed: () => _editGatewayDialog(context, waveConfig),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Modifier l\'identifiant ou le QR', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayTile(PaymentGatewayConfig gateway) {
    if (gateway.id == 'wave') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gateway.isEnabled ? gateway.brandColor.withOpacity(0.4) : Colors.black12,
          width: gateway.isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: gateway.brandColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(gateway.iconData, color: gateway.brandColor, size: 22),
        ),
        title: Row(
          children: [
            Text(gateway.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: gateway.isEnabled ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                gateway.isEnabled ? 'ACTIF' : 'INACTIF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: gateway.isEnabled ? const Color(0xFF059669) : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          gateway.description,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        trailing: Switch(
          value: gateway.isEnabled,
          activeColor: gateway.brandColor,
          onChanged: (val) {
            PaymentConfigService.instance.toggleGateway(gateway.id, val);
          },
        ),
        onTap: () => _editGatewayDialog(context, gateway),
      ),
    );
  }

  void _editGatewayDialog(BuildContext context, PaymentGatewayConfig gateway) {
    final codeCtrl = TextEditingController(text: gateway.merchantCode ?? '');
    final nameCtrl = TextEditingController(text: gateway.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Paramétrer ${gateway.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nom d'affichage"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: "Identifiant / Numéro Marchand",
                hintText: "Ex: Identifiant API ou Téléphone",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final updated = gateway.copyWith(
                name: nameCtrl.text.trim(),
                merchantCode: codeCtrl.text.trim(),
              );
              PaymentConfigService.instance.updateGateway(updated);
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _showFullImageDialog(BuildContext context, String assetPath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fermer"),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. ONGLET TRAJETS & PRIX FCFA
  // ===========================================================================
  Widget _buildTripsTab() {
    return AnimatedBuilder(
      animation: TripManagementService.instance,
      builder: (context, _) {
        final trips = TripManagementService.instance.trips;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lignes & Grille Tarifaire FCFA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DioufyColors.primaryDark),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau Trajet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _editTripDialog(context, null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...trips.map((trip) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${trip.departure} → ${trip.arrival}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text("${trip.company} • ${trip.type} (${trip.seatsCount} sièges)",
                              style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${trip.price} FCFA",
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const XofCurrencyBadge(size: 14),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.black54),
                            onPressed: () => _editTripDialog(context, trip),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () => TripManagementService.instance.deleteTrip(trip.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  void _editTripDialog(BuildContext context, Trip? trip) {
    final activeOrgs = OrganizationService.instance.activeOrganizations;

    // Valeurs initiales
    String selectedDep = trip?.departure ?? AppConstants.stations.first;
    if (!AppConstants.stations.contains(selectedDep)) {
      selectedDep = AppConstants.stations.first;
    }

    String selectedArr = trip?.arrival ?? AppConstants.stations[1];
    if (!AppConstants.stations.contains(selectedArr)) {
      selectedArr = AppConstants.stations[1];
    }

    String? selectedOrgId = activeOrgs.isNotEmpty ? activeOrgs.first.id : null;
    String selectedCompanyName = trip?.company ?? (activeOrgs.isNotEmpty ? activeOrgs.first.name : 'Coopérative Partenaire');
    if (trip != null) {
      final matches = activeOrgs.where((o) => o.name.toLowerCase() == trip.company.toLowerCase());
      if (matches.isNotEmpty) {
        selectedOrgId = matches.first.id;
      }
    }

    final timeCtrl = TextEditingController(text: trip?.time ?? "07:30");
    final priceCtrl = TextEditingController(text: trip?.price.toString() ?? '5000');
    final seatsCtrl = TextEditingController(text: trip?.seatsCount.toString() ?? '45');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.directions_bus, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Text(trip == null ? "Programmer un Trajet" : "Modifier le Trajet",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélecteur de Coopérative GIE
                  if (activeOrgs.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: activeOrgs.any((o) => o.id == selectedOrgId) ? selectedOrgId : activeOrgs.first.id,
                      decoration: const InputDecoration(
                        labelText: "Coopérative / GIE Opérateur *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.corporate_fare),
                      ),
                      items: activeOrgs.map((org) {
                        return DropdownMenuItem<String>(
                          value: org.id,
                          child: Text(org.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = activeOrgs.firstWhere((o) => o.id == val);
                          setDialogState(() {
                            selectedOrgId = val;
                            selectedCompanyName = match.name;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Gare de départ
                  DropdownButtonFormField<String>(
                    value: selectedDep,
                    decoration: const InputDecoration(
                      labelText: "Gare de départ *",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trip_origin, color: Color(0xFF059669)),
                    ),
                    items: AppConstants.stations.map((st) {
                      return DropdownMenuItem<String>(value: st, child: Text(st, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedDep = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Gare d'arrivée
                  DropdownButtonFormField<String>(
                    value: selectedArr,
                    decoration: const InputDecoration(
                      labelText: "Gare d'arrivée *",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on, color: Color(0xFFDC2626)),
                    ),
                    items: AppConstants.stations.map((st) {
                      return DropdownMenuItem<String>(value: st, child: Text(st, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedArr = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Heure de départ
                  TextFormField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: "Heure de départ (HH:mm) *",
                      hintText: "Ex: 07:30",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "L'heure est requise" : null,
                  ),
                  const SizedBox(height: 12),

                  // Prix en FCFA
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: "Tarif du billet (FCFA) *",
                      hintText: "Ex: 5000",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: "FCFA",
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Le prix est requis";
                      final p = int.tryParse(v.trim());
                      if (p == null || p <= 0) return "Prix FCFA invalide";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Capacité en sièges
                  TextFormField(
                    controller: seatsCtrl,
                    decoration: const InputDecoration(
                      labelText: "Capacité totale (sièges) *",
                      hintText: "Ex: 45",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event_seat),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Capacité requise";
                      final s = int.tryParse(v.trim());
                      if (s == null || s <= 0) return "Nombre de sièges invalide";
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final p = int.parse(priceCtrl.text.trim());
                final seats = int.parse(seatsCtrl.text.trim());
                if (trip == null) {
                  TripManagementService.instance.addTrip(
                    departure: selectedDep,
                    arrival: selectedArr,
                    company: selectedCompanyName,
                    time: timeCtrl.text.trim(),
                    type: "CONFORT",
                    price: p,
                    seatsCount: seats,
                    organizationId: selectedOrgId,
                  );
                } else {
                  TripManagementService.instance.updateTripPrice(trip.id, p);
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Trajet $selectedDep → $selectedArr enregistré !"),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              },
              child: const Text("Valider"),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. ONGLET MODULES & FEATURE FLAGS
  // ===========================================================================
  static const List<Map<String, String>> _allModules = [
    {
      'key': FeatureFlagState.flagCoreTraveler,
      'name': 'Module Voyageurs & Recherche',
      'desc': 'Recherche de lignes, horaires et affichage des tarifs FCFA',
    },
    {
      'key': FeatureFlagState.flagSeatLockEngine,
      'name': 'Moteur de Réservation & Sièges',
      'desc': 'Verrouillage atomique des sièges à bord du bus',
    },
    {
      'key': FeatureFlagState.flagPaymentWave,
      'name': 'Paiement Wave Sénégal',
      'desc': 'Paiement instantané Wave via passerelle paramétrable',
    },
    {
      'key': FeatureFlagState.flagPaymentOm,
      'name': 'Paiement Orange Money',
      'desc': 'Autorisation sécurisée Orange Money Sénégal',
    },
    {
      'key': FeatureFlagState.flagTicketingHmacQr,
      'name': 'Billettique Numérique & QR HMAC',
      'desc': 'Génération du Boarding Pass sécurisé et signé',
    },
    {
      'key': FeatureFlagState.flagFieldOpsCameraScan,
      'name': 'Contrôle Terrain & Scanner Caméra',
      'desc': 'Lecture optique instantanée des billets sur quai',
    },
    {
      'key': FeatureFlagState.flagCashClosureChauffeur,
      'name': 'Clôture de Caisse & Commissions',
      'desc': 'Calcul des commissions et solde net à reverser au GIE',
    },
    {
      'key': FeatureFlagState.flagMultiTenancyGie,
      'name': 'Multi-Tenancy GIE & Flotte',
      'desc': 'Cloisonnement par coopérative de transport',
    },
    {
      'key': FeatureFlagState.flagGarageMarketplaceSos,
      'name': 'SOS Dépannage & Garages Agréés',
      'desc': 'Assistance géolocalisée et diagnostic de panne',
    },
  ];

  Widget _buildModulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Règle d\'Or : « Désactiver ≠ Supprimer ». Désactiver un module masque l\'interface sans altérer l\'intégrité des données historiques.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._allModules.map((mod) {
          final isEnabled = FeatureFlagService.instance.isEnabled(mod['key']!);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: Text(mod['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(mod['desc']!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              value: isEnabled,
              activeTrackColor: const Color(0xFF059669),
              onChanged: (val) async {
                await FeatureFlagService.instance.setFlag(mod['key']!, val);
                setState(() {});
              },
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // 5. ONGLET GOUVERNANCE RBAC & MATRICE DES RÔLES
  // ===========================================================================
  Widget _buildRbacTab() {
    return const RbacManagementScreen(showAppBar: false);
  }

  // ===========================================================================
  // 6. ONGLET JOURNAL D'AUDIT SYSTÈME
  // ===========================================================================
  Widget _buildAuditLogTab() {
    return FutureBuilder<List<AuditEntry>>(
      future: AuditService.instance.fetchRecentLogs(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: DioufyColors.primaryDark),
          );
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              "Aucun événement d'audit récent",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (ctx, i) {
            final log = logs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: DioufyColors.primaryDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("${log.targetType} #${log.targetId} • Rôle: ${log.actorRole}",
                            style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(log.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
