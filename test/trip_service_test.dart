import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/features/search/trip.dart';
import 'package:dioufy_ts_mvp/services/trip_service.dart';
import 'package:dioufy_ts_mvp/services/booking_service.dart';

void main() {
  group('Trip Model & Mapping', () {
    test('Trip.fromMap parses Supabase response correctly', () {
      final sampleRow = {
        'id': 'trip-123',
        'from_loc': 'Dakar',
        'to_loc': 'Thiès',
        'depart_at': '2026-09-07T08:30:00Z',
        'price': 7500,
        'seats_count': 36,
        'metadata': {'type': 'CONFORT'},
        'agencies': {'name': 'Dioufy Trans'},
        'seats': [
          {'seat_number': 'A1', 'status': 'occupied'},
          {'seat_number': 'A2', 'status': 'locked', 'lock_until': '2099-01-01T00:00:00Z'},
          {'seat_number': 'A3', 'status': 'available'},
        ],
      };

      final trip = Trip.fromMap(sampleRow);

      expect(trip.id, 'trip-123');
      expect(trip.company, 'Dioufy Trans');
      expect(trip.departure, 'Dakar');
      expect(trip.arrival, 'Thiès');
      expect(trip.price, 7500);
      expect(trip.type, 'CONFORT');
      expect(trip.seatsCount, 36);
      // 36 total - 2 occupied/locked = 34
      expect(trip.seatsLeft, 34);
    });
  });

  group('TripService (Supabase Source Unique de Vérité)', () {
    test('searchTrips lève une exception explicite si Supabase est indisponible (aucun mock en production)', () async {
      final service = TripService();
      // Sans instance Supabase connectée, le service doit lever une exception explicite et non retourner de faux trajets
      expect(
        () async => await service.searchTrips(
          departure: 'Dakar',
          destination: 'Thiès',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('BookingService (Sécurisation des Réservations)', () {
    test('lockSeatsBatch rejette les identifiants invalides non UUID', () async {
      final service = BookingService();
      expect(
        () async => await service.lockSeatsBatch(
          tripId: 'invalid-id-not-uuid',
          seatNumbers: ['B1', 'B2'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getOccupiedSeats lève une exception explicite si Supabase n est pas disponible (fail-closed)', () async {
      final service = BookingService();
      expect(
        () async => await service.getOccupiedSeats('00000000-0000-0000-0000-000000000001'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
