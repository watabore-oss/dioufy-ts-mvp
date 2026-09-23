import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Arrière-plan animé Cyber-Transport inspiré du site officiel dioufy-ts.sn
/// Affiche les corridors télématiques vivants, les impulsions de données GPS
/// et la silhouette vectorielle d'un car express en filigrane discret.
class DioufyLiveBackground extends StatefulWidget {
  final Widget child;
  final double busOpacity;

  const DioufyLiveBackground({
    super.key,
    required this.child,
    this.busOpacity = 0.08, // Opacité discrète qui laisse paraître le contenu par-dessus
  });

  @override
  State<DioufyLiveBackground> createState() => _DioufyLiveBackgroundState();
}

class _DioufyLiveBackgroundState extends State<DioufyLiveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return CustomPaint(
          painter: _DioufyCyberPainter(
            progress: _animController.value,
            busOpacity: widget.busOpacity,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _DioufyCyberPainter extends CustomPainter {
  final double progress;
  final double busOpacity;

  _DioufyCyberPainter({
    required this.progress,
    required this.busOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dégradé Bleu Royal Dioufy lumineux et institutionnel
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1D4ED8), // Bleu Royal Dioufy
          Color(0xFF1E3A8A), // Bleu Nuit
          Color(0xFF2563EB), // Bleu Azur
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Dessin de la silhouette de car en filigrane d'arrière-plan
    _paintBusWatermark(canvas, size);

    // 3. Corridors télématiques GPS en mouvement (Dakar, Thiès, Touba, Saint-Louis)
    _paintTelematicsNetwork(canvas, size);
  }

  /// Tracé vectoriel précis d'un car / bus express en filigrane (Watermark)
  void _paintBusWatermark(Canvas canvas, Size size) {
    final busPaint = Paint()
      ..color = Colors.white.withOpacity(busOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final busFillPaint = Paint()
      ..color = const Color(0xFF1E3A8A).withOpacity(busOpacity * 0.4)
      ..style = PaintingStyle.fill;

    // Positionnement au tiers supérieur de l'en-tête, occupant ~80% de la largeur
    final double busWidth = math.min(size.width * 0.85, 340.0);
    final double busHeight = busWidth * 0.38;
    final double left = (size.width - busWidth) / 2;
    final double top = size.height * 0.12;

    // A. Carrosserie du Car
    final bodyPath = Path();
    bodyPath.moveTo(left + 20, top); // Toit avant
    bodyPath.lineTo(left + busWidth - 10, top); // Toit jusqu'à l'arrière
    bodyPath.quadraticBezierTo(left + busWidth, top, left + busWidth, top + 15); // Arrondi toit arrière
    bodyPath.lineTo(left + busWidth, top + busHeight - 16); // Face arrière
    bodyPath.quadraticBezierTo(left + busWidth, top + busHeight, left + busWidth - 15, top + busHeight); // Bas arrière
    bodyPath.lineTo(left + busWidth * 0.78, top + busHeight); // Avant roue arrière

    // Passage roue arrière
    bodyPath.arcToPoint(
      Offset(left + busWidth * 0.62, top + busHeight),
      radius: const Radius.circular(18),
      clockwise: false,
    );

    bodyPath.lineTo(left + busWidth * 0.38, top + busHeight); // Entre-roues

    // Passage roue avant
    bodyPath.arcToPoint(
      Offset(left + busWidth * 0.22, top + busHeight),
      radius: const Radius.circular(18),
      clockwise: false,
    );

    bodyPath.lineTo(left + 15, top + busHeight); // Bas avant
    bodyPath.quadraticBezierTo(left, top + busHeight, left, top + busHeight - 20); // Calandre basse
    bodyPath.lineTo(left, top + 35); // Calandre haute
    bodyPath.quadraticBezierTo(left + 2, top + 10, left + 20, top); // Pare-brise profilé avant
    bodyPath.close();

    canvas.drawPath(bodyPath, busFillPaint);
    canvas.drawPath(bodyPath, busPaint);

    // B. Rangée de vitres teintées du car
    final windowPaint = Paint()
      ..color = const Color(0xFF00B2FE).withOpacity(busOpacity * 0.9)
      ..style = PaintingStyle.fill;

    final windowBorderPaint = Paint()
      ..color = Colors.white.withOpacity(busOpacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double winTop = top + 8;
    final double winHeight = busHeight * 0.35;

    // Pare-brise avant
    final frontWin = Path()
      ..moveTo(left + 18, winTop)
      ..lineTo(left + 50, winTop)
      ..lineTo(left + 50, winTop + winHeight)
      ..lineTo(left + 6, winTop + winHeight)
      ..quadraticBezierTo(left + 6, winTop + 18, left + 18, winTop)
      ..close();
    canvas.drawPath(frontWin, windowPaint);
    canvas.drawPath(frontWin, windowBorderPaint);

    // 5 fenêtres latérales passagers
    for (int i = 0; i < 5; i++) {
      final double winLeft = left + 56 + (i * (busWidth * 0.135));
      final winRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(winLeft, winTop, busWidth * 0.12, winHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(winRect, windowPaint);
      canvas.drawRRect(winRect, windowBorderPaint);
    }

    // C. Roues avec jantes stylisées
    final wheelPaint = Paint()
      ..color = Colors.white.withOpacity(busOpacity * 1.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Roue avant
    final centerFront = Offset(left + busWidth * 0.30, top + busHeight);
    canvas.drawCircle(centerFront, 13, wheelPaint);
    canvas.drawCircle(centerFront, 5, busPaint);

    // Roue arrière
    final centerBack = Offset(left + busWidth * 0.70, top + busHeight);
    canvas.drawCircle(centerBack, 13, wheelPaint);
    canvas.drawCircle(centerBack, 5, busPaint);

    // D. Ligne de bas de caisse aérodynamique or / cyan
    final stripePaint = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(busOpacity * 1.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(left + 4, top + busHeight * 0.75),
      Offset(left + busWidth - 4, top + busHeight * 0.75),
      stripePaint,
    );
  }

  /// Réseau de corridors télématiques animés reliant Dakar, Thiès, Touba, Saint-Louis
  void _paintTelematicsNetwork(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final pulsePaint = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Coordonnées relatives des pôles
    final dakar = Offset(size.width * 0.12, size.height * 0.42);
    final thies = Offset(size.width * 0.36, size.height * 0.38);
    final touba = Offset(size.width * 0.72, size.height * 0.32);
    final stLouis = Offset(size.width * 0.65, size.height * 0.16);

    // Lignes géodésiques reliant les villes
    final corridor1 = Path()
      ..moveTo(dakar.dx, dakar.dy)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.40, thies.dx, thies.dy);

    final corridor2 = Path()
      ..moveTo(thies.dx, thies.dy)
      ..quadraticBezierTo(size.width * 0.54, size.height * 0.35, touba.dx, touba.dy);

    final corridor3 = Path()
      ..moveTo(thies.dx, thies.dy)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.22, stLouis.dx, stLouis.dy);

    canvas.drawPath(corridor1, routePaint);
    canvas.drawPath(corridor2, routePaint);
    canvas.drawPath(corridor3, routePaint);

    // Halos radar pulsants autour des pôles
    final double pulseRadius = 6 + (progress * 10);
    final double pulseAlpha = (1.0 - progress).clamp(0.0, 1.0) * 0.4;
    final ringPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(dakar, pulseRadius, ringPaint);
    canvas.drawCircle(thies, pulseRadius, ringPaint);
    canvas.drawCircle(touba, pulseRadius, ringPaint);

    // Points fixes des gares
    final nodePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dakar, 3.5, nodePaint);
    canvas.drawCircle(thies, 4.0, nodePaint);
    canvas.drawCircle(touba, 3.5, nodePaint);
    canvas.drawCircle(stLouis, 3.0, nodePaint);

    // Paquets de données GPS circulant sur les corridors en temps réel
    final packetDakarThies = Offset(
      dakar.dx + (thies.dx - dakar.dx) * progress,
      dakar.dy + (thies.dy - dakar.dy) * progress,
    );
    canvas.drawCircle(packetDakarThies, 3.0, pulsePaint);

    final double delayedProgress = (progress + 0.4) % 1.0;
    final packetThiesTouba = Offset(
      thies.dx + (touba.dx - thies.dx) * delayedProgress,
      thies.dy + (touba.dy - thies.dy) * delayedProgress,
    );
    canvas.drawCircle(packetThiesTouba, 2.8, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _DioufyCyberPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.busOpacity != busOpacity;
  }
}
