// ignore_for_file: deprecated_member_use
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../core/widgets/transaction_summary_pane.dart';
import '../../services/booking_service.dart';
import '../../services/ticket_service.dart';
import '../../services/payment_config_service.dart';
import '../search/trip.dart';
import '../ticket/ticket_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Trip trip;
  final List<String> seats;
  final List<String> bookingIds;
  final String passengerName;
  final String? passengerPhone;

  const PaymentScreen({
    super.key,
    required this.trip,
    required this.seats,
    required this.bookingIds,
    required this.passengerName,
    this.passengerPhone,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  String _selectedGatewayId = 'wave';
  final BookingService _bookingService = BookingService();

  int get _totalAmount => widget.trip.price * widget.seats.length;

  /// Valide un paiement et persiste le billet en local avant d'afficher la carte d'embarquement
  void _completePaymentWithSuccess(String transactionRef) {
    final gateway = PaymentConfigService.instance.getGateway(_selectedGatewayId);
    final providerName = gateway?.name ?? 'Paiement Sécurisé';

    // 1. Sauvegarde locale du billet (accès hors-ligne garanti)
    TicketService.saveTicketLocally({
      'ref': transactionRef,
      'trip': widget.trip.toMap(),
      'seats': widget.seats,
      'passenger_name': widget.passengerName,
      'passenger_phone': widget.passengerPhone,
      'bookingIds': widget.bookingIds,
      'amount': _totalAmount,
      'provider': providerName,
      'status': 'confirmed',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Confirmation en arrière-plan dans Supabase (idempotente)
    _bookingService.confirmPayment(
      bookingIds: widget.bookingIds,
      provider: providerName,
      providerRef: transactionRef,
      amount: _totalAmount,
    );

    // 3. Affichage du Billet / Carte d'embarquement
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TicketScreen(
          trip: widget.trip,
          seats: widget.seats,
          ref: transactionRef,
          bookingIds: widget.bookingIds,
          passengerName: widget.passengerName,
          passengerPhone: widget.passengerPhone,
        ),
      ),
    );
  }

  /// Vérifie si les réservations ont été marquées comme payées sur le serveur central
  Future<bool> _checkIfBookingsPaid() async {
    try {
      final client = Supabase.instance.client;
      final realIds = widget.bookingIds
          .where((id) => !id.startsWith('local_') && !id.startsWith('demo-'))
          .toList();

      if (realIds.isEmpty) return false;

      final response = await client
          .from('bookings')
          .select('id, status')
          .inFilter('id', realIds)
          .timeout(const Duration(seconds: 4));

      final list = response as List;
      if (list.isEmpty) return false;
      return list.every((item) => item['status'] == 'paid');
    } catch (e) {
      debugPrint('[PaymentScreen] Vérification statut réservation: $e');
      return false;
    }
  }

  /// Vérifie le paiement réel Wave auprès du serveur avant d'autoriser l'émission du billet
  void _verifyAndProcessWavePayment(BuildContext context) async {
    setState(() => _processing = true);

    final isPaid = await _checkIfBookingsPaid();

    if (!mounted) return;
    setState(() => _processing = false);
    if (!context.mounted) return;

    if (isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Paiement vérifié et validé avec succès par le serveur !'),
        ),
      );
      final ref = 'WAVE-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _completePaymentWithSuccess(ref);
    } else {
      _showPendingPaymentDialog(context);
    }
  }

  void _showPendingPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFF00B2FE)),
            SizedBox(width: 10),
            Text('Paiement en attente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aucune confirmation bancaire reçue pour le moment.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Si vous venez d\'effectuer le transfert sur le compte Wave marchand 774691379, veuillez patienter quelques secondes puis actualiser la vérification.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Réservations : ${widget.bookingIds.join(", ")}\nMontant : $_totalAmount FCFA',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyAndProcessWavePayment(context);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Vérifier à nouveau'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B2FE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Déclenchement du paiement selon la passerelle sélectionnée
  Future<void> _makePayment(BuildContext context) async {
    final gateway = PaymentConfigService.instance.getGateway(_selectedGatewayId);

    // 1. Paiement Wave Sénégal officiel
    if (_selectedGatewayId == 'wave') {
      _showWavePaymentModal(context, gateway);
      return;
    }

    // 2. Flutterwave
    if (_selectedGatewayId == 'flutterwave') {
      if (kIsWeb) {
        _showTestValidationDialog(context, gateway?.name ?? 'Flutterwave');
        return;
      }
      _triggerFlutterwave(context);
      return;
    }

    // 3. Autres passerelles (PayDunya, PayTech, Orange Money, Free Money, Cash)
    _showTestValidationDialog(context, gateway?.name ?? 'Paiement');
  }

  void _showWavePaymentModal(BuildContext context, PaymentGatewayConfig? waveConfig) {
    final merchantNum = waveConfig?.merchantCode ?? '774691379';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, color: Color(0xFF00B2FE), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Paiement Wave Sénégal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Montant : $_totalAmount FCFA',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
              ),
              const SizedBox(height: 14),

              // Affiche le poster officiel Wave du marchand
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xFF00B2FE).withValues(alpha: 0.06),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/wave_merchant_qr.jpg',
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(Icons.qr_code_scanner, size: 80, color: Color(0xFF00B2FE)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Code Marchand : ', style: TextStyle(fontSize: 13, color: Colors.black54)),
                          Text(
                            merchantNum,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00B2FE)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Scannez le QR code avec votre application Wave ou confirmez votre règlement ci-dessous.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _verifyAndProcessWavePayment(context);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('J AI EFFECTUÉ LE PAIEMENT WAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B2FE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showTestValidationDialog(BuildContext context, String providerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 8),
            Text('Vérification $providerName'),
          ],
        ),
        content: Text(
          'Vérifier auprès du serveur la confirmation de votre paiement de $_totalAmount FCFA via $providerName pour émettre votre billet ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyAndProcessWavePayment(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Vérifier Statut Réel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerFlutterwave(BuildContext context) async {
    final flwGateway = PaymentConfigService.instance.getGateway('flutterwave');
    final publicKey = (flwGateway?.apiKey != null && flwGateway!.apiKey!.isNotEmpty)
        ? flwGateway.apiKey!
        : const String.fromEnvironment('FLW_PUBLIC_KEY', defaultValue: '');

    if (publicKey.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Configuration Flutterwave non définie. Veuillez choisir Wave Sénégal.'),
        ),
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final flutterwave = Flutterwave(
        publicKey: publicKey,
        currency: 'XOF',
        txRef: 'dioufy_${widget.bookingIds.join(',')}_${DateTime.now().millisecondsSinceEpoch}',
        amount: '$_totalAmount',
        customer: Customer(
          name: widget.passengerName,
          phoneNumber: widget.passengerPhone ?? '221774691379',
          email: 'passager@dioufy.sn',
        ),
        paymentOptions: 'mobilemoney',
        customization: Customization(
          title: 'Dioufy-TS',
          description: 'Paiement billet de transport (${widget.trip.company})',
        ),
        redirectUrl: 'https://example.com/payment-callback',
        isTestMode: true,
      );

      final response = await flutterwave.charge(context);
      if (!context.mounted) return;

      if (response.status == 'successful' && response.transactionId != null) {
        // Attente de propagation du webhook Flutterwave
        await Future.delayed(const Duration(milliseconds: 1500));
        final isPaid = await _checkIfBookingsPaid();
        if (!context.mounted) return;
        if (isPaid) {
          _completePaymentWithSuccess(response.transactionId!);
        } else {
          _showPendingPaymentDialog(context);
        }
      } else {
        for (var id in widget.bookingIds) {
          await _bookingService.releaseSeat(bookingId: id);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement annulé ou refusé.')),
        );
      }
    } catch (e) {
      debugPrint('[PaymentScreen] Erreur Flutterwave: $e');
      if (context.mounted) {
        _showPendingPaymentDialog(context);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopSplitScaffold(
      title: 'Paiement Sécurisé',
      subtitle: '${widget.trip.company} • ${widget.trip.departure} → ${widget.trip.arrival}',
      showBackButton: true,
      rightPane: TransactionSummaryPane(
        trip: widget.trip,
        selectedSeats: widget.seats,
        totalAmount: _totalAmount,
        passengerName: widget.passengerName,
        passengerPhone: widget.passengerPhone,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte Récapitulative Lumineuse et Aérée
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DioufyRadius.lgAll,
                border: Border.all(color: DioufyColors.border, width: 1.2),
                boxShadow: DioufyShadows.card,
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL À RÉGLER',
                    style: TextStyle(
                      fontFamily: DioufyTypography.fontFamily,
                      color: DioufyColors.textSecondary,
                      fontSize: 12.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_totalAmount FCFA',
                        style: const TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          fontSize: 32,
                          fontWeight: DioufyTypography.black,
                          color: DioufyColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const XofCurrencyBadge(size: 24),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: DioufyColors.surfaceSoft),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sièges : ${widget.seats.join(", ")}',
                        style: const TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: DioufyColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Voyageur : ${widget.passengerName}',
                        style: const TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: DioufyColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Choisissez votre moyen de paiement :',
              style: TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                fontSize: 16,
                fontWeight: DioufyTypography.bold,
                color: DioufyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Liste dynamique des passerelles actives configurées par le Super Admin
            AnimatedBuilder(
              animation: PaymentConfigService.instance,
              builder: (context, _) {
                final activeGateways = PaymentConfigService.instance.activeGateways;

                if (activeGateways.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune passerelle de paiement active.'),
                    ),
                  );
                }

                if (!activeGateways.any((g) => g.id == _selectedGatewayId)) {
                  _selectedGatewayId = activeGateways.first.id;
                }

                return Column(
                  children: activeGateways.map((g) {
                    final isSelected = _selectedGatewayId == g.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: DioufyRadius.mdAll,
                        border: Border.all(
                          color: isSelected ? DioufyColors.primary : DioufyColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? DioufyShadows.card : null,
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: g.brandColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(g.iconData, color: g.brandColor, size: 22),
                        ),
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              g.name,
                              style: const TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (g.id == 'wave')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B2FE).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Recommandé',
                                  style: TextStyle(
                                    fontFamily: DioufyTypography.fontFamily,
                                    color: Color(0xFF00B2FE),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          g.description,
                          style: const TextStyle(
                            fontFamily: DioufyTypography.fontFamily,
                            fontSize: 13,
                            color: DioufyColors.textSecondary,
                          ),
                        ),
                        trailing: Radio<String>(
                          value: g.id,
                          groupValue: _selectedGatewayId,
                          activeColor: DioufyColors.primary,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedGatewayId = val);
                          },
                        ),
                        onTap: () => setState(() => _selectedGatewayId = g.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Bouton Principal Payer
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _processing ? null : () => _makePayment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DioufyColors.emerald,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'VALIDER ET PAYER $_totalAmount FCFA',
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
