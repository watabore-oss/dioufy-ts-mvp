import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dioufy_ts_mvp/services/cash_register_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CashRegisterSession Financial Math', () {
    test('Calculates total revenue, commissions, and net cash to deposit correctly', () {
      final session = CashRegisterSession(
        id: 'CLS-001',
        tripId: 'TRIP-001',
        busId: 'DK-882-SN',
        route: 'Dakar → Touba',
        date: '07/09/2026',
        totalPassengers: 35,
        digitalRevenue: 131250, // 75% digital
        cashRevenue: 43750,     // 25% espèces
        driverCommissionRate: 0.05,
        coxeurCommission: 2000,
        closedAt: DateTime(2026, 9, 7, 18, 30),
      );

      // Total recettes
      expect(session.totalRevenue, 175000);

      // Commission chauffeur 5% de 175 000 = 8 750 FCFA
      expect(session.driverCommission, 8750);

      // Solde net espèces à reverser au GIE = 43 750 - 8 750 - 2 000 = 33 000 FCFA
      expect(session.netCashToDeposit, 33000);
    });

    test('generateReceiptText produces complete formatted statement for WhatsApp', () {
      final session = CashRegisterSession(
        id: 'CLS-002',
        tripId: 'TRIP-002',
        busId: 'DK-882-SN',
        route: 'Dakar → Touba',
        date: '07/09/2026',
        totalPassengers: 40,
        digitalRevenue: 150000,
        cashRevenue: 50000,
        closedAt: DateTime(2026, 9, 7, 20, 0),
      );

      final text = CashRegisterService.generateReceiptText(session);

      expect(text, contains('DIOUFY-TS • BORDEREAU DE CLÔTURE DE CAISSE'));
      expect(text, contains('Dakar → Touba'));
      expect(text, contains('DK-882-SN'));
      expect(text, contains('200000 FCFA')); // Total recettes
      expect(text, contains('10000 FCFA'));  // Commission chauffeur 5%
      expect(text, contains('38000 FCFA'));  // Solde net espèces
    });
  });

  group('CashRegisterService Persistence', () {
    test('saveSession and getSessionHistory persist and retrieve sessions', () async {
      final session = CashRegisterSession(
        id: 'CLS-123',
        tripId: 'TRIP-123',
        route: 'Dakar → Thiès',
        date: '07/09/2026',
        totalPassengers: 25,
        digitalRevenue: 50000,
        cashRevenue: 25000,
        closedAt: DateTime.now(),
      );

      await CashRegisterService.saveSession(session);

      final history = await CashRegisterService.getSessionHistory();
      expect(history.length, 1);
      expect(history.first.id, 'CLS-123');
      expect(history.first.route, 'Dakar → Thiès');
      expect(history.first.totalRevenue, 75000);
    });
  });
}
