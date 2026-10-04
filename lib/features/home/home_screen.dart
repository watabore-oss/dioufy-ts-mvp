import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/permissions/app_role.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/permission_guard.dart';
import '../../services/auth_service.dart';
import '../admin/super_admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../chauffeur/chauffeur_screen.dart';
import '../search/search_results_screen.dart';
import '../ticket/my_tickets_screen.dart';
import 'dioufy_live_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedDeparture = "Dakar";
  String selectedDestination = "Thiès";
  DateTime selectedDate = DateTime.now();
  int passengerCount = 1;

  final List<String> cities = AppConstants.cityNames;

  void _swapCities() {
    setState(() {
      final temp = selectedDeparture;
      selectedDeparture = selectedDestination;
      selectedDestination = temp;
    });
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    return "$day/$month/$year";
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = selectedDate.isBefore(today) ? today : selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate.day == DateTime.now().day &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.year == DateTime.now().year;

    final isTomorrow = selectedDate.day == DateTime.now().add(const Duration(days: 1)).day &&
        selectedDate.month == DateTime.now().add(const Duration(days: 1)).month;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Racine de l'application : Android gère la mise en veille ou sortie propre
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // En-tête Hero avec arrière-plan animé dioufy-ts.sn & accès rapides sans troncature
            DioufyLiveBackground(
              busOpacity: 0.08,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rangée 1 : Logo Dioufy-TS, Slogan & Profil Utilisateur Dynamique
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                    'assets/logo.png',
                                  height: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, stack) => const Icon(
                                    Icons.directions_bus,
                                    color: Color(0xFFFBBF24),
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        "Dioufy-TS",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        "Fo nek sa gare fek lafa",
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          color: Color(0xFFFBBF24),
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Widget Profil & Connexion
                          AnimatedBuilder(
                            animation: AuthService.instance,
                            builder: (context, _) {
                              final isLoggedIn = AuthService.instance.isLoggedIn;
                              final isSuperAdmin = AuthService.instance.isSuperAdmin;
                              final user = AuthService.instance.currentUser;

                              if (!isLoggedIn) {
                                return TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  ),
                                  icon: const Icon(Icons.login, color: Color(0xFFFBBF24), size: 18),
                                  label: const Text(
                                    "Connexion",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.18),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                );
                              }

                              return PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'admin') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()),
                                    );
                                  } else if (val == 'chauffeur') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ChauffeurScreen()),
                                    );
                                  } else if (val == 'change_password') {
                                    _showChangePasswordDialog(context);
                                  } else if (val == 'logout') {
                                    AuthService.instance.logout();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Déconnexion effectuée.')),
                                    );
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    enabled: false,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        Text(
                                          user.role.name,
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                        const Divider(),
                                      ],
                                    ),
                                  ),
                                  if (isSuperAdmin)
                                    const PopupMenuItem(
                                      value: 'admin',
                                      child: Row(
                                        children: [
                                          Icon(Icons.dashboard_customize, size: 18, color: Color(0xFF1E3A8A)),
                                          SizedBox(width: 8),
                                          Text('Dashboard Super Admin'),
                                        ],
                                      ),
                                    ),
                                  if (user.role == AppRole.driver || isSuperAdmin)
                                    const PopupMenuItem(
                                      value: 'chauffeur',
                                      child: Row(
                                        children: [
                                          Icon(Icons.directions_bus, size: 18, color: Color(0xFF059669)),
                                          SizedBox(width: 8),
                                          Text('Espace Chef de Bord'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'change_password',
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock_reset, size: 18, color: Color(0xFF2563EB)),
                                        SizedBox(width: 8),
                                        Text('Changer de mot de passe'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'logout',
                                    child: Row(
                                      children: [
                                        Icon(Icons.logout, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Se déconnecter'),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSuperAdmin
                                        ? const Color(0xFFFBBF24).withOpacity(0.25)
                                        : Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSuperAdmin ? const Color(0xFFFBBF24) : Colors.white24,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSuperAdmin ? Icons.shield : Icons.account_circle,
                                        color: isSuperAdmin ? const Color(0xFFFBBF24) : Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isSuperAdmin
                                            ? 'Admin'
                                            : (user.fullName.split(' ').first),
                                        style: TextStyle(
                                          color: isSuperAdmin ? const Color(0xFFFBBF24) : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Rangée 2 : Barre de Raccourcis Tactiles Calée au Viewport (Mobile-First Wrap, Zéro Débordement)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // 1. Billets (Hors-ligne)
                          _buildQuickActionChip(
                            icon: Icons.confirmation_number_outlined,
                            label: "Mes Billets",
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                            ),
                          ),

                          // 2. Chef de bord (Chauffeur / Coxeur / Admin UNIQUEMENT - STRICTEMENT MASQUÉ POUR PASSAGERS)
                          AnimatedBuilder(
                            animation: AuthService.instance,
                            builder: (context, _) {
                              final role = AuthService.instance.currentRole;
                              final isStaff = role == AppRole.driver ||
                                  role == AppRole.coxeur ||
                                  AuthService.instance.isSuperAdmin;
                              if (!isStaff) return const SizedBox.shrink();
                              return _buildQuickActionChip(
                                icon: Icons.qr_code_scanner,
                                label: "Chef de bord",
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PermissionGuard(
                                      permissionId: AppPermission.fleetViewVehicles,
                                      actionLabel: 'Espace Chef de Bord / Chauffeur',
                                      child: ChauffeurScreen(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // 3. Super Admin (si admin)
                          AnimatedBuilder(
                            animation: AuthService.instance,
                            builder: (context, _) {
                              if (!AuthService.instance.isSuperAdmin) return const SizedBox.shrink();
                              return _buildQuickActionChip(
                                icon: Icons.admin_panel_settings,
                                label: "Super Admin",
                                isGold: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()),
                                ),
                              );
                            },
                          ),

                          // 4. Gérant ou Agent GIE (si transporteur)
                          AnimatedBuilder(
                            animation: AuthService.instance,
                            builder: (context, _) {
                              final role = AuthService.instance.currentRole;
                              final isGie = role == AppRole.gieAdmin || role == AppRole.gieAgent;
                              if (!isGie) return const SizedBox.shrink();
                              return _buildQuickActionChip(
                                icon: Icons.business,
                                label: "GIE Transport",
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SuperAdminDashboardScreen(initialTab: 1),
                                  ),
                                ),
                              );
                            },
                          ),

                          // 5. Raccourci Assistance Voyageur (Toujours visible pour les passagers)
                          _buildQuickActionChip(
                            icon: Icons.support_agent,
                            label: "Assistance",
                            onTap: () => _showAssistanceModal(context),
                          ),

                          // 5. Raccourci Inscription / Compte si voyageur direct
                          AnimatedBuilder(
                            animation: AuthService.instance,
                            builder: (context, _) {
                              if (AuthService.instance.isLoggedIn) return const SizedBox.shrink();
                              return _buildQuickActionChip(
                                icon: Icons.person_add_alt,
                                label: "Créer un compte",
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Badge réassurance achat sans compte pour voyageurs directs
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, color: Color(0xFFFBBF24), size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Réservation directe sans compte disponible",
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Carte de Recherche moderne
                      Card(
                        elevation: 8,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Départ avec icône
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedDeparture,
                                decoration: InputDecoration(
                                  labelText: "Gare de Départ",
                                  prefixIcon: const Icon(Icons.trip_origin, color: Color(0xFF1E3A8A)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: cities.map((city) {
                                  return DropdownMenuItem(
                                    value: city,
                                    child: Text(
                                      city == "Dakar" ? "Dakar (Baux Maraîchers)" : city,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedDeparture = val);
                                },
                              ),

                              // Bouton d'inversion des villes
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: const Icon(
                                        Icons.swap_vert,
                                        color: Color(0xFF1E3A8A),
                                        size: 20,
                                      ),
                                    ),
                                    tooltip: "Inverser départ et destination",
                                    onPressed: _swapCities,
                                  ),
                                ),
                              ),

                              // Destination avec icône
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedDestination,
                                decoration: InputDecoration(
                                  labelText: "Destination",
                                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF059669)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: cities.map((city) {
                                  return DropdownMenuItem(
                                    value: city,
                                    child: Text(
                                      city == "Touba" ? "Touba (Gare Ouest)" : city,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedDestination = val);
                                },
                              ),

                              const SizedBox(height: 18),

                              // Sélecteur de Date de voyage
                              const Text(
                                "Date de départ",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Aujourd'hui
                                  Expanded(
                                    child: _buildDateChoiceChip(
                                      label: "Aujourd'hui",
                                      isSelected: isToday,
                                      onTap: () => setState(() => selectedDate = DateTime.now()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Demain
                                  Expanded(
                                    child: _buildDateChoiceChip(
                                      label: "Demain",
                                      isSelected: isTomorrow,
                                      onTap: () => setState(() => selectedDate = DateTime.now().add(const Duration(days: 1))),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Calendrier
                                  InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: (!isToday && !isTomorrow) ? const Color(0xFF1E3A8A) : Colors.white,
                                        border: Border.all(
                                          color: (!isToday && !isTomorrow) ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.calendar_month,
                                        size: 18,
                                        color: (!isToday && !isTomorrow) ? Colors.white : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Nombre de passagers
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          "Nombre de passagers",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        Text(
                                          "Places à réserver",
                                          style: TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [1, 2, 3, 4].map((count) {
                                        final isSel = passengerCount == count;
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: InkWell(
                                            onTap: () => setState(() => passengerCount = count),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                "$count",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSel ? Colors.white : const Color(0xFF0F172A),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              // Bouton de Recherche principal
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (selectedDeparture == selectedDestination) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Le départ et l'arrivée doivent être différents."),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SearchResultsScreen(
                                          departure: selectedDeparture,
                                          destination: selectedDestination,
                                          travelDate: _formatDate(selectedDate),
                                          passengerCount: passengerCount,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search, color: Colors.white, size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        "RECHERCHER",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 17,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Lignes populaires au Sénégal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lignes populaires du moment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPopularRouteCard(
                          from: "Dakar",
                          to: "Touba",
                          price: "5 000 FCFA",
                          duration: "2h30",
                          highlight: "Spécial Express",
                        ),
                        const SizedBox(width: 12),
                        _buildPopularRouteCard(
                          from: "Dakar",
                          to: "Saint-Louis",
                          price: "7 000 FCFA",
                          duration: "3h45",
                          highlight: "Climatisé",
                        ),
                        const SizedBox(width: 12),
                        _buildPopularRouteCard(
                          from: "Dakar",
                          to: "Thiès",
                          price: "2 500 FCFA",
                          duration: "1h00",
                          highlight: "Navette fréquente",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Engagement Qualité Dioufy-TS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.offline_pin, color: Color(0xFF059669), size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Billets accessibles 100% Hors-ligne",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Présentez votre QR Code sécurisé à la gare même sans connexion internet.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pied de page
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 28,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        Icons.directions_bus,
                        color: Color(0xFF1E3A8A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Dioufy-TS • Le Réseau National du Sénégal",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDateChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPopularRouteCard({
    required String from,
    required String to,
    required String price,
    required String duration,
    required String highlight,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedDeparture = from;
          selectedDestination = to;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                highlight,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$from → $to",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              duration,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const XofCurrencyBadge(size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isGold = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: isGold ? const Color(0xFFFBBF24).withOpacity(0.25) : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isGold ? const Color(0xFFFBBF24) : Colors.white24,
            width: isGold ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFBBF24), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isGold ? const Color(0xFFFBBF24) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Color(0xFFFBBF24)),
            SizedBox(width: 8),
            Text('Changer de mot de passe', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirmez le mot de passe',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (newPassCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le mot de passe doit comporter au moins 6 caractères.')),
                );
                return;
              }
              if (newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
                );
                return;
              }
              final ok = await AuthService.instance.updatePassword(newPassword: newPassCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Mot de passe mis à jour avec succès !' : 'Erreur mise à jour mot de passe.'),
                    backgroundColor: ok ? const Color(0xFF059669) : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Mettre à jour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAssistanceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent, color: Color(0xFF0F172A), size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Assistance Voyageurs Dioufy-TS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Besoin d aide pour votre billet, un départ ou une réclamation ?',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.chat, color: Colors.white, size: 20),
              ),
              title: const Text('Support WhatsApp Direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('+221 77 469 13 79 • Réponse 7j/7', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1E3A8A),
                child: Icon(Icons.phone, color: Colors.white, size: 20),
              ),
              title: const Text('Gare des Baux Maraîchers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Régulation & Quais : +221 33 800 00 00', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
