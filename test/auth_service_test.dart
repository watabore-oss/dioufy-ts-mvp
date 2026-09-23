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

  group('AuthService & Session Management', () {
    test('Default session is guest traveler (without account)', () {
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.isGuest, isTrue);
      expect(AuthService.instance.currentRole, AppRole.passenger);
    });

    test('Continue as guest preserves guest traveler mode', () {
      AuthService.instance.continueAsGuest();
      expect(AuthService.instance.isGuest, isTrue);
      expect(AuthService.instance.isSuperAdmin, isFalse);
    });

    test('Login as Super Admin dev role synchronizes RBAC and grants sovereign rights', () async {
      final success = await AuthService.instance.loginAsDevRole(AppRole.superAdmin);
      expect(success, isTrue);
      expect(AuthService.instance.isLoggedIn, isTrue);
      expect(AuthService.instance.isSuperAdmin, isTrue);
      expect(AuthService.instance.currentRole, AppRole.superAdmin);

      // Vérifie la synchronisation immédiate avec RbacService
      expect(RbacService.instance.currentRole, AppRole.superAdmin);
      expect(
        RbacService.instance.hasPermission(AppPermission.rbacManagePermissions),
        isTrue,
      );
      expect(
        RbacService.instance.hasPermission(AppPermission.rbacManageSuperAdmins),
        isTrue,
      );
    });

    test('Login as Driver role synchronizes RBAC for chauffeur operations', () async {
      final success = await AuthService.instance.loginAsDevRole(AppRole.driver);
      expect(success, isTrue);
      expect(AuthService.instance.currentRole, AppRole.driver);
      expect(AuthService.instance.isSuperAdmin, isFalse);

      // Chauffeur a le droit de voir ses véhicules et de clôturer sa caisse
      expect(
        RbacService.instance.hasPermission(AppPermission.fleetViewVehicles),
        isTrue,
      );
      expect(
        RbacService.instance.hasPermission(AppPermission.cashCloseSession),
        isTrue,
      );

      // Mais n a PAS le droit d administrer le RBAC
      expect(
        RbacService.instance.hasPermission(AppPermission.rbacManagePermissions),
        isFalse,
      );
    });

    test('Logout clears session and resets to guest passenger', () async {
      await AuthService.instance.loginAsDevRole(AppRole.superAdmin);
      expect(AuthService.instance.isSuperAdmin, isTrue);

      await AuthService.instance.logout();
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(AuthService.instance.isGuest, isTrue);
      expect(AuthService.instance.currentRole, AppRole.passenger);
      expect(
        RbacService.instance.hasPermission(AppPermission.rbacManagePermissions),
        isFalse,
      );
    });

    test('Phone OTP login flow (+221 Senegal) authenticates passenger', () async {
      final sent = await AuthService.instance.signInWithPhoneOtp(phone: '77 469 13 79');
      expect(sent, isTrue);

      final verified = await AuthService.instance.verifyPhoneOtp(
        phone: '77 469 13 79',
        token: '123456',
      );
      expect(verified, isTrue);
      expect(AuthService.instance.isLoggedIn, isTrue);
      expect(AuthService.instance.currentUser.phone, '+221774691379');
    });

    test('Reset password with unverified phone OTP is securely rejected', () async {
      final resetOk = await AuthService.instance.resetPasswordWithPhoneOtp(
        phone: '77 469 13 79',
        token: '000000',
        newPassword: 'NouveauPass2026!',
      );
      // Règle de sécurité stricte : sans validation serveur cryptographique, tout OTP arbitraire est rejeté
      expect(resetOk, isFalse);
    });

    test('Update password for connected user validates minimum length and backend session', () async {
      final shortPass = await AuthService.instance.updatePassword(newPassword: '123');
      expect(shortPass, isFalse);

      // Sans session active Supabase connectée, le mot de passe ne peut être falsifié
      final unauthenticatedPass = await AuthService.instance.updatePassword(newPassword: 'SolidePass2026!');
      expect(unauthenticatedPass, isFalse);
    });

    test('Dev login covers all 8 Dioufy-TS roles seamlessly', () async {
      final allRoles = [
        AppRole.superAdmin,
        AppRole.platformAdmin,
        AppRole.gieAdmin,
        AppRole.gieAgent,
        AppRole.driver,
        AppRole.coxeur,
        AppRole.mechanic,
        AppRole.passenger,
      ];

      for (final role in allRoles) {
        final ok = await AuthService.instance.loginAsDevRole(role);
        expect(ok, isTrue);
        expect(AuthService.instance.currentRole, role);
      }
    });
  });
}
