import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/services/scanner/scan_session.dart';
import 'package:dioufy_ts_mvp/services/scanner/scan_stabilizer.dart';
import 'package:dioufy_ts_mvp/services/scanner/ticket_verifier.dart';
import 'package:dioufy_ts_mvp/services/ticket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScanSession Tests', () {
    test('ScanSession tracks processed tickets and prevents duplicates', () {
      final session = ScanSession();
      expect(session.isProcessed('TICK-001'), isFalse);
      expect(session.processedCount, equals(0));

      final added = session.registerProcessed('TICK-001');
      expect(added, isTrue);
      expect(session.isProcessed('TICK-001'), isTrue);
      expect(session.processedCount, equals(1));

      // Tentative d'ajout du même billet
      final addedAgain = session.registerProcessed('TICK-001');
      expect(addedAgain, isFalse);
      expect(session.processedCount, equals(1));
    });

    test('ScanSession expiration calculation', () {
      final session = ScanSession(
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        timeout: const Duration(minutes: 60),
      );
      expect(session.isExpired, isTrue);
    });
  });

  group('ScanStabilizer Tests', () {
    test('Requires configured consecutive matches before confirming', () async {
      final stabilizer = ScanStabilizer(
        requiredConsecutiveMatches: 3,
        minFrameInterval: const Duration(milliseconds: 10),
        postScanCooldown: const Duration(milliseconds: 500),
      );

      // Frame 1
      expect(stabilizer.processFrame('QR_VALUE_A'), isNull);
      expect(stabilizer.candidateMatches, equals(1));

      await Future.delayed(const Duration(milliseconds: 15));
      // Frame 2 (même valeur)
      expect(stabilizer.processFrame('QR_VALUE_A'), isNull);
      expect(stabilizer.candidateMatches, equals(2));

      await Future.delayed(const Duration(milliseconds: 15));
      // Frame 3 (seuil de 3 atteint !)
      final confirmed = stabilizer.processFrame('QR_VALUE_A');
      expect(confirmed, equals('QR_VALUE_A'));
    });

    test('Resets candidate if a different value is encountered', () async {
      final stabilizer = ScanStabilizer(
        requiredConsecutiveMatches: 3,
        minFrameInterval: const Duration(milliseconds: 10),
      );

      stabilizer.processFrame('QR_VALUE_A');
      await Future.delayed(const Duration(milliseconds: 15));
      stabilizer.processFrame('QR_VALUE_A');

      await Future.delayed(const Duration(milliseconds: 15));
      // Valeur différente
      stabilizer.processFrame('QR_VALUE_B');
      expect(stabilizer.candidateMatches, equals(1));
    });

    test('Post-scan cooldown blocks rapid bursts', () async {
      final stabilizer = ScanStabilizer(
        requiredConsecutiveMatches: 1,
        minFrameInterval: Duration.zero,
        postScanCooldown: const Duration(milliseconds: 300),
      );

      final first = stabilizer.processFrame('QR_BURST');
      expect(first, equals('QR_BURST'));

      // Immédiatement après : doit retourner null à cause du cooldown
      final burst = stabilizer.processFrame('QR_BURST');
      expect(burst, isNull);
    });
  });

  group('TicketVerifier Cryptographic & Business Tests', () {
    test('Validates authentic HMAC signed ticket successfully', () async {
      final session = ScanSession();
      final payload = {
        'ticketId': 'TICK-DK-THIES-901',
        'passengerName': 'Amadou Diallo',
        'seatNumber': '14',
        'departure': 'Dakar',
        'destination': 'Thiès',
        'price': 2500,
      };

      final signedQrText = TicketService.encodeTicket(payload);

      final result = await TicketVerifier.verifyAndProcessTicket(
        rawValue: signedQrText,
        session: session,
      );

      expect(result.isValid, isTrue);
      expect(result.isAlreadyUsed, isFalse);
      expect(result.ticketId, equals('TICK-DK-THIES-901'));
      expect(result.passengerName, equals('Amadou Diallo'));
      expect(result.seatNumber, equals('14'));
      expect(session.isProcessed('TICK-DK-THIES-901'), isTrue);
    });

    test('Rejects ticket with forged or invalid HMAC signature', () async {
      final session = ScanSession();
      final forgedQrText = '{\"payload\":{\"ticketId\":\"FAKE-01\"},\"signature\":\"fake_bad_signature\"}';

      final result = await TicketVerifier.verifyAndProcessTicket(
        rawValue: forgedQrText,
        session: session,
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('HMAC'));
    });

    test('Detects duplicate scan in same session', () async {
      final session = ScanSession();
      final payload = {'ticketId': 'TICK-DUP-01', 'passenger': 'Fatou Sow'};
      final qrText = TicketService.encodeTicket(payload);

      // Premier scan : validé
      final res1 = await TicketVerifier.verifyAndProcessTicket(
        rawValue: qrText,
        session: session,
      );
      expect(res1.isValid, isTrue);

      // Second scan du même billet : rejet pour doublon
      final res2 = await TicketVerifier.verifyAndProcessTicket(
        rawValue: qrText,
        session: session,
      );
      expect(res2.isValid, isFalse);
      expect(res2.isAlreadyUsed, isTrue);
    });
  });
}
