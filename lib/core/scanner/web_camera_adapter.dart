import 'dart:async';
import 'camera_adapter.dart';
import 'scanner_models.dart';

/// Implémentation de repli Web / Navigateur pour le scanner de billets.
class WebCameraAdapter implements CameraAdapter {
  final _stateController = StreamController<ScannerState>.broadcast();
  final _rawBarcodeController = StreamController<String>.broadcast();

  ScannerState _state = ScannerState.uninitialized;
  bool _torchOn = false;

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

  @override
  Future<void> initialize() async {
    _setState(ScannerState.initializing);
    try {
      // Sur le web, la permission caméra est demandée par le navigateur
      await Future.delayed(const Duration(milliseconds: 150));
      _setState(ScannerState.ready);
    } catch (e) {
      _setState(ScannerState.error);
    }
  }

  @override
  Future<void> startScanning() async {
    if (_state == ScannerState.scanning) return;
    _setState(ScannerState.scanning);
  }

  @override
  Future<void> pauseScanning() async {
    _setState(ScannerState.paused);
  }

  @override
  Future<void> resumeScanning() async {
    _setState(ScannerState.scanning);
  }

  @override
  Future<void> stopScanning() async {
    _setState(ScannerState.ready);
  }

  @override
  Future<void> toggleTorch() async {
    // La torche n'est généralement pas supportée directement sur le web sans MediaStreamTrack avancé
    _torchOn = !_torchOn;
  }

  @override
  Future<void> setTorch(bool enable) async {
    _torchOn = enable;
  }

  /// Injecte manuellement un code scanné (par ex via dialogue de fichier ou test)
  void injectRawCode(String rawCode) {
    if (!_rawBarcodeController.isClosed && rawCode.isNotEmpty) {
      _rawBarcodeController.add(rawCode.trim());
    }
  }

  @override
  Future<void> dispose() async {
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
