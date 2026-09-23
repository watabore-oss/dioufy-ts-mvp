import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'camera_adapter.dart';
import 'scanner_models.dart';

/// Implémentation native haute performance (CameraX Android / AVFoundation iOS).
class NativeCameraAdapter implements CameraAdapter {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
    returnImage: false,
  );

  final _stateController = StreamController<ScannerState>.broadcast();
  final _rawBarcodeController = StreamController<String>.broadcast();

  ScannerState _state = ScannerState.uninitialized;
  bool _torchOn = false;
  StreamSubscription? _sub;

  @override
  ScannerState get currentState => _state;

  @override
  bool get isTorchOn => _torchOn;

  @override
  bool get isInitialized => _state != ScannerState.uninitialized;

  @override
  Stream<ScannerState> get stateStream => _stateController.stream;

  @override
  Stream<String> get rawDataStream => _rawBarcodeController.stream;

  MobileScannerController get controller => _controller;

  @override
  Future<void> initialize() async {
    _setState(ScannerState.initializing);
    try {
      _sub = _controller.barcodes.listen((capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _rawBarcodeController.add(raw);
          }
        }
      });
      _setState(ScannerState.ready);
    } catch (_) {
      _setState(ScannerState.error);
    }
  }

  @override
  Future<void> startScanning() async {
    if (_state == ScannerState.scanning) return;
    try {
      await _controller.start();
      _setState(ScannerState.scanning);
    } catch (_) {
      _setState(ScannerState.error);
    }
  }

  @override
  Future<void> pauseScanning() async {
    try {
      await _controller.stop();
      _setState(ScannerState.paused);
    } catch (_) {}
  }

  @override
  Future<void> resumeScanning() async {
    try {
      await _controller.start();
      _setState(ScannerState.scanning);
    } catch (_) {}
  }

  @override
  Future<void> stopScanning() async {
    try {
      await _controller.stop();
      _setState(ScannerState.ready);
    } catch (_) {}
  }

  @override
  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
      _torchOn = !_torchOn;
    } catch (_) {}
  }

  @override
  Future<void> setTorch(bool enable) async {
    try {
      if (enable != _torchOn) {
        await _controller.toggleTorch();
        _torchOn = enable;
      }
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.dispose();
    await _stateController.close();
    await _rawBarcodeController.close();
  }

  void _setState(ScannerState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
