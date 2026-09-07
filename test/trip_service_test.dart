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

  group('TripService', () {
    test('searchTrips returns matching routes for Dakar to Thiès', () async {
      final service = TripService();
      final trips = await service.searchTrips(
        departure: 'Dakar',
        destination: 'Thiès',
      );

      expect(trips.isNotEmpty, isTrue);
      for (var trip in trips) {
        expect(trip.departure.toLowerCase(), contains('dakar'));
        expect(trip.arrival.toLowerCase(), contains('thies'));
      }
    });

    test('searchTrips returns matching routes for Dakar to Touba', () async {
      final service = TripService();
      final trips = await service.searchTrips(
        departure: 'Dakar',
        destination: 'Touba',
      );

      expect(trips.isNotEmpty, isTrue);
      for (var trip in trips) {
        expect(trip.departure.toLowerCase(), contains('dakar'));
        expect(trip.arrival.toLowerCase(), contains('touba'));
      }
    });
  });

  group('BookingService', () {
    test('getOccupiedSeats returns non-empty list for trips', () async {
      final service = BookingService();
      final seats = await service.getOccupiedSeats('t1');
      expect(seats, isNotEmpty);
    });

    test('lockSeatsBatch locks seats and returns IDs', () async {
      final service = BookingService();
      final bookingIds = await service.lockSeatsBatch(
        tripId: 't1',
        seatNumbers: ['B1', 'B2'],
      );
      expect(bookingIds.length, 2);
    });
  });
}
