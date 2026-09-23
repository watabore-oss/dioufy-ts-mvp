import 'dart:async';

/// Processeur de flux de frames vidéo avec cadencement adaptatif (Throttling)
/// Conçu pour réguler la charge CPU et la température de la batterie sur Android/iOS.
class FrameProcessor {
  final Duration minFrameInterval;
  DateTime _lastProcessedTime = DateTime.fromMillisecondsSinceEpoch(0);
  final StreamController<String> _processedOutput = StreamController<String>.broadcast();

  FrameProcessor({
    this.minFrameInterval = const Duration(milliseconds: 60), // ~16 FPS max
  });

  Stream<String> get stream => _processedOutput.stream;

  /// Reçoit une frame brute ou un code détecté et applique la régulation temporelle
  bool process(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;

    final now = DateTime.now();
    if (now.difference(_lastProcessedTime) < minFrameInterval) {
      // Frame ignorée pour soulager le processeur
      return false;
    }

    _lastProcessedTime = now;
    if (!_processedOutput.isClosed) {
      _processedOutput.add(raw.trim());
    }
    return true;
  }

  void dispose() {
    _processedOutput.close();
  }
}
