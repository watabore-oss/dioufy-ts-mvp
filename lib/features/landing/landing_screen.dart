import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../digital_display/presentation/digital_display_widget.dart';
import '../digital_display/presentation/mobile_hero_slide_zone.dart';
import '../digital_display/presentation/mobile_promo_card.dart';
import '../search/search_results_screen.dart';

/// Écran d'accueil et de réservation Dioufy-TS adaptatif Desktop & Mobile.
///
/// Implémente le mode Desktop Experience natif :
/// - Desktop (>= 960px) : Volet gauche applicatif ultra pur et lumineux +
///   Volet droit Digital Display avec diaporama cinématique auto-détecté.
/// - Mobile (< 960px) : Expérience parfaitement alignée :
///   * Logo aligné à gauche
///   * Sélecteur multilingue aligné à droite
///   * Slogan agrandi en semi-bold italique
///   * Tous les autres éléments (libellés des boutons, contenu et mentions du footer) centrés
///   * Typographie rehaussée sur tout le contenu pour lisibilité sans effort (seniors).
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String _departureCity = 'Dakar';
  String _destinationCity = 'Touba';
  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  int _passengerCount = 1;
  String _selectedLanguage = 'FR';
  bool _isDarkMode = false;

  static const List<String> _frenchMonths = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  String _formatDisplayDate(DateTime d) {
    return '${d.day} ${_frenchMonths[d.month - 1]} ${d.year}';
  }

  String _formatApiDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    return '$day/$month/$year';
  }

  void _swapCities() {
    setState(() {
      final temp = _departureCity;
      _departureCity = _destinationCity;
      _destinationCity = temp;
    });
  }

  Future<void> _selectCity({required bool isDeparture}) async {
    final availableCities = AppConstants.cityNames;
    final currentVal = isDeparture ? _departureCity : _destinationCity;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDeparture ? 'Ville de Départ' : 'Ville de Destination',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 24),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: availableCities.map((city) {
                    final isCurrent = city == currentVal;
                    return ChoiceChip(
                      label: Text(city),
                      selected: isCurrent,
                      selectedColor: const Color(0xFF1D4ED8),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isCurrent ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 15.5,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isCurrent
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      onSelected: (val) {
                        if (val) Navigator.pop(ctx, city);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        if (isDeparture) {
          _departureCity = selected;
          if (_destinationCity == selected) {
            _destinationCity = availableCities.firstWhere(
              (c) => c != selected,
              orElse: () => 'Touba',
            );
          }
        } else {
          _destinationCity = selected;
          if (_departureCity == selected) {
            _departureCity = availableCities.firstWhere(
              (c) => c != selected,
              orElse: () => 'Dakar',
            );
          }
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate.isBefore(now) ? now : _departureDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D4ED8),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _departureDate = picked);
    }
  }

  Future<void> _pickPassengers() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nombre de passagers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(8, (i) {
                    final count = i + 1;
                    final isSel = count == _passengerCount;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, count),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _passengerCount = picked);
    }
  }

  void _handleSearch() {
    AuthService.instance.continueAsGuest();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          departure: _departureCity,
          destination: _destinationCity,
          travelDate: _formatApiDate(_departureDate),
          passengerCount: _passengerCount,
        ),
      ),
    );
  }

  void _showPopularDestinationsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destinations populaires au Sénégal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDestinationRow('Dakar ↔ Touba', 'Départs quotidiens toutes les 30 min'),
                _buildDestinationRow('Dakar ↔ Saint-Louis', 'Ligne express climatisée'),
                _buildDestinationRow('Dakar ↔ Ziguinchor', 'Trajet régulier sud Sénégal'),
                _buildDestinationRow('Dakar ↔ Thiès', 'Navette rapide continue'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDestinationRow(String route, String desc) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFFEFF6FF),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.directions_bus, color: Color(0xFF1D4ED8), size: 24),
      ),
      title: Text(route, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF94A3B8)),
      onTap: () {
        Navigator.pop(context);
        final parts = route.split(' ↔ ');
        if (parts.length == 2) {
          setState(() {
            _departureCity = parts[0].trim();
            _destinationCity = parts[1].trim();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  // ==========================================
  // DISPOSITION DESKTOP (Split Screen 38% / 62%)
  // ==========================================
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // VOLET GAUCHE : APPLICATION & RÉSERVATION
        Container(
          width: 540,
          constraints: const BoxConstraints(minWidth: 480, maxWidth: 600),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
          ),
          child: Column(
            children: [
              // EN-TÊTE FIXE DU VOLET GAUCHE
              _buildLeftPaneHeader(isMobile: false),

              // CONTENU SCROLLABLE DU VOLET GAUCHE
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SLOGAN MIS EN VALEUR
                      _buildSloganSection(isMobile: false),

                      const SizedBox(height: 12),

                      // TITRE DE BIENVENUE BRILLANT ET PUR
                      _buildWelcomeSection(isMobile: false),

                      const SizedBox(height: 24),

                      // BOUTONS RAPIDES AUTHENTIFICATION
                      _buildAuthButtonsRow(isMobile: false),

                      const SizedBox(height: 20),

                      // SÉPARATEUR ÉLÉGANT "OU"
                      _buildOrDivider(),

                      const SizedBox(height: 16),

                      // TITRE MODULE ACHAT SANS COMPTE
                      _buildGuestBookingHeader(),

                      const SizedBox(height: 16),

                      // CARTE DE RECHERCHE FORMULAIRE
                      _buildSearchBookingCard(isMobile: false),

                      const SizedBox(height: 28),

                      // PILIERS DE RÉASSURANCE
                      _buildTrustBadgesRow(isMobile: false),

                      const SizedBox(height: 32),

                      // PIED DE PAGE LÉGAL
                      _buildLegalFooter(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // VOLET DROIT : DIGITAL DISPLAY / CONTENT SLIDESHOW (Auto-détecté)
        Expanded(
          child: DigitalDisplayWidget(
            onExploreDestinations: _showPopularDestinationsModal,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // DISPOSITION MOBILE & TABLETTE (< 960px)
  // ==========================================
  Widget _buildMobileLayout() {
    return SafeArea(
      child: Column(
        children: [
          // EN-TÊTE MOBILE : Logo aligné à gauche, Sélecteur multilingue aligné à droite
          _buildLeftPaneHeader(isMobile: true),

          // CONTENU SCROLLABLE MOBILE : Tous les autres éléments sont centrés
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ZONE D'ACCUEIL AVEC SLIDES EN ARRIÈRE-PLAN (Harmonie & Taille adéquate)
                  MobileHeroSlideZone(
                    onLogin: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    onRegister: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    onExploreDestinations: _showPopularDestinationsModal,
                  ),

                  // CARTE FORMULAIRE DE RECHERCHE MOBILE
                  _buildSearchBookingCard(isMobile: true),

                  const SizedBox(height: 18),

                  // PILIERS DE RÉASSURANCE CENTRÉS
                  _buildTrustBadgesRow(isMobile: true),

                  const SizedBox(height: 22),

                  // FOOTER ET MENTIONS LÉGALES CENTRÉS
                  _buildLegalFooter(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPOSANTS REUTILISABLES DE L'APPLICATION
  // ==========================================

  /// En-tête : Logo aligné à gauche, Sélecteur multilingue aligné à droite
  Widget _buildLeftPaneHeader({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 36,
        vertical: isMobile ? 14 : 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // GAUCHE : Bouton retour (si applicable) + Logo Dioufy-TS et Nom
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
                  tooltip: 'Retour',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                width: isMobile ? 42 : 46,
                height: isMobile ? 42 : 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 12),
              const Text(
                'DIOUFY-TS',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),

          // DROITE : Sélecteur multilingue & bascule de thème
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sélecteur de langue (FR ▾, WO, EN)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: PopupMenuButton<String>(
                  initialValue: _selectedLanguage,
                  tooltip: 'Changer la langue',
                  onSelected: (lang) => setState(() => _selectedLanguage = lang),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'FR', child: Text('Français (FR)', style: TextStyle(fontSize: 15))),
                    PopupMenuItem(value: 'WO', child: Text('Wolof (WO)', style: TextStyle(fontSize: 15))),
                    PopupMenuItem(value: 'EN', child: Text('English (EN)', style: TextStyle(fontSize: 15))),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedLanguage,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF475569)),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Bascule de thème
              IconButton(
                icon: Icon(
                  _isDarkMode ? Icons.light_mode_outlined : Icons.nightlight_round,
                  size: 22,
                  color: const Color(0xFF334155),
                ),
                tooltip: 'Mode sombre / clair',
                onPressed: () {
                  setState(() => _isDarkMode = !_isDarkMode);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Slogan : Typographie agrandie et style semi-bold italique, centré
  Widget _buildSloganSection({bool isMobile = false}) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 8 : 14,
      ),
      child: Text(
        '« ${AppConstants.appSlogan} »', // "Fo nek sa gare fek lafa"
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: isMobile ? 16.0 : 20.0,
          fontWeight: FontWeight.w600, // Semi-bold
          fontStyle: FontStyle.italic, // Italique
          color: const Color(0xFF1D4ED8), // Bleu Royal Dioufy
          letterSpacing: 0.2,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildWelcomeSection({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: isMobile ? 28 : 34,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.25,
            ),
            children: const [
              TextSpan(text: 'Bienvenue sur\n'),
              TextSpan(
                text: 'Dioufy-TS',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Réservez vos billets de bus en quelques clics et voyagez sereinement.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 16.0 : 17.5, // Lisibilité sans effort pour personnes âgées
            color: const Color(0xFF475569),
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButtonsRow({bool isMobile = false}) {
    return Row(
      children: [
        // BOUTON SE CONNECTER (Bleu primaire brillant avec libellé centré)
        Expanded(
          child: SizedBox(
            height: isMobile ? 52 : 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded, size: isMobile ? 19 : 21),
                      const SizedBox(width: 6),
                      Text(
                        'Se connecter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 15.0 : 16.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // BOUTON CRÉER UN COMPTE (Outlined pur avec libellé centré)
        Expanded(
          child: SizedBox(
            height: isMobile ? 52 : 52,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                foregroundColor: const Color(0xFF1D4ED8),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: isMobile ? 19 : 21, color: const Color(0xFF1D4ED8)),
                      const SizedBox(width: 6),
                      Text(
                        'Créer un compte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 14.5 : 15.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrDivider() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1.2)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OU',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1.2)),
      ],
    );
  }

  Widget _buildGuestBookingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Text(
          'Acheter un billet sans compte',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Recherchez votre trajet et réservez en toute simplicité',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBookingCard({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // RANGÉE 1 : DÉPART / SWAP / DESTINATION
          // Mobile : layout vertical (pleine largeur) pour éviter troncature
          // Desktop : layout horizontal avec swap au centre
          if (isMobile) ...[
            // Départ — pleine largeur
            _buildSelectorBox(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF1D4ED8),
              label: 'Départ',
              value: _departureCity,
              onTap: () => _selectCity(isDeparture: true),
            ),

            // Bouton Inverser villes ⇄ contrasté bleu roi Dioufy
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  onTap: _swapCities,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            // Destination — pleine largeur
            _buildSelectorBox(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF059669),
              label: 'Destination',
              value: _destinationCity,
              onTap: () => _selectCity(isDeparture: false),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildSelectorBox(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFF1D4ED8),
                    label: 'Départ',
                    value: _departureCity,
                    onTap: () => _selectCity(isDeparture: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: _swapCities,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildSelectorBox(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFF059669),
                    label: 'Destination',
                    value: _destinationCity,
                    onTap: () => _selectCity(isDeparture: false),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // RANGÉE 2 : DATE DE DÉPART / PASSAGERS
          Row(
            children: [
              // Date
              Expanded(
                child: _buildSelectorBox(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF475569),
                  label: 'Date',
                  value: _formatDisplayDate(_departureDate),
                  onTap: _pickDate,
                ),
              ),

              const SizedBox(width: 10),

              // Passagers
              Expanded(
                child: _buildSelectorBox(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF475569),
                  label: 'Passagers',
                  value: '$_passengerCount Passager${_passengerCount > 1 ? 's' : ''}',
                  onTap: _pickPassengers,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // BOUTON RECHERCHER UN TRAJET (Centré parfaitement et imposant)
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _handleSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.search_rounded, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Rechercher un trajet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  /// Piliers de réassurance : Centrés sur mobile pour un équilibre parfait
  Widget _buildTrustBadgesRow({bool isMobile = false}) {
    final items = [
      _TrustItem(
        icon: Icons.shield_outlined,
        title: 'Paiement sécurisé',
        desc: 'Wave, Orange Money & CB protégés à 100%',
      ),
      _TrustItem(
        icon: Icons.event_seat_outlined,
        title: 'Choix de siège',
        desc: 'Visualisez et choisissez votre place à bord',
      ),
      _TrustItem(
        icon: Icons.confirmation_number_outlined,
        title: 'Billet instantané',
        desc: 'Disponible hors-ligne par SMS et QR code',
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: items.map((item) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: const Color(0xFF1D4ED8), size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.0,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: const Color(0xFF1D4ED8), size: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        item.desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Footer et mentions légales : Centrés avec typographie agrandie
  Widget _buildLegalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '© 2025 Dioufy-TS. Tous droits réservés.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            InkWell(
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(
                  'Conditions d\'utilisation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(
                  'Confidentialité',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrustItem {
  final IconData icon;
  final String title;
  final String desc;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.desc,
  });
}
