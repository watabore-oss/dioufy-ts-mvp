import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../ticket/my_tickets_screen.dart';
import '../search/search_results_screen.dart';
import '../search/trip.dart';
import '../auth/forgot_password_screen.dart';

/// Tableau de bord dédié Espace Voyageur / Passager Dioufy-TS
/// Épuré au maximum : recherche de trajet directe et 4 actions clés sans aucun bruit technique.
class PassengerDashboardScreen extends StatefulWidget {
  const PassengerDashboardScreen({super.key});

  @override
  State<PassengerDashboardScreen> createState() => _PassengerDashboardScreenState();
}

class _PassengerDashboardScreenState extends State<PassengerDashboardScreen> {
  String selectedDeparture = "Dakar";
  String selectedDestination = "Touba";
  DateTime selectedDate = DateTime.now();

  final List<String> cities = AppConstants.cityNames;

  void _swapCities() {
    setState(() {
      final temp = selectedDeparture;
      selectedDeparture = selectedDestination;
      selectedDestination = temp;
    });
  }

  void _handleSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          departure: selectedDeparture,
          destination: selectedDestination,
          travelDate: "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}",
          passengerCount: 1,
        ),
      ),
    );
  }

  void _openAssistanceModal() {
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
              'Besoin d aide pour votre billet, un départ ou un bagage ?',
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
              subtitle: const Text('Régulation & Départs : +221 33 800 00 00', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAccountDialog() {
    final user = AuthService.instance.currentUser;
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
                CircleAvatar(
                  backgroundColor: DioufyColors.primaryDark,
                  radius: 24,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'P',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user.phone ?? user.email ?? 'Compte Voyageur', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Color(0xFF1E3A8A)),
              title: const Text('Changer de mot de passe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                AuthService.instance.logout();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Espace Voyageur',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF0F172A)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 24),
            tooltip: 'Retour',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
              ),
              child: Text(
                user.fullName.split(' ').first,
                style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. MOTEUR DE RECHERCHE DIRECT (OÙ VOULEZ-VOUS ALLER ?)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_bus, color: DioufyColors.primaryDark, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Où voulez-vous aller ?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: DioufyColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Départ
                    DropdownButtonFormField<String>(
                      value: selectedDeparture,
                      decoration: InputDecoration(
                        labelText: 'Gare de départ',
                        prefixIcon: const Icon(Icons.trip_origin, color: Color(0xFF0F766E)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c == 'Dakar' ? 'Dakar (Baux Maraîchers)' : c))).toList(),
                      onChanged: (v) => setState(() => selectedDeparture = v ?? selectedDeparture),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.swap_vert, color: DioufyColors.primaryDark),
                        onPressed: _swapCities,
                        tooltip: 'Inverser les gares',
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Destination
                    DropdownButtonFormField<String>(
                      value: selectedDestination,
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: const Icon(Icons.location_on, color: Color(0xFFB45309)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => selectedDestination = v ?? selectedDestination),
                    ),

                    const SizedBox(height: 20),

                    // BOUTON RECHERCHER
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _handleSearch,
                        icon: const Icon(Icons.search, size: 22),
                        label: const Text(
                          'RECHERCHER UN BILLET',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DioufyColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. LES 4 ACTIONS PRINCIPALES VOYAGEUR
              const Text(
                'Vos Raccourcis Voyageur',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DioufyColors.primaryDark),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.confirmation_number_outlined,
                      color: const Color(0xFF047857),
                      title: 'Mes Billets',
                      subtitle: 'QR Codes hors-ligne',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.luggage_outlined,
                      color: const Color(0xFF0284C7),
                      title: 'Mes Voyages',
                      subtitle: 'Trajets réservés',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.support_agent,
                      color: const Color(0xFF7C3AED),
                      title: 'Assistance',
                      subtitle: 'WhatsApp 7j/7',
                      onTap: _openAssistanceModal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.person_outline,
                      color: const Color(0xFF475569),
                      title: 'Mon Compte',
                      subtitle: 'Profil & Sécurité',
                      onTap: _showAccountDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              radius: 20,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
