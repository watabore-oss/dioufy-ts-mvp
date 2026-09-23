import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'feature_flag_service.dart';

/// Widget Guard empêchant l'accès à un écran/module inactif et évitant tout écran blanc
class FeatureGuard extends StatelessWidget {
  final String flagKey;
  final Widget child;
  final Widget? fallback;
  final String? featureName;

  const FeatureGuard({
    super.key,
    required this.flagKey,
    required this.child,
    this.fallback,
    this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = FeatureFlagService.instance.isEnabled(flagKey);

    if (isEnabled) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    // Écran de repli élégant conforme aux règles (Mobile-First & Bouton Retour)
    return Scaffold(
      backgroundColor: DioufyColors.backgroundLight,
      appBar: AppBar(
        title: Text(featureName ?? 'Module en cours de déploiement'),
        backgroundColor: DioufyColors.primaryDark,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DioufyColors.primaryDark.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction,
                  size: 36,
                  color: DioufyColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                featureName ?? 'Fonctionnalité temporairement désactivée',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DioufyColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ce module est en cours de déploiement progressif ou de maintenance technique selon la feuille de route.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              if (Navigator.canPop(context))
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour à la page précédente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DioufyColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
