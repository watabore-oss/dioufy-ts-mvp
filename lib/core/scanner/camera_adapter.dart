import 'dart:async';
import 'scanner_models.dart';

/// Contrat d'abstraction matérielle découplant la capture vidéo du décodage métier.
abstract class CameraAdapter {
  ScannerState get currentState;
  bool get isTorchOn;
  bool get isInitialized;

  Stream<ScannerState> get stateStream;
  Stream<String> get rawDataStream;

  Future<void> initialize();
  Future<void> startScanning();
  Future<void> pauseScanning();
  Future<void> resumeScanning();
  Future<void> stopScanning();
  Future<void> toggleTorch();
  Future<void> setTorch(bool enable);
  Future<void> dispose();
}
