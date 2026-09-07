import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';

import '../search/trip.dart';
import '../ticket/ticket_screen.dart';
import '../../services/booking_service.dart';

class PaymentScreen extends StatefulWidget {
  final Trip trip;
  final List<String> seats;
  final List<String> bookingIds; // un id par siège verrouillé

  const PaymentScreen({
    super.key,
    required this.trip,
    required this.seats,
    required this.bookingIds,
  });

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  final BookingService _bookingService = BookingService();

  Future<void> _makePayment(BuildContext context) async {
    setState(() => _processing = true);
    try {
      final flutterwave = Flutterwave(
        publicKey:
            'FLWPUBK_TEST-dd2bf79db2fba2c407db482f59df4aef-X', // clé publique test fournie
        currency: 'XOF',
        txRef:
            'dioufy_${widget.bookingIds.join('-')}_${DateTime.now().millisecondsSinceEpoch}',
        amount: '${widget.trip.price * widget.seats.length}',
        customer: Customer(
          name: 'Utilisateur Dioufy',
          phoneNumber: '221771234567',
          email: 'test@dioufy.sn',
        ),
        paymentOptions: 'mobilemoney',
        customization: Customization(
          title: 'Dioufy-TS',
          description: 'Paiement billet transport',
        ),
        redirectUrl: 'https://example.com/payment-callback',
        isTestMode: true,
      );

      final response = await flutterwave.charge(context);
      if (!mounted) return;

      if (response.status == 'successful' && response.transactionId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TicketScreen(
              trip: widget.trip,
              seats: widget.seats,
              ref: response.transactionId!,
              bookingIds: widget.bookingIds,
            ),
          ),
        );
      } else {
        for (var id in widget.bookingIds) {
          await _bookingService.releaseSeat(bookingId: id);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement annulé ou échoué (test)')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payment, size: 100, color: Color(0xFF059669)),
            const SizedBox(height: 30),
            Text(
              '${widget.trip.price * widget.seats.length} XOF',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
            ),
            const Text('Wave - Orange Money - Free Money',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _processing ? null : () => _makePayment(context),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                backgroundColor: const Color(0xFF0F172A),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('PAYER MAINTENANT',
                      style: TextStyle(fontSize: 22, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
