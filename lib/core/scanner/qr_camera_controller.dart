import 'dart:async';

/// Orientation de la caméra de visée
enum QrCameraFacing { back, front }

/// Abstraction unique du contrôleur de caméra optique (Standard Industriel)
/// Découple totalement l'UI Flutter de l'environnement d'exécution (CameraX / HTML5 MediaStream / iOS Safari)
abstract class QrCameraController {
  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> switchCamera();
  Future<void> toggleTorch();
  Future<String?> capturePhoto();

  bool get isTorchSupported;
  bool get isTorchOn;
  bool get canSwitchCamera;
  QrCameraFacing get currentFacing;

  Stream<String> get onCodeDetected;
  Stream<String> get onError;
  void dispose();
}
