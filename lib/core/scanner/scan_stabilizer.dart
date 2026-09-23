/// Stabilisateur multi-frames et filtre anti-rebond pour le scanner de billets Dioufy-TS
class ScanStabilizer {
  final int requiredConsecutiveMatches;
  final Duration postScanCooldown;
  final Duration minFrameInterval;

  String? _candidateValue;
  int _consecutiveMatches = 0;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastScanSuccessTime = DateTime.fromMillisecondsSinceEpoch(0);

  ScanStabilizer({
    this.requiredConsecutiveMatches = 2,
    this.postScanCooldown = const Duration(milliseconds: 800),
    this.minFrameInterval = const Duration(milliseconds: 60),
  });

  /// Alias compatible pour processCandidate
  String? processFrame(String? rawValue) => processCandidate(rawValue);

  /// Traite une valeur reçue d'une frame vidéo.
  /// Retourne la valeur stabilisée uniquement lorsque [requiredConsecutiveMatches] consécutives concordent.
  String? processCandidate(String? rawValue) {
    final now = DateTime.now();

    // 1. Période de refroidissement post-scan : bloque les rafales involontaires
    if (now.difference(_lastScanSuccessTime) < postScanCooldown) {
      return null;
    }

    // 2. Cadencement minimal entre deux frames
    if (now.difference(_lastFrameTime) < minFrameInterval) {
      return null;
    }
    _lastFrameTime = now;

    if (rawValue == null || rawValue.trim().isEmpty) {
      _candidateValue = null;
      _consecutiveMatches = 0;
      return null;
    }

    final cleanValue = rawValue.trim();

    // 2. Stabilisation multi-frames : 2 lectures identiques consécutives requises
    if (cleanValue == _candidateValue) {
      _consecutiveMatches++;
    } else {
      _candidateValue = cleanValue;
      _consecutiveMatches = 1;
    }

    if (_consecutiveMatches >= requiredConsecutiveMatches) {
      _lastScanSuccessTime = now;
      _candidateValue = null;
      _consecutiveMatches = 0;
      return cleanValue;
    }

    return null;
  }

  /// Valide directement une valeur fixe (upload galerie ou saisie clavier)
  /// sans imposer le filtre multi-frames conçu pour la vidéo.
  String? processDirectValue(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;
    final cleanValue = rawValue.trim();
    _lastScanSuccessTime = DateTime.now();
    _candidateValue = null;
    _consecutiveMatches = 0;
    return cleanValue;
  }

  /// Réinitialise l'état du stabilisateur
  void reset() {
    _candidateValue = null;
    _consecutiveMatches = 0;
  }

  bool get hasCandidate => _candidateValue != null;
  int get candidateMatches => _consecutiveMatches;
}
