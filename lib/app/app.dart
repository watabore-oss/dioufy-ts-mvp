import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../features/landing/landing_screen.dart';
import '../features/navigation/main_navigation_scaffold.dart';
import '../features/auth/reset_password_screen.dart';
import '../services/version_check_service.dart';
import 'router.dart';

/// Widget racine de l'application Dioufy-TS
class DioufyApp extends StatelessWidget {
  const DioufyApp({super.key});

  /// Clé globale du navigateur pour la navigation native et le retour Android
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Gestionnaire universel de retour arrière (PopScope, Predictive Back & Android hardware)
  static bool handleBackNavigation() {
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        final isRecovery = auth.isPasswordRecovery;
        final isLoggedIn = auth.isLoggedIn;

        final Widget homeWidget;
        if (isRecovery) {
          homeWidget = const ResetPasswordScreen();
        } else if (isLoggedIn) {
          homeWidget = const MainNavigationScaffold();
        } else {
          homeWidget = const LandingScreen();
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Dioufy-TS',
          theme: DioufyTheme.light,
          home: homeWidget,
          onGenerateRoute: AppRouter.onGenerateRoute,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr', 'FR'),
            Locale('en', 'US'),
          ],
          locale: const Locale('fr', 'FR'),
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              VersionCheckService.instance.showUpdateDialogIfNeeded(context);
            });
            return child ?? const SizedBox();
          },
        );
      },
    );
  }
}
