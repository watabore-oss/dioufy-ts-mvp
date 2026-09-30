import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dioufy_ts_mvp/services/auth_service.dart';
import 'package:dioufy_ts_mvp/core/permissions/app_role.dart';
import 'package:dioufy_ts_mvp/core/permissions/app_permission.dart';
import 'package:dioufy_ts_mvp/core/permissions/rbac_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RbacService.instance.initialize();
    await AuthService.instance.initialize();
  });

  group('AuthService & Session Management (Production Architecture)', () {
    test('Default session is guest traveler (without account)', () {
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.isGuest, isTrue);
      expect(AuthService.instance.currentRole, AppRole.passenger);
    });

    test('Continue as guest preserves guest traveler mode and passenger RBAC', () {
      AuthService.instance.continueAsGuest();
      expect(AuthService.instance.isGuest, isTrue);
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.isSuperAdmin, isFalse);
      expect(AuthService.instance.currentRole, AppRole.passenger);
    });

    test('Login with empty credentials fails immediately', () async {
      final success = await AuthService.instance.loginWithCredentials(
        login: '',
        password: '',
      );
      expect(success, isFalse);
      expect(AuthService.instance.lastAuthError, isNotNull);
    });

    test('Local admin bypass and hardcoded passwords do NOT grant login', () async {
      // Vérification que les anciens contournements locaux sont strictement rejetés
      final success = await AuthService.instance.loginWithCredentials(
        login: '774787145',
        password: 'Dioufy2026!',
      );
      // Sans backend Supabase connecté en test unitaire, la connexion locale n'est plus accordée
      expect(success, isFalse);
      expect(AuthService.instance.isLoggedIn, isFalse);
    });

    test('Demo phone numbers do NOT grant roles locally', () async {
      final driverSuccess = await AuthService.instance.loginWithCredentials(
        login: '772345678',
        password: 'Dioufy2026!',
      );
      expect(driverSuccess, isFalse);
      expect(AuthService.instance.currentRole, AppRole.passenger);
    });

    test('OTP SMS test codes 123456 and 2026 are rejected without Supabase validation', () async {
      final verified1 = await AuthService.instance.verifyPhoneOtp(
        phone: '77 469 13 79',
        token: '123456',
      );
      expect(verified1, isFalse);

      final verified2 = await AuthService.instance.verifyPhoneOtp(
        phone: '77 469 13 79',
        token: '2026',
      );
      expect(verified2, isFalse);
      expect(AuthService.instance.isLoggedIn, isFalse);
    });

    test('Reset password with unverified phone OTP is securely rejected', () async {
      final resetOk = await AuthService.instance.resetPasswordWithPhoneOtp(
        phone: '77 469 13 79',
        token: '000000',
        newPassword: 'NouveauPass2026!',
      );
      expect(resetOk, isFalse);
    });

    test('Update password for connected user validates minimum length and backend session', () async {
      final shortPass = await AuthService.instance.updatePassword(newPassword: '123');
      expect(shortPass, isFalse);

      // Sans session active Supabase, le mot de passe ne peut être falsifié
      final unauthenticatedPass = await AuthService.instance.updatePassword(newPassword: 'SolidePass2026!');
      expect(unauthenticatedPass, isFalse);
    });

    test('Logout clears session, clears RBAC and resets to guest passenger', () async {
      await AuthService.instance.logout();
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.isGuest, isTrue);
      expect(AuthService.instance.currentRole, AppRole.passenger);
      expect(
        RbacService.instance.hasPermission(AppPermission.rbacManagePermissions),
        isFalse,
      );
    });

    test('Password recovery state management works reliably', () async {
      expect(AuthService.instance.isPasswordRecovery, isFalse);
      expect(AuthService.instance.passwordRecoveryError, isNull);

      AuthService.instance.setPasswordRecovery(true, error: 'Lien expiré');
      expect(AuthService.instance.isPasswordRecovery, isTrue);
      expect(AuthService.instance.passwordRecoveryError, 'Lien expiré');

      await AuthService.instance.cancelPasswordRecovery();
      expect(AuthService.instance.isPasswordRecovery, isFalse);
      expect(AuthService.instance.passwordRecoveryError, isNull);
    });

    test('Complete password recovery validates minimum length', () async {
      AuthService.instance.setPasswordRecovery(true);
      final shortResult = await AuthService.instance.completePasswordRecovery(newPassword: '123');
      expect(shortResult, isFalse);
      expect(AuthService.instance.lastAuthError, contains('6 caractères'));
      expect(AuthService.instance.isPasswordRecovery, isTrue);
      await AuthService.instance.cancelPasswordRecovery();
    });
  });
}
