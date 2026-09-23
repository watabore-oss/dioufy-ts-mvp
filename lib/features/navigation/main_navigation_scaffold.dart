import 'package:flutter/material.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/permissions/app_role.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../ticket/my_tickets_screen.dart';
import '../chauffeur/chauffeur_screen.dart';
import '../chauffeur/cloture_caisse_screen.dart';
import '../coxeur/coxeur_dashboard_screen.dart';
import '../gie/gie_dashboard_screen.dart';
import '../admin/super_admin_dashboard_screen.dart';
import '../../modules/garage_assistance/garage_assistance_module.dart';
import '../digital_display/presentation/digital_display_widget.dart';
import '../digital_display/services/digital_display_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/forgot_password_screen.dart';

/// Configuration de navigation par rôle pour Dioufy-TS
class _RoleNavBundle {
  final List<Widget> pages;
  final List<NavigationDestination> destinations;

  const _RoleNavBundle({
    required this.pages,
    required this.destinations,
  });
}

/// Composant racine de navigation Dioufy-TS avec BottomNavigationBar dynamique selon le rôle RBAC,
/// conservation d'état (IndexedStack) et bouton de retour déterministe.
class MainNavigationScaffold extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  late int _currentIndex;
  bool _isDigitalDisplayCollapsed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  _RoleNavBundle _getRoleBundle(AppRole role) {
    switch (role) {
      case AppRole.driver:
        return const _RoleNavBundle(
          pages: [
            ChauffeurScreen(),
            ClotureCaisseScreen(),
            HomeScreen(),
            _UserProfileTab(),
          ],
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'Chef de Bord',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: 'Caisse',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route),
              selectedIcon: Icon(Icons.alt_route),
              label: 'Lignes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        );

      case AppRole.coxeur:
        return const _RoleNavBundle(
          pages: [
            CoxeurDashboardScreen(),
            ChauffeurScreen(),
            HomeScreen(),
            _UserProfileTab(),
          ],
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.departure_board_outlined),
              selectedIcon: Icon(Icons.departure_board),
              label: 'Régulation',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Contrôle',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route),
              selectedIcon: Icon(Icons.alt_route),
              label: 'Lignes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        );

      case AppRole.gieAdmin:
      case AppRole.gieAgent:
        return const _RoleNavBundle(
          pages: [
            GieDashboardScreen(),
            CoxeurDashboardScreen(),
            ChauffeurScreen(),
            _UserProfileTab(),
          ],
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: 'Flotte & GIE',
            ),
            NavigationDestination(
              icon: Icon(Icons.departure_board_outlined),
              selectedIcon: Icon(Icons.departure_board),
              label: 'Régulation',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Contrôle',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        );

      case AppRole.superAdmin:
      case AppRole.platformAdmin:
        return const _RoleNavBundle(
          pages: [
            SuperAdminDashboardScreen(),
            GieDashboardScreen(),
            CoxeurDashboardScreen(),
            _UserProfileTab(),
          ],
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Console',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: 'Flotte GIE',
            ),
            NavigationDestination(
              icon: Icon(Icons.departure_board_outlined),
              selectedIcon: Icon(Icons.departure_board),
              label: 'Régulation',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        );

      case AppRole.mechanic:
        return const _RoleNavBundle(
          pages: [
            GarageAssistanceScreen(),
            ChauffeurScreen(),
            _PassengerAssistanceTab(),
            _UserProfileTab(),
          ],
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.build_circle_outlined),
              selectedIcon: Icon(Icons.build_circle),
              label: 'SOS Dépannage',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_bus_outlined),
              selectedIcon: Icon(Icons.directions_bus),
              label: 'Bus',
            ),
            NavigationDestination(
              icon: Icon(Icons.support_agent),
              selectedIcon: Icon(Icons.support_agent),
              label: 'Support',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        );

      case AppRole.passenger:
        return const _RoleNavBundle(
          pages: [
            HomeScreen(),
            MyTicketsScreen(),
            _PassengerAssistanceTab(),
            _UserProfileTab(),
          ],
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search),
              label: 'Recherche',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'Mes Billets',
            ),
            NavigationDestination(
              icon: Icon(Icons.support_agent),
              selectedIcon: Icon(Icons.support_agent),
              label: 'Assistance',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final role = AuthService.instance.currentRole;
        final bundle = _getRoleBundle(role);
        final clampedIndex = _currentIndex.clamp(0, bundle.pages.length - 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= DioufyBreakpoints.tablet;
            final isTablet = width >= DioufyBreakpoints.mobile && width < DioufyBreakpoints.tablet;

            if (isDesktop) {
              return _buildDesktopShell(bundle, clampedIndex, role);
            } else if (isTablet) {
              return _buildTabletShell(bundle, clampedIndex);
            } else {
              return _buildMobileShell(bundle, clampedIndex);
            }
          },
        );
      },
    );
  }

  // ===========================================================================
  // 1. DESKTOP EXPERIENCE SHELL (≥ 1024px)
  // Rail vertical lumineux + Espace Applicatif Métier (48%) + Digital Display (52%)
  // ===========================================================================
  Widget _buildDesktopShell(_RoleNavBundle bundle, int clampedIndex, AppRole role) {
    return Scaffold(
      backgroundColor: DioufyColors.background,
      body: Row(
        children: [
          // NavigationRail lumineux moderne Dioufy-TS
          NavigationRailTheme(
            data: NavigationRailThemeData(
              backgroundColor: DioufyColors.white,
              selectedIconTheme: const IconThemeData(color: DioufyColors.primary, size: 24),
              unselectedIconTheme: const IconThemeData(color: DioufyColors.textSecondary, size: 22),
              selectedLabelTextStyle: const TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                color: DioufyColors.primary,
                fontSize: 13,
                fontWeight: DioufyTypography.bold,
              ),
              unselectedLabelTextStyle: const TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                color: DioufyColors.textSecondary,
                fontSize: 12,
                fontWeight: DioufyTypography.medium,
              ),
              indicatorColor: DioufyColors.primarySoft,
            ),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: DioufyColors.border, width: 1.0)),
              ),
              child: NavigationRail(
                selectedIndex: clampedIndex,
                onDestinationSelected: _onTabSelected,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DioufyColors.primary,
                      borderRadius: DioufyRadius.mdAll,
                      boxShadow: [
                        BoxShadow(
                          color: DioufyColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: DioufyRadius.mdAll,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.directions_bus_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        icon: Icon(
                          _isDigitalDisplayCollapsed
                              ? Icons.slideshow_rounded
                              : Icons.fullscreen_rounded,
                          color: DioufyColors.primary,
                        ),
                        tooltip: _isDigitalDisplayCollapsed
                            ? 'Afficher le Digital Display'
                            : 'Plein écran applicatif (masquer le slide)',
                        onPressed: () {
                          setState(() => _isDigitalDisplayCollapsed = !_isDigitalDisplayCollapsed);
                        },
                      ),
                    ),
                  ),
                ),
                destinations: bundle.destinations.map((d) {
                  return NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon ?? d.icon,
                    label: Text(d.label),
                  );
                }).toList(),
              ),
            ),
          ),

          // Volet gauche : Zone Applicative Métier
          Expanded(
            flex: 5,
            child: Container(
              color: DioufyColors.background,
              child: IndexedStack(
                index: clampedIndex,
                children: bundle.pages,
              ),
            ),
          ),

          // Volet droit : Digital Display permanent et contextuel (sauf si replié)
          if (!_isDigitalDisplayCollapsed) ...[
            const VerticalDivider(width: 1, thickness: 1, color: DioufyColors.border),
            Expanded(
              flex: 5,
              child: DigitalDisplayWidget(
                key: ValueKey('${role.id}-$clampedIndex'),
                slides: DigitalDisplayService.instance.getSlidesForRole(
                  role,
                  tabIndex: clampedIndex,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. TABLET EXPERIENCE SHELL (600px - 1023px)
  // Rail vertical + Pleine largeur applicative centrée ergonomique
  // ===========================================================================
  Widget _buildTabletShell(_RoleNavBundle bundle, int clampedIndex) {
    return Scaffold(
      backgroundColor: DioufyColors.background,
      body: Row(
        children: [
          NavigationRailTheme(
            data: NavigationRailThemeData(
              backgroundColor: DioufyColors.white,
              selectedIconTheme: const IconThemeData(color: DioufyColors.primary, size: 24),
              unselectedIconTheme: const IconThemeData(color: DioufyColors.textSecondary, size: 22),
              selectedLabelTextStyle: const TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                color: DioufyColors.primary,
                fontSize: 12.5,
                fontWeight: DioufyTypography.bold,
              ),
              unselectedLabelTextStyle: const TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                color: DioufyColors.textSecondary,
                fontSize: 11.5,
              ),
              indicatorColor: DioufyColors.primarySoft,
            ),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: DioufyColors.border, width: 1.0)),
              ),
              child: NavigationRail(
                selectedIndex: clampedIndex,
                onDestinationSelected: _onTabSelected,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DioufyColors.primary,
                      borderRadius: DioufyRadius.mdAll,
                    ),
                    child: ClipRRect(
                      borderRadius: DioufyRadius.mdAll,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.directions_bus_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                destinations: bundle.destinations.map((d) {
                  return NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon ?? d.icon,
                    label: Text(d.label),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: IndexedStack(
                  index: clampedIndex,
                  children: bundle.pages,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. MOBILE EXPERIENCE SHELL (< 600px)
  // Navigation native mobile 1 colonne avec BottomNavigationBar lumineuse
  // ===========================================================================
  Widget _buildMobileShell(_RoleNavBundle bundle, int clampedIndex) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (clampedIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: DioufyColors.background,
        body: IndexedStack(
          index: clampedIndex,
          children: bundle.pages,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: DioufyColors.white,
            border: Border(top: BorderSide(color: DioufyColors.border, width: 1.0)),
            boxShadow: DioufyShadows.bottomBar,
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: DioufyColors.white,
              indicatorColor: DioufyColors.primarySoft,
              surfaceTintColor: Colors.transparent,
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontFamily: DioufyTypography.fontFamily,
                    fontSize: 13.0,
                    fontWeight: DioufyTypography.bold,
                    color: DioufyColors.primary,
                    letterSpacing: 0.2,
                  );
                }
                return const TextStyle(
                  fontFamily: DioufyTypography.fontFamily,
                  fontSize: 12.0,
                  fontWeight: DioufyTypography.semiBold,
                  color: DioufyColors.textSecondary,
                  letterSpacing: 0.1,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: DioufyColors.primary, size: 24);
                }
                return const IconThemeData(color: DioufyColors.textSecondary, size: 22);
              }),
            ),
            child: NavigationBar(
              selectedIndex: clampedIndex,
              onDestinationSelected: _onTabSelected,
              backgroundColor: DioufyColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: bundle.destinations,
            ),
          ),
        ),
      ),
    );
  }
}

