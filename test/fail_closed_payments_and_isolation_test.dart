import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/services/trip_service.dart';
import 'package:dioufy_ts_mvp/services/booking_service.dart';
import 'package:dioufy_ts_mvp/services/kpi_service.dart';

void main() {
  group('P0 Fail-Closed Architecture & Security Verification', () {
    test('TripService propage les exceptions sans masquer les erreurs par du cache mémoire périmé', () async {
      final tripService = TripService();
      expect(
        () async => await tripService.searchTrips(
          departure: 'Dakar',
          destination: 'Saint-Louis',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('BookingService.checkBookingPaidStatus retourne false sans exception si client non initialisé', () async {
      final bookingService = BookingService();
      final isPaid = await bookingService.checkBookingPaidStatus(['00000000-0000-0000-0000-000000000001']);
      expect(isPaid, isFalse);
    });

    test('BookingService.checkBookingPaidStatus filtre les IDs invalides et retourne false', () async {
      final bookingService = BookingService();
      final isPaid = await bookingService.checkBookingPaidStatus(['invalid-id-not-uuid']);
      expect(isPaid, isFalse);
    });

    test('KpiService signale hasErrors: true de manière transparente en mode offline/non initialisé', () async {
      final kpiService = KpiService.instance;
      final report = await kpiService.fetchPlatformKpis(organizationId: 'gie-test-123');
      expect(report.hasErrors, isTrue);
      expect(report.totalRevenueCollected, 0);
    });
  });
}
