import 'package:flutter/widgets.dart';

/// Contrôleur dédié à la gestion du cycle de vie du capteur caméra (CameraX / AVFoundation).
/// Libère le capteur matériel dès la mise en veille/arrière-plan et le réactive proprement en premier plan.
class CameraLifecycleController with WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback onPause;
  final VoidCallback? onDispose;

  bool _isObserving = false;

  CameraLifecycleController({
    required this.onResume,
    required this.onPause,
    this.onDispose,
  });

  /// Démarre l'écoute des événements du cycle de vie système Android/iOS
  void start() {
    if (!_isObserving) {
      WidgetsBinding.instance.addObserver(this);
      _isObserving = true;
    }
  }

  /// Arrête l'écoute du cycle de vie
  void stop() {
    if (_isObserving) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserving = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // L'application revient au premier plan : réactivation propre de la caméra
        onResume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // L'application passe en arrière-plan (ex: appel entrant, minimisation) : libération du capteur
        onPause();
        break;
      case AppLifecycleState.detached:
        // Destruction complète de l'activité
        onDispose?.call();
        break;
    }
  }
}
