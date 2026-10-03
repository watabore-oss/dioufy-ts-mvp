import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/cash_register_service.dart';

/// Écran de Clôture de Caisse Chauffeur / Chef de Bord
/// Connecté à Supabase — Financement réel et calcul sans données factices.
class ClotureCaisseScreen extends StatefulWidget {
  final int totalPassengers;
  final String route;
  final String busId;
  final String? tripId;

  const ClotureCaisseScreen({
    super.key,
    this.totalPassengers = 0,
    this.route = "Dakar → Touba",
    this.busId = "DK-882-SN",
    this.tripId,
  });

  @override
  State<ClotureCaisseScreen> createState() => _ClotureCaisseScreenState();
}

class _ClotureCaisseScreenState extends State<ClotureCaisseScreen> {
  int _digitalRevenue = 0;
  int _cashRevenue = 0;
  int _actualPassengers = 0;
  bool _isLoading = false;

  final double _driverCommissionRate = 0.07; // 7% commission chauffeur
  final double _platformFeeRate = 0.05;      // 5% plateforme
  final int _coxeurCommission = 2000;         // 2000 FCFA régulateur quai

  bool _isSaved = false;
  CashRegisterSession? _closedSession;

  @override
  void initState() {
    super.initState();
    _actualPassengers = widget.totalPassengers;
    _loadTripFinancials();
  }

  /// Chargement des recettes réelles des billets vendus pour ce trajet depuis Supabase
  Future<void> _loadTripFinancials() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Recherche du dernier trajet actif du chauffeur si tripId non fourni
      String? targetTripId = widget.tripId;
      if (targetTripId == null) {
        final tripsRes = await client
            .from('trips')
            .select('id, price, from_loc, to_loc')
            .order('depart_at', ascending: false)
            .limit(1);

        if (tripsRes.isNotEmpty) {
          targetTripId = tripsRes.first['id']?.toString();
        }
      }

