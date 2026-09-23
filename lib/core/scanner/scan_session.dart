/// Session de contrôle et d'embarquement avec déduplication instantanée en mémoire (RAM)
class ScanSession {
  final String sessionId;
  final DateTime startedAt;
  final Duration timeout;
  final Set<String> _processedValues;

  ScanSession({
    String? sessionId,
    DateTime? startedAt,
    this.timeout = const Duration(minutes: 120),
    Set<String>? initialProcessed,
  })  : sessionId = sessionId ?? 'SESS-${DateTime.now().millisecondsSinceEpoch}',
        startedAt = startedAt ?? DateTime.now(),
        _processedValues = initialProcessed != null
            ? Set<String>.from(initialProcessed)
            : <String>{};

  /// Vérifie si ce billet ou QR a déjà été scanné dans cette session d'embarquement
  bool isProcessed(String value) {
    return _processedValues.contains(value.trim());
  }

  /// Enregistre un billet comme validé dans la session
  bool registerProcessed(String value) {
    return _processedValues.add(value.trim());
  }

  /// Alias de registerProcessed pour marquer un billet comme traité
  bool markProcessed(String value) => registerProcessed(value);

  /// Nombre total de billets validés durant cette session
  int get processedCount => _processedValues.length;

  /// Indique si la session a expiré
  bool get isExpired => DateTime.now().difference(startedAt) > timeout;

  /// Réinitialise l'historique de la session
  void clear() => _processedValues.clear();
}
