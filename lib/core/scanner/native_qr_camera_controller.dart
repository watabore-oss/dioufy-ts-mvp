import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'qr_camera_controller.dart';

/// Implémentation native CameraX (Android) / AVFoundation (iOS)
class NativeQrCameraController implements QrCameraController {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoStart: false,
  );

  final _codeController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  StreamSubscription<BarcodeCapture>? _subscription;

  bool _isTorchOn = false;
  QrCameraFacing _facing = QrCameraFacing.back;

  MobileScannerController get mobileScannerController => _controller;

  @override
  bool get isTorchSupported =>
      _controller.value.torchState != TorchState.unavailable;

  @override
  bool get isTorchOn => _isTorchOn;

  @override
  bool get canSwitchCamera => true;

  @override
  QrCameraFacing get currentFacing => _facing;

  @override
  Stream<String> get onCodeDetected => _codeController.stream;

  @override
  Stream<String> get onError => _errorController.stream;

  @override
  Future<void> initialize() async {
    _subscription = _controller.barcodes.listen((capture) {
      for (final barcode in capture.barcodes) {
        final val = barcode.rawValue;
        if (val != null && val.trim().isNotEmpty) {
          _codeController.add(val.trim());
        }
      }
    });
  }

  @override
  Future<void> start() async {
    try {
      await _controller.start();
    } catch (e) {
      _errorController.add("Erreur d'activation caméra : $e");
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  @override
  Future<void> switchCamera() async {
    try {
      await _controller.switchCamera();
      _facing = _facing == QrCameraFacing.back
          ? QrCameraFacing.front
          : QrCameraFacing.back;
    } catch (e) {
      _errorController.add("Impossible de basculer la caméra : $e");
    }
  }

  @override
  Future<void> toggleTorch() async {
    if (!isTorchSupported) return;
    try {
      await _controller.toggleTorch();
      _isTorchOn = !_isTorchOn;
    } catch (e) {
      _errorController.add("Erreur lampe torche : $e");
    }
  }

  @override
  Future<String?> capturePhoto() async {
    // Sur natif, la détection vidéo en continu est la méthode nominale
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _codeController.close();
    _errorController.close();
    _controller.dispose();
  }
}
