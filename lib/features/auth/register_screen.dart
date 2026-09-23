import 'package:flutter/material.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../core/permissions/app_role.dart';
import '../../services/auth_service.dart';

/// Écran d'Ouverture de Compte Voyageur (Passager) adaptatif Desktop Split Screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+221 77 ');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final AppRole _selectedRole = AppRole.passenger;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final success = await AuthService.instance.register(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      password: _passwordController.text,
      role: _selectedRole,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Compte passager créé avec succès ! Bienvenue ${_nameController.text}',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
          backgroundColor: DioufyColors.primary,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    } else {
      final errorMsg = AuthService.instance.lastAuthError ?? 'Erreur lors de la création du compte. Veuillez réessayer.';
      final isAlreadyExists = errorMsg.toLowerCase().contains('déjà') ||
          errorMsg.toLowerCase().contains('already') ||
          errorMsg.toLowerCase().contains('enregistré');

      if (isAlreadyExists) {
        _showAccountExistsDialog(errorMsg);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, style: const TextStyle(fontSize: 15)),
            backgroundColor: DioufyColors.coral,
          ),
        );
      }
    }
  }

  void _showAccountExistsDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.xlAll),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_circle_outlined, color: Color(0xFFD97706), size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Compte Déjà Enregistré',
                style: TextStyle(
                  fontFamily: DioufyTypography.fontFamily,
                  fontWeight: DioufyTypography.bold,
                  fontSize: 17,
                  color: DioufyColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: DioufyTypography.fontFamily,
            fontSize: 15,
            color: DioufyColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Modifier la saisie',
              style: TextStyle(color: DioufyColors.textSecondary, fontSize: 14.5),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            icon: const Icon(Icons.login_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Me connecter',
              style: TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                fontWeight: DioufyTypography.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DioufyColors.primary,
              shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final ok = await AuthService.instance.signInWithGoogle();
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion Google réussie', style: TextStyle(fontSize: 15.5)),
          backgroundColor: DioufyColors.primary,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    } else {
      final err = AuthService.instance.lastAuthError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err != null ? 'Google Auth : $err' : 'Impossible de se connecter avec Google.',
            style: const TextStyle(fontSize: 15),
          ),
          backgroundColor: DioufyColors.coral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopSplitScaffold(
      title: 'Créer un Compte',
      showBackButton: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ENCADRÉ INCITATIF : AVANTAGES DU COMPTE PASSAGER (Lumineux & Doux)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DioufyColors.surfaceSoft,
                borderRadius: DioufyRadius.lgAll,
                border: Border.all(color: DioufyColors.border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.stars_rounded, color: DioufyColors.primary, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Pourquoi ouvrir un compte ?',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          fontSize: 16,
                          fontWeight: DioufyTypography.bold,
                          color: DioufyColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitRow(Icons.history_rounded, 'Historique complet et suivi de tous vos trajets'),
                  const SizedBox(height: 8),
                  _buildBenefitRow(Icons.qr_code_2_rounded, 'Retrouvez vos billets et QR codes à tout moment'),
                  const SizedBox(height: 8),
                  _buildBenefitRow(Icons.bolt_rounded, 'Réservation express sans ressaisir vos coordonnées'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Indication profil passager
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DioufyRadius.mdAll,
                border: Border.all(color: DioufyColors.border),
                boxShadow: DioufyShadows.card,
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_rounded, color: DioufyColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Compte Voyageur / Passager',
                      style: TextStyle(
                        fontFamily: DioufyTypography.fontFamily,
                        fontSize: 15.5,
                        fontWeight: DioufyTypography.semiBold,
                        color: DioufyColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: DioufyColors.emerald, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // FORMULAIRE D'INSCRIPTION AVEC TYPOGRAPHIE AGRANDIE
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Prénom et Nom complet *',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: DioufyColors.primary, size: 22),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Veuillez saisir votre nom complet' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone sénégalais *',
                      prefixIcon: Icon(Icons.phone_android_rounded, color: DioufyColors.primary, size: 22),
                    ),
                    validator: (v) => (v == null || v.length < 9) ? 'Numéro de téléphone valide requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Adresse Email (optionnel)',
                      prefixIcon: Icon(Icons.email_outlined, color: DioufyColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe sécurisé *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: DioufyColors.primary, size: 22),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 22),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Le mot de passe doit comporter au moins 6 caractères' : null,
                  ),

                  const SizedBox(height: 24),

                  // BOUTON PRINCIPAL DE CRÉATION
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DioufyColors.primary,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                        elevation: 1,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'CRÉER MON COMPTE VOYAGEUR',
                              style: TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                fontWeight: DioufyTypography.bold,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Séparateur OU
                  const Row(
                    children: [
                      Expanded(child: Divider(color: DioufyColors.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OU',
                          style: TextStyle(
                            fontFamily: DioufyTypography.fontFamily,
                            color: DioufyColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: DioufyTypography.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: DioufyColors.border)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // BOUTON GOOGLE OAUTH
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                      icon: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 30),
                      label: const Text(
                        'Continuer avec Google',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          fontWeight: DioufyTypography.bold,
                          fontSize: 15,
                          color: DioufyColors.textPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: DioufyColors.border, width: 1.2),
                        shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Note d'administration
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DioufyColors.surfaceSoft,
                borderRadius: DioufyRadius.mdAll,
                border: Border.all(color: DioufyColors.border),
              ),
              child: const Text(
                'Note : Les comptes des transporteurs et régulateurs (Chauffeurs, Gérants GIE, Agents de gare) sont administrés directement par la direction Dioufy-TS.',
                style: TextStyle(
                  fontFamily: DioufyTypography.fontFamily,
                  fontSize: 13,
                  color: DioufyColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Déjà un compte ? ',
                  style: TextStyle(
                    fontFamily: DioufyTypography.fontFamily,
                    color: DioufyColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(
                      fontFamily: DioufyTypography.fontFamily,
                      color: DioufyColors.primary,
                      fontWeight: DioufyTypography.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DioufyColors.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: DioufyTypography.fontFamily,
              fontSize: 14,
              color: DioufyColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
