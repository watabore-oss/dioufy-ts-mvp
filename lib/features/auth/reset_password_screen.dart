import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../app/router.dart';

/// Écran de définition du nouveau mot de passe
/// Accessible via le lien sécurisé envoyé par email ou redirection recovery
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPass = _passwordController.text.trim();
      final ok = await AuthService.instance.completePasswordRecovery(newPassword: newPass);

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe mis à jour avec succès ! Veuillez vous connecter avec votre nouveau mot de passe.'),
            backgroundColor: DioufyColors.emerald,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
      } else {
        final err = AuthService.instance.lastAuthError ?? 'Erreur lors de la mise à jour du mot de passe.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: DioufyColors.coral,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour : $e'),
          backgroundColor: DioufyColors.coral,
        ),
      );
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      AuthService.instance.cancelPasswordRecovery();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recoveryError = AuthService.instance.passwordRecoveryError;

    return Scaffold(
      backgroundColor: DioufyColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DioufyColors.textPrimary),
          tooltip: 'Retour',
          onPressed: _handleBack,
        ),
        title: const Text(
          'Nouveau mot de passe',
          style: TextStyle(
            color: DioufyColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: recoveryError != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: DioufyColors.coral.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: DioufyColors.coral,
                                size: 44,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Lien de réinitialisation invalide',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: DioufyColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            recoveryError,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DioufyColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text(
                              'DEMANDER UN NOUVEAU LIEN',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            onPressed: () {
                              AuthService.instance.cancelPasswordRecovery();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRouter.login,
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _handleBack,
                            child: const Text('Retour à la connexion'),
                          ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // En-tête
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: DioufyColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_reset,
                                  color: DioufyColors.primary,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Définir un nouveau mot de passe',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: DioufyColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Votre lien de sécurité a été validé. Saisissez votre nouveau mot de passe pour sécuriser votre compte.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 28),

                      // Champ Nouveau Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Nouveau mot de passe *',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 6) {
                            return 'Au moins 6 caractères requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Champ Confirmation
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirmer le mot de passe *',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Les deux mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Bouton d'enregistrement
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DioufyColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _handleUpdatePassword,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'ENREGISTRER LE MOT DE PASSE',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Lien retour login
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRouter.login,
                            (route) => false,
                          ),
                          icon: const Icon(Icons.arrow_back, size: 16, color: DioufyColors.primary),
                          label: const Text(
                            'Retour à la connexion',
                            style: TextStyle(color: DioufyColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
