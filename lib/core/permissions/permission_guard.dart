import 'package:flutter/material.dart';
import '../theme.dart';
import 'rbac_service.dart';

/// Guard d'Autorisation par Permission et Contexte Organisationnel
class PermissionGuard extends StatelessWidget {
  final String permissionId;
  final String? targetOrganizationId;
  final Widget child;
  final Widget? fallback;
  final bool hideIfDenied;
  final String? actionLabel;

  const PermissionGuard({
    super.key,
    required this.permissionId,
    required this.child,
    this.targetOrganizationId,
    this.fallback,
    this.hideIfDenied = false,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: RbacService.instance,
      builder: (context, _) {
        final isAllowed = RbacService.instance.hasPermission(
          permissionId,
          targetOrganizationId: targetOrganizationId,
        );

        if (isAllowed) {
          return child;
        }

        if (hideIfDenied) {
          return const SizedBox.shrink();
        }

        if (fallback != null) {
          return fallback!;
        }

        // Écran de refus d'accès élégant avec bouton retour obligatoire
        return Scaffold(
          backgroundColor: DioufyColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Accès Restreint'),
            backgroundColor: DioufyColors.primaryDark,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
            ),
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
                      color: DioufyColors.coral.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 36,
                      color: DioufyColors.coral,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    actionLabel != null
                        ? 'Droit insuffisant : $actionLabel'
                        : 'Privilèges Insuffisants',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: DioufyColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votre rôle actuel (${RbacService.instance.currentRole.name}) ne dispose pas de la permission requise [$permissionId] pour exécuter cette opération.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Retour'),
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
      },
    );
  }
}
