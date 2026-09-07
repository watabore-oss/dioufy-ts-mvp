import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../search/trip.dart';
import '../../services/ticket_service.dart';

class TicketScreen extends StatelessWidget {
  final Trip trip;
  final List<String> seats;
  final String ref;
  final List<String>? bookingIds;

  const TicketScreen({
    super.key,
    required this.trip,
    required this.seats,
    required this.ref,
    this.bookingIds,
  });

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
        title: const Text('Ticket'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trip.departure} -> ${trip.arrival}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 8),
            Text('${trip.company} - ${trip.time}'),
            const SizedBox(height: 8),
            Text('Sieges: ${seats.join(', ')}'),
            const SizedBox(height: 8),
            Text('Reference paiement: $ref'),
            if (bookingIds != null) ...[
              const SizedBox(height: 8),
              Text('Réservations: ${bookingIds!.join(', ')}',
                  style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 24),
            // QR code du ticket
            Center(
              child: QrImageView(
                data: TicketService.encodeTicket({
                  'trip': {
                    'departure': trip.departure,
                    'arrival': trip.arrival,
                    'time': trip.time,
                    'company': trip.company,
                  },
                  'seats': seats,
                  'ref': ref,
                  'bookingIds': bookingIds,
                }),
                size: 200.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