/// Onglet d'assistance & informations gares pour les voyageurs
class _PassengerAssistanceTab extends StatelessWidget {
  const _PassengerAssistanceTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Assistance & Lignes Dioufy-TS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.directions_bus, color: Color(0xFF1E3A8A), size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gare Numérique du Sénégal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Départs quotidiens garantis entre Dakar, Thiès, Touba, Saint-Louis et Mbour.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Assistance Voyageurs 7j/7 :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF25D366),
                      child: Icon(Icons.chat, color: Colors.white, size: 20),
                    ),
                    title: const Text('Support WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('+221 77 469 13 79 • Réponse immédiate', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1E3A8A),
                      child: Icon(Icons.phone, color: Colors.white, size: 20),
                    ),
                    title: const Text('Standard Téléphonique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Baux Maraîchers : +221 33 800 00 00', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet Compte / Profil de l'utilisateur connecté ou invité
class _UserProfileTab extends StatelessWidget {
  const _UserProfileTab();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final isLoggedIn = AuthService.instance.isLoggedIn;
        final user = AuthService.instance.currentUser;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Mon Profil & Compte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Carte d'identité utilisateur
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFFBBF24),
                        child: Text(
                          isLoggedIn ? user.fullName.characters.first.toUpperCase() : 'V',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoggedIn ? user.fullName : 'Voyageur Invité',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoggedIn ? user.role.name : 'Réservation directe sans compte',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isLoggedIn && user.phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(user.phone, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (!isLoggedIn) ...[
                  // Actions de connexion / Inscription si invité
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    icon: const Icon(Icons.login),
                    label: const Text('SE CONNECTER À MON COMPTE', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('CRÉER UN COMPTE DIOUFY-TS', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Bouton Google
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService.instance.signInWithGoogle();
                      },
                      icon: const Icon(Icons.account_circle, color: Color(0xFF1E3A8A), size: 24),
                      label: const Text('Continuer avec Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Options pour utilisateur connecté
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_reset, color: Color(0xFF1E3A8A)),
                          title: const Text('Changer de mot de passe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF059669)),
                          title: const Text('Mes Billets enregistrés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Se déconnecter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                          onTap: () {
                            AuthService.instance.logout();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Déconnexion effectuée avec succès.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
