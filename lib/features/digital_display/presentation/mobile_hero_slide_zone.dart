import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../models/slide_item.dart';
import '../services/digital_display_service.dart';

/// Zone d'accueil mobile avec carrousel de slides immersif en arrière-plan.
/// 
/// Fusionne harmonieusement :
/// - Les diapositives en arrière-plan plein cadre (hauteur adéquate et BoxFit.cover)
/// - Un filtre dégradé semi-transparent garantissant un contraste parfait et la lisibilité du texte
/// - Le slogan wolof en or Dioufy étincelant
/// - Le titre d'accueil "Bienvenue sur Dioufy-TS"
/// - Les boutons d'accès rapide (Connexion / Inscription)
/// - Le séparateur élégant "OU"
/// - L'en-tête du module "Acheter un billet sans compte"
/// - Des indicateurs discrets de pagination de slides
class MobileHeroSlideZone extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback? onExploreDestinations;
  final String? slogan;

  const MobileHeroSlideZone({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.onExploreDestinations,
    this.slogan,
  });

  @override
  State<MobileHeroSlideZone> createState() => _MobileHeroSlideZoneState();
}

class _MobileHeroSlideZoneState extends State<MobileHeroSlideZone> {
  late List<SlideItem> _slides;
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _slides = DigitalDisplayService.instance.getSlides();
    _pageController = PageController();
    _startTimer();
    _loadAutoDetectedSlides();
  }

  Future<void> _loadAutoDetectedSlides() async {
    final autoSlides = await DigitalDisplayService.instance.loadAutoDetectedSlides();
    if (mounted && autoSlides.isNotEmpty) {
      setState(() {
        _slides = autoSlides;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    _autoSlideTimer?.cancel();
    if (_slides.length <= 1) return;

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final nextIndex = (_currentIndex + 1) % _slides.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _goToSlide(int index) {
    if (index >= 0 && index < _slides.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides.isNotEmpty ? _slides[_currentIndex] : null;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 540),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // =================================================================
            // 1. CARROUSEL D'IMAGES EN ARRIÈRE-PLAN (Taille adéquate & Couverture)
            // =================================================================
            Positioned.fill(
              child: _slides.isEmpty
                  ? const SizedBox.shrink()
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (i) {
                        setState(() => _currentIndex = i);
                        // Réinitialiser le timer après interaction manuelle
                        _startTimer();
                      },
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return Image.asset(
                          slide.assetImage,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_bus_rounded,
                                size: 80,
                                color: Color(0x33FBBF24),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // =================================================================
            // 2. VOILE DÉGRADÉ MULTI-NIVEAU (Harmonie, Profondeur & Lisibilité)
            // =================================================================
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0F172A).withValues(alpha: 0.82), // Sombre en haut pour le slogan & titre
                      const Color(0xFF0F172A).withValues(alpha: 0.58), // Plus aéré au centre pour valoriser la photo
                      const Color(0xFF0B132B).withValues(alpha: 0.88), // Sombre en bas pour boutons & intro recherche
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Vignette latérale subtile pour adoucir les contours
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.20),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
            ),

            // =================================================================
            // 3. CONTENU AU PREMIER PLAN
            // =================================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slogan Wolof valorisé en Or Dioufy
                  Text(
                    '« ${widget.slogan ?? AppConstants.appSlogan} »',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFFBBF24), // Or éclatant Dioufy
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Badge contextuel du slide actif (cliquable pour explorer)
                  if (currentSlide != null)
                    GestureDetector(
                      onTap: widget.onExploreDestinations,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              size: 13,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              currentSlide.tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Titre de bienvenue contrasté
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 27,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.25,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1.5)),
                        ],
                      ),
                      children: [
                        TextSpan(text: 'Bienvenue sur\n'),
                        TextSpan(
                          text: 'Dioufy-TS',
                          style: TextStyle(
                            color: Color(0xFF38BDF8), // Bleu ciel lumineux
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Sous-titre lisible
                  const Text(
                    'Réservez vos billets de bus en quelques clics et voyagez sereinement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.0,
                      color: Color(0xFFF1F5F9),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Boutons d'action rapides (Connexion & Inscription)
                  Row(
                    children: [
                      // Se connecter
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: widget.onLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 19),
                                    SizedBox(width: 6),
                                    Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        fontSize: 15.0,
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

                      // Créer un compte
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: widget.onRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1D4ED8),
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: Color(0xFF38BDF8),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 19,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Créer un compte',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1D4ED8),
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
                  ),

                  const SizedBox(height: 14),

                  // Séparateur "OU" harmonieux
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.35),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OU',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.35),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Titre du module d'achat sans compte
                  const Text(
                    'Acheter un billet sans compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Recherchez votre trajet et réservez en toute simplicité',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE2E8F0),
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Indicateurs de diapositives discrets (Pastilles de pagination)
                  if (_slides.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final isActive = _currentIndex == i;
                        return GestureDetector(
                          onTap: () => _goToSlide(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 20 : 6,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
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
