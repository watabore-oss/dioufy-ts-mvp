import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/slide_item.dart';
import '../services/digital_display_service.dart';

/// Widget Digital Display Desktop & Grand Écran pour Dioufy-TS.
/// Conçu pour fonctionner de façon permanente sur desktop et s'adapter
/// contextuellement au rôle de l'utilisateur (Voyageur, Chauffeur, GIE, Coxeur, Admin).
///
/// Intègre un mode "Focus" permettant de mettre en pause les animations
/// et d'estomper les slides lors des opérations sensibles (clôture de caisse, régulation).
class DigitalDisplayWidget extends StatefulWidget {
  final List<SlideItem>? slides;
  final VoidCallback? onExploreDestinations;
  final VoidCallback? onToggleFocusMode;
  final bool isFocusMode;

  const DigitalDisplayWidget({
    super.key,
    this.slides,
    this.onExploreDestinations,
    this.onToggleFocusMode,
    this.isFocusMode = false,
  });

  @override
  State<DigitalDisplayWidget> createState() => _DigitalDisplayWidgetState();
}

class _DigitalDisplayWidgetState extends State<DigitalDisplayWidget> {
  late List<SlideItem> _slides;
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSlideTimer;
  bool _isHovered = false;
  late bool _internalFocusMode;

  @override
  void initState() {
    super.initState();
    _internalFocusMode = widget.isFocusMode;
    _slides = widget.slides ?? DigitalDisplayService.instance.getSlides();
    _pageController = PageController();
    if (!_internalFocusMode) {
      _startTimer();
    }
    if (widget.slides == null) {
      _loadAutoDetectedSlides();
    }
  }

  Future<void> _loadAutoDetectedSlides() async {
    final autoSlides = await DigitalDisplayService.instance.loadAutoDetectedSlides();
    if (mounted && autoSlides.isNotEmpty && widget.slides == null) {
      setState(() {
        _slides = autoSlides;
      });
      if (!_internalFocusMode) {
        _startTimer();
      }
    }
  }

  @override
  void didUpdateWidget(covariant DigitalDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocusMode != oldWidget.isFocusMode) {
      setState(() {
        _internalFocusMode = widget.isFocusMode;
        if (_internalFocusMode) {
          _autoSlideTimer?.cancel();
        } else {
          _startTimer();
        }
      });
    }

    if (widget.slides != null && widget.slides != oldWidget.slides) {
      setState(() {
        _slides = widget.slides!;
        if (_currentIndex >= _slides.length) {
          _currentIndex = 0;
        }
      });
      if (!_internalFocusMode) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _autoSlideTimer?.cancel();
    if (_internalFocusMode || _slides.length <= 1) return;

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!_isHovered && mounted && !_internalFocusMode) {
        final nextIndex = (_currentIndex + 1) % _slides.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _goToSlide(int index) {
    if (index >= 0 && index < _slides.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousSlide() {
    if (_slides.isEmpty) return;
    final prevIndex = (_currentIndex - 1 + _slides.length) % _slides.length;
    _goToSlide(prevIndex);
  }

  void _nextSlide() {
    if (_slides.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _slides.length;
    _goToSlide(nextIndex);
  }

  void _toggleFocus() {
    if (widget.onToggleFocusMode != null) {
      widget.onToggleFocusMode!();
    } else {
      setState(() {
        _internalFocusMode = !_internalFocusMode;
        if (_internalFocusMode) {
          _autoSlideTimer?.cancel();
        } else {
          _startTimer();
        }
      });
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
    if (_slides.isEmpty) return const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _internalFocusMode ? 0.35 : 1.0,
        child: Container(
          color: const Color(0xFF0F172A),
          child: Stack(
            children: [
              // 1. CARROUSEL D'IMAGES PLEIN ÉCRAN
              PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image d'arrière-plan avec fallback
                      Image.asset(
                        slide.assetImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_bus_rounded,
                                size: 100,
                                color: Color(0x33FBBF24),
                              ),
                            ),
                          );
                        },
                      ),

                      // Voile dégradé sombre directionnel (contraste élevé et lisibilité garantie)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0B132B).withValues(alpha: 0.65),
                              const Color(0xFF0B132B).withValues(alpha: 0.40),
                              const Color(0xFF0B132B).withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),

                      // Voile latéral doux pour détacher le texte à gauche
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFF0F172A).withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.70],
                          ),
                        ),
                      ),

                      // CONTENU DU SLIDE
                      Positioned.fill(
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 36,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 50),

                                // BADGE (ex: NOUVEAU, SÉCURITÉ ROUTIÈRE, PILOTAGE FLOTTE)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    slide.tag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // GRAND TITRE AVEC MOT EN DORÉ ÉCLATANT
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 40,
                                      height: 1.15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.8,
                                    ),
                                    children: [
                                      TextSpan(text: slide.titlePrefix),
                                      TextSpan(
                                        text: slide.titleHighlight,
                                        style: const TextStyle(
                                          color: Color(0xFFFBBF24), // Or Dioufy
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // SOUS-TITRE LISIBLE
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  child: Text(
                                    slide.subtitle,
                                    style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontSize: 16,
                                      height: 1.45,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // BOUTON GLASSMORPHISM CTA
                                InkWell(
                                  onTap: widget.onExploreDestinations,
                                  borderRadius: BorderRadius.circular(30),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Text(
                                          slide.ctaText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // 2. EN-TÊTE SUPÉRIEUR : BOUTON FOCUS & INDICATEURS DE PAGINATION
              Positioned(
                top: 32,
                left: 36,
                right: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bouton Mode Focus (suggestion d'expert pour les opérations sensibles)
                    InkWell(
                      onTap: _toggleFocus,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _internalFocusMode
                                ? const Color(0xFFFBBF24)
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _internalFocusMode
                                  ? Icons.center_focus_strong
                                  : Icons.visibility_outlined,
                              size: 15,
                              color: _internalFocusMode
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _internalFocusMode ? 'Mode Focus Actif' : 'Mode Focus',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _internalFocusMode
                                    ? const Color(0xFFFBBF24)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pastilles de pagination
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_slides.length, (index) {
                        final isActive = _currentIndex == index;
                        return GestureDetector(
                          onTap: () => _goToSlide(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                                        blurRadius: 8,
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

              // 3. FLÈCHES DIRECTIONNELLES LATÉRALES (< et >)
              if (_slides.length > 1) ...[
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildCircleNavButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: _previousSlide,
                      tooltip: 'Précédent',
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildCircleNavButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: _nextSlide,
                      tooltip: 'Suivant',
                    ),
                  ),
                ),
              ],

              // 4. BARRE INFÉRIEURE FLOTTANTE AVEC 3 ATOUTS (FROSTED GLASS)
              Positioned(
                left: 36,
                right: 36,
                bottom: 28,
                child: _buildFloatingFeatureBar(_slides[_currentIndex]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingFeatureBar(SlideItem slide) {
    if (slide.features.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: slide.features.map((feature) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: feature.iconBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          feature.icon,
                          color: feature.iconColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              feature.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feature.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
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
          ),
        ),
      ),
    );
  }
}
