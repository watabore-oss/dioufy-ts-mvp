import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dioufy_ts_mvp/core/constants.dart';
import 'package:dioufy_ts_mvp/services/ticket_service.dart';
import 'package:dioufy_ts_mvp/features/search/trip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TicketService Offline & Local Storage', () {
    test('saveTicketLocally saves and retrieves tickets correctly', () async {
      final sampleTicket = {
        'ticketId': 'T-TEST-12345',
        'tripId': 'trip-001',
        'company': 'Dioufy Trans',
        'from': 'Dakar',
        'to': 'Touba',
        'time': '08:00',
        'seats': ['A1', 'A2'],
        'totalPrice': 10000,
        'passengerName': 'Amadou Wade',
        'passengerPhone': '77 123 45 67',
        'status': 'valid',
        'purchasedAt': DateTime.now().toIso8601String(),
      };

      await TicketService.saveTicketLocally(sampleTicket);

      final tickets = await TicketService.getLocalTickets();
      expect(tickets.length, 1);
      expect(tickets.first['ticketId'], 'T-TEST-12345');
      expect(tickets.first['passengerName'], 'Amadou Wade');
      expect(tickets.first['status'], 'valid');
    });

    test('markTicketUsed updates ticket status to used', () async {
      final sampleTicket = {
        'ticketId': 'T-TEST-777',
        'passengerName': 'Fatou Ndiaye',
        'status': 'valid',
      };

      await TicketService.saveTicketLocally(sampleTicket);
      await TicketService.markTicketUsed('T-TEST-777');

      final tickets = await TicketService.getLocalTickets();
      final updated = tickets.firstWhere((t) => t['ticketId'] == 'T-TEST-777');
      expect(updated['status'], 'used');
    });
  });

  group('Trip Model Senegalese Stations & Amenities', () {
    test('Trip defaults provide Dakar Baux Maraîchers and FCFA compatible values', () {
      final trip = Trip(
        id: 'trip-1',
        company: 'Dioufy Trans',
        departure: 'Dakar',
        arrival: 'Thiès',
        time: '07:30',
        price: 3000,
        seatsLeft: 20,
        seatsCount: 40,
        type: 'CONFORT',
      );

      expect(trip.departureStation, 'Gare des Baux Maraîchers');
      expect(trip.currency, AppConstants.currency);
      expect(trip.currency, 'FCFA');
      expect(trip.price, 3000);
      expect(trip.amenities, isNotEmpty);
    });
  });
}
