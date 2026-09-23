import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/permission_guard.dart';
import '../../services/payment_config_service.dart';
import '../../services/trip_management_service.dart';
import '../../services/kpi_service.dart';
import '../../app/feature_flags/feature_flag_service.dart';
import '../../app/feature_flags/feature_flag_state.dart';
import 'rbac_management_screen.dart';
import '../../services/audit_service.dart';
import '../search/trip.dart';

/// Grand Tableau de Bord Centralisé Super Administrateur (Dioufy-TS)
/// Console d'exploitation et de gouvernance globale :
/// - Cockpit Exécutif & KPIs d'Exploitation (CA Encaissé, Taux d'Utilisation des Billets, Départs Actifs)
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
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
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
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Super Administration",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  "Console de Gouvernance Dioufy-TS",
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              // BOUTON VERT D'ACTION RAPIDE : + CRÉER COMPTE
              ElevatedButton.icon(
                onPressed: () => RbacManagementScreen.showCreateUserDialog(context),
                icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
                label: const Text(
                  '+ Créer Compte',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.storefront_outlined, color: Color(0xFF1D4ED8), size: 24),
                tooltip: "Espace Voyageur Public",
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
              ),
              const SizedBox(width: 10),
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
              _buildPaymentsTab(),
              _buildTripsTab(),
              _buildModulesTab(),
              _buildRbacTab(),
              _buildAuditLogTab(),
            ],
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: DioufyColors.primaryDark),
                SizedBox(height: 16),
                Text("Agrégation des métriques d'exploitation...", style: TextStyle(color: Colors.black54)),
              ],
            ),
          );
        }

        final report = snapshot.data;
        if (report == null) {
          return Center(
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
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            const SizedBox(height: 20),

            // Répartition du Chiffre d'Affaires par Passerelle de Paiement
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
        );
      },
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
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: iconColor, letterSpacing: 0.5),
              ),
              Icon(icon, size: 24, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          if (customValue != null) customValue else Text(
            value ?? "0",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: iconColor),
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
    final depCtrl = TextEditingController(text: trip?.departure ?? 'Dakar');
    final arrCtrl = TextEditingController(text: trip?.arrival ?? 'Touba');
    final compCtrl = TextEditingController(text: trip?.company ?? 'Dioufy Express');
    final priceCtrl = TextEditingController(text: trip?.price.toString() ?? '5000');
    final seatsCtrl = TextEditingController(text: trip?.seatsCount.toString() ?? '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trip == null ? "Créer un Trajet" : "Modifier le Trajet"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: depCtrl, decoration: const InputDecoration(labelText: "Ville de départ")),
              TextField(controller: arrCtrl, decoration: const InputDecoration(labelText: "Ville d'arrivée")),
              TextField(controller: compCtrl, decoration: const InputDecoration(labelText: "Compagnie / GIE")),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Prix en FCFA"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: seatsCtrl,
                decoration: const InputDecoration(labelText: "Nombre total de sièges"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(priceCtrl.text.trim()) ?? 5000;
              final seats = int.tryParse(seatsCtrl.text.trim()) ?? 50;
              if (trip == null) {
                TripManagementService.instance.addTrip(
                  departure: depCtrl.text.trim(),
                  arrival: arrCtrl.text.trim(),
                  company: compCtrl.text.trim(),
                  time: "08:00",
                  type: "CONFORT",
                  price: p,
                  seatsCount: seats,
                );
              } else {
                TripManagementService.instance.updateTripPrice(trip.id, p);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Valider"),
          ),
        ],
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
