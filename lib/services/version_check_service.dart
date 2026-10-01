import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Résultat d'une vérification de version d'application
class VersionCheckResult {
  final bool isUpdateRequired;
  final bool isUpdateRecommended;
  final String currentVersion;
  final String latestVersion;
  final String minimumSupportedVersion;
  final String storeUrl;
  final String? releaseNotes;

  const VersionCheckResult({
    required this.isUpdateRequired,
    required this.isUpdateRecommended,
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.storeUrl,
    this.releaseNotes,
  });
}

/// Service de gouvernance applicative et de mise à jour forcée Dioufy-TS
class VersionCheckService {
  static const String currentAppVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static VersionCheckService? _instance;
  VersionCheckResult? _lastResult;

  VersionCheckService._();

  static VersionCheckService get instance {
    _instance ??= VersionCheckService._();
    return _instance!;
  }

  VersionCheckResult? get lastResult => _lastResult;

  /// Vérifie la version auprès de la table `app_releases` dans Supabase
  Future<VersionCheckResult?> checkVersion() async {
    try {
      final client = Supabase.instance.client;
      final platformStr = _detectPlatform();

      final response = await client
          .from('app_releases')
          .select()
          .or('platform.eq.$platformStr,platform.eq.all')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 3500));

      if (response == null) return null;

      final latestVer = response['latest_version']?.toString() ?? '1.0.0';
      final minVer = response['minimum_supported_version']?.toString() ?? '1.0.0';
      final forceFlag = response['update_required'] as bool? ?? false;
      final storeUrl = response['store_url']?.toString() ??
          'https://play.google.com/store/apps/details?id=com.dioufy.transport';
      final notes = response['release_notes']?.toString();

      final cmpMin = _compareSemver(currentAppVersion, minVer);
      final cmpLatest = _compareSemver(currentAppVersion, latestVer);

      final isRequired = forceFlag || (cmpMin < 0);
      final isRecommended = !isRequired && (cmpLatest < 0);

      _lastResult = VersionCheckResult(
        isUpdateRequired: isRequired,
        isUpdateRecommended: isRecommended,
        currentVersion: currentAppVersion,
        latestVersion: latestVer,
        minimumSupportedVersion: minVer,
        storeUrl: storeUrl,
        releaseNotes: notes,
      );

      return _lastResult;
    } catch (e) {
      debugPrint('Vérification de version ignorée (mode hors-ligne): $e');
      return null;
    }
  }

  /// Détecte la plateforme d'exécution
  String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'all';
    }
  }

  /// Compare deux chaînes sémantiques (Semver) MAJOR.MINOR.PATCH
  /// Retourne -1 si v1 < v2, 0 si v1 == v2, 1 si v1 > v2
  int _compareSemver(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (parts1.length < 3) {
        parts1.add(0);
      }
      while (parts2.length < 3) {
        parts2.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (parts1[i] < parts2[i]) return -1;
        if (parts1[i] > parts2[i]) return 1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  bool _dialogShown = false;

  /// Affiche le dialogue de mise à jour bloquante ou recommandée
  void showUpdateDialogIfNeeded(BuildContext context) {
    if (_dialogShown) return;
    final result = _lastResult;
    if (result == null) return;

    if (result.isUpdateRequired) {
      _dialogShown = true;
      _showMandatoryUpdateDialog(context, result);
    } else if (result.isUpdateRecommended) {
      _dialogShown = true;
      _showOptionalUpdateDialog(context, result);
    }
  }

  void _showMandatoryUpdateDialog(BuildContext context, VersionCheckResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFFDC2626), size: 28),
              SizedBox(width: 10),
              Text(
                'Mise à jour obligatoire',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Une nouvelle version majeure de Dioufy-TS (${result.latestVersion}) est disponible pour garantir la sécurité bancaire et l\'embarquement.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  'Votre version actuelle ($currentAppVersion) n\'est plus supportée (minimum requis : ${result.minimumSupportedVersion}).',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                ),
              ),
              if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Nouveautés :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 4),
                Text(
                  result.releaseNotes!,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Mettre à jour maintenant', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final uri = Uri.parse(result.storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionalUpdateDialog(BuildContext context, VersionCheckResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.new_releases_outlined, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Nouvelle version', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La version ${result.latestVersion} de Dioufy-TS est disponible avec des améliorations de confort et de rapidité.',
              style: const TextStyle(fontSize: 14),
            ),
            if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                result.releaseNotes!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(result.storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }
}
