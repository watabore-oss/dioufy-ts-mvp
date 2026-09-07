import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';

import '../search/trip.dart';
import '../ticket/ticket_screen.dart';
import '../../services/booking_service.dart';

class PaymentScreen extends StatefulWidget {
  final Trip trip;
  final List<String> seats;
  final List<String> bookingIds;

  const PaymentScreen({
    super.key,
    required this.trip,
    required this.seats,
    required this.bookingIds,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  String _selectedProvider = 'Wave';
  final BookingService _bookingService = BookingService();

  int get _totalAmount => widget.trip.price * widget.seats.length;

  /// Valide un paiement de test/simulation et genere le ticket
  void _completePaymentWithSuccess(String transactionRef) {
    _bookingService.confirmPayment(
      bookingIds: widget.bookingIds,
      provider: _selectedProvider,
      providerRef: transactionRef,
      amount: _totalAmount,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TicketScreen(
          trip: widget.trip,
          seats: widget.seats,
          ref: transactionRef,
          bookingIds: widget.bookingIds,
        ),
      ),
    );
  }

  /// Simulation d'un paiement reussi pour le mode test web et offline
  void _simulateSuccessPayment() {
    setState(() => _processing = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _processing = false);
      final testRef = 'FLW-TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          content: Text('Paiement $_selectedProvider valide avec succes !'),
        ),
      );
      _completePaymentWithSuccess(testRef);
    });
  }

  /// Declenchement du paiement Flutterwave standard
  Future<void> _makePayment(BuildContext context) async {
    // Sur le Web, les navigateurs bloquent Flutterwave sandbox via CORS
    if (kIsWeb) {
      _showWebCorsNotice(context);
      return;
    }

    setState(() => _processing = true);
    try {
      final flutterwave = Flutterwave(
        publicKey: 'FLWPUBK_TEST-dd2bf79db2fba2c407db482f59df4aef-X',
        currency: 'XOF',
        txRef: 'dioufy_${widget.bookingIds.join('-')}_${DateTime.now().millisecondsSinceEpoch}',
        amount: '$_totalAmount',
        customer: Customer(
          name: 'Voyageur Dioufy',
          phoneNumber: '221771234567',
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
      if (!mounted) return;

      if (response.status == 'successful' && response.transactionId != null) {
        _completePaymentWithSuccess(response.transactionId!);
      } else {
        for (var id in widget.bookingIds) {
          await _bookingService.releaseSeat(bookingId: id);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement annule ou refuse')),
        );
      }
    } catch (e) {
      debugPrint('Erreur Flutterwave: $e');
      if (mounted) {
        _showWebCorsNotice(context);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showWebCorsNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
            SizedBox(width: 8),
            Text('Mode Test Web (CORS)'),
          ],
        ),
        content: const Text(
          'Sur navigateur Web (Chrome/Edge), les appels directs a l''API sandbox Flutterwave sont bloques par la securite CORS du navigateur.\n\n'
          'Sur smartphone Android (environnement cible), l''application s''execute en natif sans restriction CORS.\n\n'
          'Voulez-vous valider le paiement en mode test pour visualiser le billet et son QR code signe ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _simulateSuccessPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            child: const Text('Valider en mode test', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Paiement securise'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // Badge montant
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL A REGLER',
                      style: TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_totalAmount XOF',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.trip.company} • ${widget.trip.departure} → ${widget.trip.arrival}',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sieges : ${widget.seats.join(", ")} (${widget.seats.length} place${widget.seats.length > 1 ? 's' : ''})',
                      style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Moyen de paiement :',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // Selection du moyen de paiement
              _providerTile('Wave', 'Paiement sans frais via Wave QR / Push', Icons.qr_code_2),
              const SizedBox(height: 10),
              _providerTile('Orange Money', 'Paiement securise par code d''autorisation OM', Icons.phone_android),
              const SizedBox(height: 10),
              _providerTile('Free Money', 'Paiement rapide Free Money', Icons.account_balance_wallet),

              const SizedBox(height: 30),

              // Bouton Payer
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _processing ? null : () => _makePayment(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'PAYER VIA $_selectedProvider',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Bouton Simulation de test rapide
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _simulateSuccessPayment,
                  icon: const Icon(Icons.flash_on, color: Color(0xFF059669)),
                  label: const Text(
                    'Simuler un paiement reussi (Mode Test)',
                    style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF059669)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerTile(String name, String subtitle, IconData icon) {
    final isSelected = _selectedProvider == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF1E3A8A)),
          ],
        ),
      ),
    );
  }
}