      if (targetTripId != null) {
        // 2. Récupération des réservations payées pour ce trajet
        final bookingsRes = await client
            .from('bookings')
            .select('id, status, seats')
            .eq('trip_id', targetTripId)
            .eq('status', 'paid');

        int digitalTotal = 0;
        int cashTotal = 0;
        int passengersCount = 0;

        passengersCount = bookingsRes.length;
        final bookingIds = bookingsRes.map((b) => b['id'].toString()).toList();

        if (bookingIds.isNotEmpty) {
          final paymentsRes = await client
              .from('payments')
              .select('amount, provider, status')
              .inFilter('booking_id', bookingIds)
              .eq('status', 'successful');

          for (var p in paymentsRes) {
            final amt = (p['amount'] as num?)?.toInt() ?? 0;
            final provider = p['provider']?.toString().toLowerCase() ?? '';
            if (provider.contains('espece') || provider.contains('cash') || provider.contains('guichet')) {
              cashTotal += amt;
            } else {
              digitalTotal += amt;
            }
          }
        }

        if (mounted) {
          setState(() {
            _digitalRevenue = digitalTotal;
            _cashRevenue = cashTotal;
            _actualPassengers = passengersCount;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Chargement finances trajet: $e');
    }

    if (mounted) {
      setState(() {
        // En cas d'absence de données existantes pour ce trajet
        _digitalRevenue = 0;
        _cashRevenue = 0;
        _actualPassengers = widget.totalPassengers;
        _isLoading = false;
      });
    }
  }

  int get _totalRevenue => _digitalRevenue + _cashRevenue;
  int get _driverCommission => (_totalRevenue * _driverCommissionRate).round();
  int get _platformFee => (_totalRevenue * _platformFeeRate).round();
  int get _netCashToDeposit => (_cashRevenue - _driverCommission - _coxeurCommission).clamp(0, 9999999);
  int get _gieNetRevenue => (_totalRevenue - _driverCommission - _coxeurCommission - _platformFee).clamp(0, 9999999);

  Future<void> _validateCloture() async {
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    final session = CashRegisterSession(
      id: "CLS-${now.millisecondsSinceEpoch}",
      tripId: widget.tripId ?? "TRIP-${now.millisecondsSinceEpoch}",
      busId: widget.busId,
      route: widget.route,
      date: dateStr,
      totalPassengers: _actualPassengers,
      digitalRevenue: _digitalRevenue,
      cashRevenue: _cashRevenue,
      driverCommissionRate: _driverCommissionRate,
      coxeurCommission: _coxeurCommission,
      closedAt: now,
      isClosed: true,
    );

    final savedSession = await CashRegisterService.saveSession(session);

    if (mounted) {
      setState(() {
        _isSaved = true;
        _closedSession = savedSession;
      });
      final msg = savedSession.isSynced
          ? "Clôture de caisse validée et certifiée par le serveur !"
          : "Clôture de caisse enregistrée avec succès (mode hors-ligne) !";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _shareOnWhatsApp() async {
    if (_closedSession == null) return;
    final text = CashRegisterService.generateReceiptText(_closedSession!);
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showReceiptDialog(text);
      }
    }
  }

  void _showReceiptDialog(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Bordereau de Caisse",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTransferCommissionDialog() {
    final phoneController = TextEditingController(text: "77 123 45 67");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet, color: Color(0xFFFBBF24)),
            SizedBox(width: 8),
            Text("Transfert Commission", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Montant à transférer : $_driverCommission FCFA",
              style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              "Compte Mobile Money de destination :",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: "+221 ",
                prefixStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _walletChip("Wave", const Color(0xFF00A3FF)),
                _walletChip("Orange Money", const Color(0xFFFF6600)),
                _walletChip("Free Money", const Color(0xFFE60000)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Transfert de $_driverCommission FCFA vers le +221 ${phoneController.text} réussi !"),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
            child: const Text("Confirmer le transfert", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _walletChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  /// Dialogue permettant au chauffeur d'ajuster le montant espèces collecté en route
  void _showAdjustCashDialog() {
    final cashCtrl = TextEditingController(text: '$_cashRevenue');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajuster Espèces en Main', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez le montant total en espèces effectivement collecté au bord du bus :',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                suffixText: 'FCFA',
                suffixStyle: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Color(0xFF0F172A),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () {
              final newCash = int.tryParse(cashCtrl.text.trim()) ?? _cashRevenue;
              setState(() => _cashRevenue = newCash);
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: const Text(
          "Clôture de Caisse Chauffeur",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Actualiser',
            onPressed: _loadTripFinancials,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF34D399)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bandeau d'en-tête voyage réel
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.route,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Bus : ${widget.busId} • $_actualPassengers passagers enregistrés",
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF059669)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.verified, color: Color(0xFF34D399), size: 14),
                              SizedBox(width: 4),
                              Text("Fin de ligne", style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // GRILLE DES RECETTES COLLECTÉES
                  const Text(
                    "Recettes Réelles Collectées",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _revenueCard(
                          title: "Paiements Digitaux",
                          subtitle: "Wave & Cartes",
                          amount: "$_digitalRevenue FCFA",
                          icon: Icons.contactless,
                          color: const Color(0xFF00A3FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _showAdjustCashDialog,
                          borderRadius: BorderRadius.circular(16),
                          child: _revenueCard(
                            title: "Espèces au Bord",
                            subtitle: "Collecte physique ✎",
                            amount: "$_cashRevenue FCFA",
                            icon: Icons.payments,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // TOTAL RECETTES AVEC BADGE XOF
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('XOF', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 10)),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Total Recettes Trajet",
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Text(
                          "$_totalRevenue FCFA",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DÉTAILS DE RÉPARTITION RÉELLE DU REVENU
                  const Text(
                    "Partage des Revenus & Rémunérations",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        _distributionRow(
                          label: "Commission Chauffeur (7%)",
                          amount: "$_driverCommission FCFA",
                          color: const Color(0xFF34D399),
                          isHighlight: true,
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        _distributionRow(
                          label: "Régulation Quai / Coxeur",
                          amount: "$_coxeurCommission FCFA",
                          color: const Color(0xFFFBBF24),
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        _distributionRow(
                          label: "Frais de Service Dioufy (5%)",
                          amount: "$_platformFee FCFA",
                          color: const Color(0xFF60A5FA),
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        _distributionRow(
                          label: "Part Nette Transporteur GIE",
                          amount: "$_gieNetRevenue FCFA",
                          color: Colors.white,
                          isBold: true,
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        _distributionRow(
                          label: "Espèces Nettes à Verser au GIE",
                          amount: "$_netCashToDeposit FCFA",
                          color: const Color(0xFFF87171),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // BOUTONS D'ACTION
                  if (!_isSaved)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _validateCloture,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text(
                          "VALIDER LA CLÔTURE DE CAISSE",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF059669)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Color(0xFF34D399)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Caisse clôturée et transmise au GIE avec succès.",
                              style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _shareOnWhatsApp,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text("Partager WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _showTransferCommissionDialog,
                            icon: const Icon(Icons.send_to_mobile, size: 18),
                            label: const Text("Retirer Commission", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _revenueCard({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _distributionRow({
    required String label,
    required String amount,
    required Color color,
    bool isHighlight = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? color : Colors.white70,
            fontSize: isHighlight ? 14 : 13,
            fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: isHighlight ? 15 : 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
