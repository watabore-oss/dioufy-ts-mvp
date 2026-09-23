import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/core/scanner/qr_image_decoder.dart';
import 'package:dioufy_ts_mvp/services/scanner/scanner_service.dart';
import 'package:dioufy_ts_mvp/services/ticket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScannerService.instance.startNewSession();
  });

  group('Universal QR Engine & QrImageDecoder Integration Tests', () {
    test('QrImageDecoder returns null gracefully on non-existent or invalid image file', () async {
      final dummyFile = XFile('non_existent_image_path.jpg');
      final result = await QrImageDecoder.decodeImageFile(dummyFile);
      expect(result, isNull);
    });

    test('End-to-End Pipeline: Decoded raw JSON from Gallery/Photo is validated correctly', () async {
      final payload = {
        'ref': 'TICK-UNIVERSAL-77',
        'passenger_name': 'Aminata Fall',
        'seats': ['12'],
        'amount': 9000,
        'trip': {
          'departure': 'Dakar',
          'arrival': 'Saint-Louis',
          'company': 'Dioufy Express',
          'date': '2026-09-20',
          'time': '07:30',
        },
      };

      final qrString = TicketService.encodeTicket(payload);
      
      final result = await ScannerService.instance.validateDirectCode(qrString);
      
      expect(result.isValid, isTrue);
      expect(result.ticketId, equals('TICK-UNIVERSAL-77'));
      expect(result.passengerName, equals('Aminata Fall'));
      expect(result.amount, equals(9000));
      expect(result.seatNumber, equals('12'));
      expect(result.route, equals('Dakar → Saint-Louis'));
    });

    test('End-to-End Pipeline: Rejects tampered signature code from image source', () async {
      final tamperedQr = '{"tId":"TICK-FORGED","ts":1740000000,"sig":"bad_signature_string"}';
      
      final result = await ScannerService.instance.validateDirectCode(tamperedQr);
      
      expect(result.isValid, isFalse);
      expect(result.message, contains('Signature cryptographique invalide'));
    });
  });
}
