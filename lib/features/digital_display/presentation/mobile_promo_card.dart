import 'dart:async';
import 'package:flutter/material.dart';
import '../models/slide_item.dart';
import '../services/digital_display_service.dart';

/// Carte promotionnelle compacte et contextuelle pour Mobile & Tablette.
/// Respecte les recommandations de sobriété mobile : non intrusive,
/// défilable, tactile et valorisant les nouveautés clés de Dioufy-TS.
class MobilePromoCard extends StatefulWidget {
  final VoidCallback? onTap;

  const MobilePromoCard({
    super.key,
    this.onTap,
  });

  @override
  State<MobilePromoCard> createState() => _MobilePromoCardState();
}

class _MobilePromoCardState extends State<MobilePromoCard> {
  late List<SlideItem> _slides;
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final next = (_currentIndex + 1) % _slides.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return InkWell(
                  onTap: widget.onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Arrière-plan avec photo assombrie
                      Opacity(
                        opacity: 0.28,
                        child: Image.asset(
                          slide.assetImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0F172A).withValues(alpha: 0.90),
                              const Color(0xFF1E3A8A).withValues(alpha: 0.75),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      slide.tag,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${slide.titlePrefix.replaceAll('\n', ' ')}${slide.titleHighlight}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    slide.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Color(0xFFFBBF24),
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Petits indicateurs de pagination discrets en bas au centre
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: _currentIndex == i ? 14 : 5,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? const Color(0xFF38BDF8)
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
