import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/services/scanner/scanner_service.dart';
import 'package:dioufy_ts_mvp/services/ticket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScannerService.instance.startNewSession();
  });

  group('Validation Directe (Upload Galerie & Clavier) Tests', () {
    test('validateDirectCode valide instantanément un QR code en une seule passe', () async {
      final payload = {
        'ref': 'REF-GALERIE-101',
        'passenger_name': 'Moussa Ndiaye',
        'seats': ['12', '13'],
        'amount': 5000,
        'trip': {
          'departure': 'Dakar',
          'arrival': 'Saint-Louis',
          'company': 'Dioufy Express',
          'date': '2026-09-20',
          'time': '07:30',
        },
      };

      final qrString = TicketService.encodeTicket(payload);

      // Simulation upload galerie : un seul appel immédiat
      final result = await ScannerService.instance.validateDirectCode(qrString);

      expect(result.isValid, isTrue);
      expect(result.isAlreadyUsed, isFalse);
      expect(result.ticketId, equals('REF-GALERIE-101'));
      expect(result.passengerName, equals('Moussa Ndiaye'));
      expect(result.seats, equals('12, 13'));
      expect(result.route, equals('Dakar → Saint-Louis'));
      expect(result.amount, equals(5000));
    });

    test('Détecte un billet déjà composté dans le stockage persistant', () async {
      // 1. Enregistrement d'un billet déjà utilisé
      await TicketService.saveTicketLocally({
        'ref': 'REF-DEJA-UTILISE-99',
        'passenger_name': 'Awa Fall',
        'seats': ['4'],
        'trip': {'departure': 'Dakar', 'arrival': 'Thiès'},
        'status': 'used',
        'used_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      });

      // 2. Scan direct de cette référence
      final result = await ScannerService.instance.validateDirectCode('REF-DEJA-UTILISE-99');

      expect(result.isValid, isFalse);
      expect(result.isAlreadyUsed, isTrue);
      expect(result.passengerName, equals('Awa Fall'));
      expect(result.message, contains('déjà été composté'));
    });

    test('Valide une référence simple enregistrée localement (saisie clavier)', () async {
      await TicketService.saveTicketLocally({
        'ref': 'TICK-CLAVIER-777',
        'passenger_name': 'Ousmane Ba',
        'seats': ['B1'],
        'trip': {'departure': 'Mbour', 'arrival': 'Touba'},
        'amount': 3000,
        'status': 'confirmed',
      });

      final result = await ScannerService.instance.validateDirectCode('TICK-CLAVIER-777');

      expect(result.isValid, isTrue);
      expect(result.ticketId, equals('TICK-CLAVIER-777'));
      expect(result.passengerName, equals('Ousmane Ba'));
      expect(result.seats, equals('B1'));
      expect(result.route, equals('Mbour → Touba'));
      expect(result.amount, equals(3000));
    });

    test('Rejette un faux QR code falsifié ou avec fausse signature', () async {
      final fakeQr = '{"payload":{"ref":"FAKE-999","passenger_name":"Hacker"},"signature":"invalide"}';

      final result = await ScannerService.instance.validateDirectCode(fakeQr);

      expect(result.isValid, isFalse);
      expect(result.isForged, isTrue);
    });

    test('Rejette un code vide proprement', () async {
      final result = await ScannerService.instance.validateDirectCode('   ');
      expect(result.isValid, isFalse);
    });
  });
}
