import 'package:flutter/widgets.dart';

/// Utilitaire de projection géométrique entre l'espace de coordonnées de l'UI
/// et l'espace de coordonnées du capteur de capture caméra.
class CoordinateTransformer {
  /// Calcule la zone de visée normalisée et centrée pour l'écran
  static Rect computeScanWindow({
    required Size screenSize,
    double widthFactor = 0.72,
    double minSize = 220.0,
    double maxSize = 320.0,
    double verticalOffset = -30.0,
  }) {
    final scanDimension = (screenSize.width * widthFactor).clamp(minSize, maxSize);
    return Rect.fromCenter(
      center: Offset(
        screenSize.width / 2,
        (screenSize.height / 2) + verticalOffset,
      ),
      width: scanDimension,
      height: scanDimension,
    );
  }

  /// Vérifie si un point d'impact de tap ou de coordonnées est à l'intérieur de la fenêtre de scan
  static bool isInsideScanWindow(Offset point, Rect scanWindow) {
    return scanWindow.contains(point);
  }
}
