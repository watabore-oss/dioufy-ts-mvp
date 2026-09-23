import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../services/cash_register_service.dart';

class ClotureCaisseScreen extends StatefulWidget {
  final int totalPassengers;
  final String route;
  final String busId;

  const ClotureCaisseScreen({
    super.key,
    this.totalPassengers = 35,
    this.route = "Dakar → Touba",
    this.busId = "DK-882-SN",
  });

  @override
  State<ClotureCaisseScreen> createState() => _ClotureCaisseScreenState();
}

class _ClotureCaisseScreenState extends State<ClotureCaisseScreen> {
  late int _digitalRevenue;
  late int _cashRevenue;
  final double _driverCommissionRate = 0.05; // 5%
  final int _coxeurCommission = 2000;         // 2000 FCFA

  bool _isSaved = false;
  CashRegisterSession? _closedSession;

  @override
  void initState() {
    super.initState();
    // Par défaut, estimé à partir des passagers (ex: 5 000 FCFA le billet Dakar-Touba)
    final totalEst = widget.totalPassengers * 5000;
    _digitalRevenue = (totalEst * 0.75).round(); // 75% digital (Wave / OM)
    _cashRevenue = totalEst - _digitalRevenue;   // 25% liquide
  }

  int get _totalRevenue => _digitalRevenue + _cashRevenue;
  int get _driverCommission => (_totalRevenue * _driverCommissionRate).round();
  int get _netCashToDeposit => _cashRevenue - _driverCommission - _coxeurCommission;

  Future<void> _validateCloture() async {
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    final session = CashRegisterSession(
      id: "CLS-${now.millisecondsSinceEpoch}",
      tripId: "TRIP-${now.millisecondsSinceEpoch}",
      busId: widget.busId,
      route: widget.route,
      date: dateStr,
      totalPassengers: widget.totalPassengers,
      digitalRevenue: _digitalRevenue,
      cashRevenue: _cashRevenue,
      driverCommissionRate: _driverCommissionRate,
      coxeurCommission: _coxeurCommission,
      closedAt: now,
      isClosed: true,
    );

    await CashRegisterService.saveSession(session);

    if (mounted) {
      setState(() {
        _isSaved = true;
        _closedSession = session;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clôture de caisse enregistrée avec succès !"),
          backgroundColor: Color(0xFF059669),
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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          "Clôture de Caisse Chauffeur",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau d'en-tête voyage
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.route,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Bus ${widget.busId} • ${widget.totalPassengers} passagers à bord",
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                    ),
                    child: const Text(
                      "FIN DE TRAJET",
                      style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Répartition Recettes Digital vs Espèces
            const Text(
              "Ventilation des Encaissements",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Paiements digitaux
                Expanded(
                  child: _revenueCard(
                    title: "Digital (Wave / OM)",
                    amount: "$_digitalRevenue FCFA",
                    subtitle: "Sécurisé sur Dioufy-TS",
                    color: const Color(0xFF00A3FF),
                    icon: Icons.phonelink_ring,
                  ),
                ),
                const SizedBox(width: 12),
                // Espèces au quai
                Expanded(
                  child: _revenueCard(
                    title: "Espèces (Liquide)",
                    amount: "$_cashRevenue FCFA",
                    subtitle: "Encaissé au quai / bus",
                    color: const Color(0xFFF59E0B),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Total brut
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "TOTAL RECETTES DU VOYAGE",
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$_totalRevenue FCFA",
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const XofCurrencyBadge(size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Détail des commissions déduites
            const Text(
              "Commissions & Rémunérations Instantanées",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                  // Commission Chauffeur
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Commission Chauffeur (5%)",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Crédité sur Portefeuille Virtuel",
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            "+$_driverCommission FCFA",
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_to_mobile, color: Color(0xFFFBBF24), size: 20),
                            tooltip: "Transférer vers Wave / OM",
                            onPressed: _showTransferCommissionDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  // Commission Coxeur / Gare
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Régulation Quai (Coxeur / Gare)",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Forfait départ quai",
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      Text(
                        "-$_coxeurCommission FCFA",
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Solde net à reverser au GIE
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SOLDE NET ESPÈCES À REVERSER AU GIE",
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Montant physique en liquide à remettre au bureau du GIE / Transporteur à l'arrivée (après retenue des commissions).",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$_netCashToDeposit FCFA",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const XofCurrencyBadge(size: 24),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Boutons d'action
            if (!_isSaved)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    "VALIDER LA CLÔTURE DU VOYAGE",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: _validateCloture,
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text(
                    "ENVOYER BORDEREAU SUR WHATSAPP",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: _shareOnWhatsApp,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility, color: Colors.white70, size: 18),
                  label: const Text(
                    "Afficher le bordereau numérique",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  onPressed: () {
                    if (_closedSession != null) {
                      _showReceiptDialog(CashRegisterService.generateReceiptText(_closedSession!));
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _revenueCard({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
