import 'package:flutter/material.dart';
import '../features/navigation/main_navigation_scaffold.dart';
import '../features/home/home_screen.dart';
import '../features/ticket/my_tickets_screen.dart';
import '../features/chauffeur/chauffeur_screen.dart';
import '../features/chauffeur/cloture_caisse_screen.dart';
import '../features/chauffeur/qr_camera_scanner_screen.dart';
import '../modules/garage_assistance/garage_assistance_module.dart';
import '../features/admin/rbac_management_screen.dart';
import '../features/admin/super_admin_dashboard_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/coxeur/coxeur_dashboard_screen.dart';
import '../features/gie/gie_dashboard_screen.dart';
import '../features/passenger/passenger_dashboard_screen.dart';
import 'feature_flags/feature_guard.dart';
import 'feature_flags/feature_flag_state.dart';

/// Routage centralisé de l'application Dioufy-TS
class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String myTickets = '/my-tickets';
  static const String chauffeur = '/chauffeur';
  static const String coxeur = '/coxeur';
  static const String gieDashboard = '/gie';
  static const String passengerDashboard = '/passenger';
  static const String clotureCaisse = '/chauffeur/cloture-caisse';
  static const String qrScanner = '/chauffeur/qr-scanner';
  static const String garageAssistance = '/garage-assistance';
  static const String rbacManagement = '/admin/rbac';
  static const String superAdminDashboard = '/admin/dashboard';
  static const String resetPassword = '/reset-password';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScaffold());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case resetPassword:
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());

      case superAdminDashboard:
        return MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen());

      case myTickets:
        return MaterialPageRoute(
          builder: (_) => const FeatureGuard(
            flagKey: FeatureFlagState.flagTicketingHmacQr,
            featureName: 'Mes Billets',
            child: MyTicketsScreen(),
          ),
        );

      case chauffeur:
        return MaterialPageRoute(
          builder: (_) => const FeatureGuard(
            flagKey: FeatureFlagState.flagMultiTenancyGie,
            featureName: 'Espace Chef de Bord / Chauffeur',
            child: ChauffeurScreen(),
          ),
        );

      case coxeur:
        return MaterialPageRoute(
          builder: (_) => const CoxeurDashboardScreen(),
        );

      case gieDashboard:
        return MaterialPageRoute(
          builder: (_) => const GieDashboardScreen(),
        );

      case passengerDashboard:
        return MaterialPageRoute(
          builder: (_) => const PassengerDashboardScreen(),
        );

      case clotureCaisse:
        return MaterialPageRoute(
          builder: (_) => const FeatureGuard(
            flagKey: FeatureFlagState.flagCashClosureChauffeur,
            featureName: 'Clôture de Caisse & Commissions',
            child: ClotureCaisseScreen(),
          ),
        );

      case qrScanner:
        return MaterialPageRoute(
          builder: (_) => const FeatureGuard(
            flagKey: FeatureFlagState.flagFieldOpsCameraScan,
            featureName: 'Scanner de Billets',
            child: QrCameraScannerScreen(),
          ),
        );

      case garageAssistance:
        return MaterialPageRoute(
          builder: (_) => const GarageAssistanceScreen(),
        );

      case rbacManagement:
        return MaterialPageRoute(
          builder: (_) => const RbacManagementScreen(),
        );

      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
