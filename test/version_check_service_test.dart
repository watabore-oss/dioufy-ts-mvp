import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionCheckService Logic Tests', () {
    test('Instance Singleton is created properly', () {
      final s1 = VersionCheckService.instance;
      final s2 = VersionCheckService.instance;
      expect(identical(s1, s2), isTrue);
      expect(VersionCheckService.currentAppVersion, isNotEmpty);
    });

    test('VersionCheckResult model properties hold expected values', () {
      const result = VersionCheckResult(
        isUpdateRequired: true,
        isUpdateRecommended: false,
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        minimumSupportedVersion: '1.1.0',
        storeUrl: 'https://play.google.com/store/apps/details?id=com.dioufy.transport',
        releaseNotes: 'Mise à jour majeure de sécurité',
      );

      expect(result.isUpdateRequired, isTrue);
      expect(result.isUpdateRecommended, isFalse);
      expect(result.currentVersion, '1.0.0');
      expect(result.latestVersion, '2.0.0');
      expect(result.minimumSupportedVersion, '1.1.0');
      expect(result.storeUrl, contains('google.com'));
      expect(result.releaseNotes, isNotNull);
    });

    test('checkVersion handles offline / uninitialized Supabase client gracefully without throwing', () async {
      // In unit test environment without real Supabase backend connection,
      // checkVersion should catch the error and return null gracefully (fail-open)
      final result = await VersionCheckService.instance.checkVersion();
      // Should not throw an unhandled exception
      expect(result, isNull);
    });
  });
}
