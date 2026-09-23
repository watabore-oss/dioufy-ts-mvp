import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/core/permissions/app_role.dart';
import 'package:dioufy_ts_mvp/core/permissions/app_permission.dart';
import 'package:dioufy_ts_mvp/core/permissions/rbac_context.dart';
import 'package:dioufy_ts_mvp/core/permissions/rbac_service.dart';
import 'package:dioufy_ts_mvp/app/feature_flags/feature_flag_state.dart';
import 'package:dioufy_ts_mvp/app/feature_flags/feature_flag_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('RBAC Contextual Authorization & Domain Boundaries', () {
    test('Roles have correct hierarchy levels and system locked flags', () {
      expect(AppRole.superAdmin.level, 0);
      expect(AppRole.platformAdmin.level, 1);
      expect(AppRole.gieAdmin.level, 2);
      expect(AppRole.driver.level, 3);
      expect(AppRole.coxeur.level, 3);
      expect(AppRole.mechanic.level, 3);
      expect(AppRole.passenger.level, 4);

      for (final role in AppRole.values) {
        expect(role.isSystemLocked, isTrue);
      }
    });

    test('Same level roles (Driver vs Coxeur) have strictly partitioned permissions', () {
      final driverPerms = AppPermission.getDefaultPermissions(AppRole.driver);
      final coxeurPerms = AppPermission.getDefaultPermissions(AppRole.coxeur);

      // Le Chauffeur a la clôture de caisse mais pas le scan caméra
      expect(driverPerms.contains(AppPermission.cashCloseSession), isTrue);
      expect(driverPerms.contains(AppPermission.ticketingScanCamera), isFalse);

      // Le Coxeur a le scan caméra mais pas la clôture de caisse
      expect(coxeurPerms.contains(AppPermission.ticketingScanCamera), isTrue);
      expect(coxeurPerms.contains(AppPermission.cashCloseSession), isFalse);
    });

    test('Multi-tenancy isolation: GIE Admin restricted to own organization', () {
      final rbac = RbacService.instance;
      rbac.switchRoleForTesting(AppRole.gieAdmin, organizationId: 'gie_thies');

      // Autorisé sur son propre GIE
      expect(
        rbac.hasPermission(
          AppPermission.bookingManageTrips,
          targetOrganizationId: 'gie_thies',
        ),
        isTrue,
      );

      // Rejeté sur un autre GIE concurrent
      expect(
        rbac.hasPermission(
          AppPermission.bookingManageTrips,
          targetOrganizationId: 'gie_ndiambour',
        ),
        isFalse,
      );
    });

    test('Super Admin has global scope across all organizations and modules', () {
      final rbac = RbacService.instance;
      rbac.switchRoleForTesting(AppRole.superAdmin);

      expect(
        rbac.hasPermission(
          AppPermission.bookingManageTrips,
          targetOrganizationId: 'gie_any_arbitrary',
        ),
        isTrue,
      );
      expect(
        rbac.hasPermission(AppPermission.rbacManagePermissions),
        isTrue,
      );
      expect(
        rbac.hasPermission(AppPermission.rbacManageSuperAdmins),
        isTrue,
      );
    });
  });

  group('Anti-Privilege Escalation & Hierarchy Rules', () {
    test('No role can manage or elevate to Super Admin except Super Admin', () {
      expect(AppRole.passenger.canManageRole(AppRole.superAdmin), isFalse);
      expect(AppRole.driver.canManageRole(AppRole.superAdmin), isFalse);
      expect(AppRole.coxeur.canManageRole(AppRole.superAdmin), isFalse);
      expect(AppRole.gieAdmin.canManageRole(AppRole.superAdmin), isFalse);
      expect(AppRole.platformAdmin.canManageRole(AppRole.superAdmin), isFalse);
      expect(AppRole.superAdmin.canManageRole(AppRole.superAdmin), isTrue);
    });

    test('Roles of same level cannot administer each other', () {
      expect(AppRole.driver.canManageRole(AppRole.coxeur), isFalse);
      expect(AppRole.coxeur.canManageRole(AppRole.driver), isFalse);
      expect(AppRole.driver.canManageRole(AppRole.mechanic), isFalse);
    });

    test('GIE Admin cannot administer Platform Admins or Super Admins', () {
      final rbac = RbacService.instance;
      rbac.switchRoleForTesting(AppRole.gieAdmin, organizationId: 'gie_thies');

      expect(
        rbac.canManageUser(targetRole: AppRole.superAdmin),
        isFalse,
      );
      expect(
        rbac.canManageUser(targetRole: AppRole.platformAdmin),
        isFalse,
      );
      // Peut administrer son chauffeur
      expect(
        rbac.canManageUser(
          targetRole: AppRole.driver,
          targetOrganizationId: 'gie_thies',
        ),
        isTrue,
      );
      // Ne peut pas administrer le chauffeur d un autre GIE
      expect(
        rbac.canManageUser(
          targetRole: AppRole.driver,
          targetOrganizationId: 'gie_ndiambour',
        ),
        isFalse,
      );
    });
  });

  group('Sealed Snapshot & Offline TTL Enforcement', () {
    test('Snapshot within 30 min is valid, beyond 30 min is expired', () {
      final freshSnapshot = RbacContext(
        userId: 'u1',
        role: AppRole.driver,
        permissions: {AppPermission.ticketingScanCamera},
        snapshotTimestamp: DateTime.now(),
        ttlMinutes: 30,
      );
      expect(freshSnapshot.isExpired, isFalse);

      final expiredSnapshot = RbacContext(
        userId: 'u1',
        role: AppRole.driver,
        permissions: {AppPermission.ticketingScanCamera},
        snapshotTimestamp: DateTime.now().subtract(const Duration(minutes: 31)),
        ttlMinutes: 30,
      );
      expect(expiredSnapshot.isExpired, isTrue);
    });

    test('Critical operations strictly prohibited offline, non-critical permitted', () {
      final snapshot = RbacContext(
        userId: 'u1',
        role: AppRole.gieAdmin,
        permissions: {
          AppPermission.bookingSearch,
          AppPermission.ticketingScanCamera,
          AppPermission.cashRequestPayout,
          AppPermission.rbacManagePermissions,
        },
        snapshotTimestamp: DateTime.now(),
      );

      // Non-critiques autorisées en mode dégradé hors-ligne
      expect(snapshot.canPerformOffline(AppPermission.bookingSearch), isTrue);
      expect(snapshot.canPerformOffline(AppPermission.ticketingScanCamera), isTrue);

      // Critiques INTERDITES hors-ligne (exigent consensus serveur)
      expect(snapshot.canPerformOffline(AppPermission.cashRequestPayout), isFalse);
      expect(snapshot.canPerformOffline(AppPermission.rbacManagePermissions), isFalse);
    });
  });

  group('Feature Flags Multi-State & Dependency Resolution', () {
    test('6 states behavior: allowed operations vs read-only maintenance', () {
      expect(FeatureFlagStatus.enabled.allowsNewOperations, isTrue);
      expect(FeatureFlagStatus.pilot.allowsNewOperations, isTrue);

      expect(FeatureFlagStatus.maintenance.allowsNewOperations, isFalse);
      expect(FeatureFlagStatus.maintenance.isAccessible, isTrue);
      expect(FeatureFlagStatus.maintenance.isReadOnly, isTrue);

      expect(FeatureFlagStatus.disabled.allowsNewOperations, isFalse);
      expect(FeatureFlagStatus.disabled.isAccessible, isFalse);
    });

    test('Dependency graph prevents activating module without active prerequisites', () async {
      final flagService = FeatureFlagService.instance;

      // S assurer que le paiement Wave est désactivé
      await flagService.setStatus(
        FeatureFlagState.flagPaymentWave,
        FeatureFlagStatus.disabled,
      );

      // Tentative d activer le virement Mobile Money sans paiement Wave
      final success = await flagService.setStatus(
        FeatureFlagState.flagAutoMobileMoneyPayout,
        FeatureFlagStatus.enabled,
      );

      expect(success, isFalse);
      expect(
        flagService.isEnabled(FeatureFlagState.flagAutoMobileMoneyPayout),
        isFalse,
      );
    });
  });
}
