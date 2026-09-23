import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dioufy_ts_mvp/services/payment_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PaymentConfigService.instance.initialize();
  });

  group('PaymentConfigService Gateway Management', () {
    test('Default gateways include Wave Senegal with merchant code 774691379', () {
      final wave = PaymentConfigService.instance.getGateway('wave');
      expect(wave, isNotNull);
      expect(wave!.name, 'Wave Sénégal');
      expect(wave.merchantCode, '774691379');
      expect(wave.isEnabled, isTrue);
    });

    test('Default gateways include PayDunya, Flutterwave, PayTech, OM and Cash', () {
      final gateways = PaymentConfigService.instance.allGateways;
      final ids = gateways.map((g) => g.id).toList();

      expect(ids, contains('wave'));
      expect(ids, contains('paydunya'));
      expect(ids, contains('flutterwave'));
      expect(ids, contains('paytech'));
      expect(ids, contains('orange_money'));
      expect(ids, contains('free_money'));
      expect(ids, contains('cash'));
    });

    test('toggleGateway updates activeGateways list', () async {
      // Désactivation de flutterwave
      await PaymentConfigService.instance.toggleGateway('flutterwave', false);

      final activeIds = PaymentConfigService.instance.activeGateways.map((g) => g.id).toList();
      expect(activeIds, isNot(contains('flutterwave')));

      // Réactivation
      await PaymentConfigService.instance.toggleGateway('flutterwave', true);
      final reActiveIds = PaymentConfigService.instance.activeGateways.map((g) => g.id).toList();
      expect(reActiveIds, contains('flutterwave'));
    });

    test('updateGateway updates merchantCode and technical keys', () async {
      final wave = PaymentConfigService.instance.getGateway('wave')!;
      final updated = wave.copyWith(merchantCode: '774691379_MODIF');

      await PaymentConfigService.instance.updateGateway(updated);

      final reloaded = PaymentConfigService.instance.getGateway('wave')!;
      expect(reloaded.merchantCode, '774691379_MODIF');
    });
  });
}
