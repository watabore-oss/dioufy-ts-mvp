import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/trip.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final bookingReference = 'DTS-${trip.id}-001';

    return Scaffold(
      appBar: AppBar(title: const Text('Réservation')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 72,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pré-réservation confirmée',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Présente ce QR code au guichet partenaire pour finaliser le paiement et embarquer.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  QrImageView(
                    data: bookingReference,
                    version: QrVersions.auto,
                    size: 180,
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    bookingReference,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: const Icon(Icons.route),
            title: Text('${trip.departureCity} → ${trip.arrivalCity}'),
            subtitle: Text(trip.operatorName),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(trip.priceLabel),
            subtitle: const Text('Paiement mobile money à brancher'),
          ),
        ],
      ),
    );
  }
}
