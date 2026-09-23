import 'package:flutter/material.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../core/permissions/app_role.dart';
import '../../services/auth_service.dart';
import '../chauffeur/chauffeur_screen.dart';
import '../coxeur/coxeur_dashboard_screen.dart';
import '../gie/gie_dashboard_screen.dart';
import '../admin/super_admin_dashboard_screen.dart';
import '../navigation/main_navigation_scaffold.dart';
import '../../modules/garage_assistance/garage_assistance_module.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Écran de Connexion Dioufy-TS épuré, lumineux et adaptatif (Split Screen Desktop)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _otpCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _usePhoneOtp = false;
  bool _otpCodeSent = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _phoneOtpController.dispose();
    _otpCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);
      final success = await AuthService.instance.loginWithCredentials(
        login: _loginController.text.trim(),
        password: _passwordController.text,
      );
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (success) {
        final user = AuthService.instance.currentUser;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connexion réussie : Bienvenue ${user.fullName} (${user.role.name})',
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
            backgroundColor: DioufyColors.primary,
          ),
        );
        _navigateToRoleDashboard(context);
      } else {
        final errMsg = AuthService.instance.lastAuthError ??
            'Identifiants incorrects ou compte inexistant. Veuillez vérifier votre saisie.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg, style: const TextStyle(fontSize: 15)),
            backgroundColor: DioufyColors.coral,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToRoleDashboard(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScaffold()),
      (r) => false,
    );
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneOtpController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir votre numéro de téléphone sénégalais', style: TextStyle(fontSize: 15)),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final ok = await AuthService.instance.signInWithPhoneOtp(phone: phone);
    setState(() {
      _isLoading = false;
      if (ok) _otpCodeSent = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code SMS envoyé au $phone', style: const TextStyle(fontSize: 15.5)),
        backgroundColor: DioufyColors.emerald,
      ),
    );
  }

  Future<void> _handleVerifyOtpAndLogin() async {
    final code = _otpCodeController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le code SMS reçu', style: TextStyle(fontSize: 15)),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final ok = await AuthService.instance.verifyPhoneOtp(
      phone: _phoneOtpController.text.trim(),
      token: code,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (ok) {
      final user = AuthService.instance.currentUser;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connexion réussie : Bienvenue ${user.fullName} (${user.role.name})', style: const TextStyle(fontSize: 15.5)),
          backgroundColor: DioufyColors.primary,
        ),
      );
      _navigateToRoleDashboard(context);
    } else {
      final errMsg = AuthService.instance.lastAuthError ?? 'Code SMS invalide ou expiré';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg, style: const TextStyle(fontSize: 15)),
          backgroundColor: DioufyColors.coral,
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final ok = await AuthService.instance.signInWithGoogle();
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (ok) {
      final user = AuthService.instance.currentUser;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecté via Google : Bienvenue ${user.fullName}', style: const TextStyle(fontSize: 15.5)),
          backgroundColor: DioufyColors.primary,
        ),
      );
      _navigateToRoleDashboard(context);
    }
  }

  void _handleContinueAsGuest() {
    AuthService.instance.continueAsGuest();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode direct activé : Vous pouvez réserver vos billets sans compte.', style: TextStyle(fontSize: 15)),
        backgroundColor: DioufyColors.emerald,
      ),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopSplitScaffold(
      title: 'Connexion',
      showBackButton: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. CARTE RÉASSURANCE : ACHAT DIRECT SANS COMPTE (Lumineuse & Raffinée)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DioufyRadius.lgAll,
                border: Border.all(color: DioufyColors.border, width: 1.2),
                boxShadow: DioufyShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DioufyColors.goldSoft,
                          borderRadius: DioufyRadius.smAll,
                        ),
                        child: const Icon(Icons.directions_bus_rounded, color: DioufyColors.goldDark, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'VOYAGEUR SANS COMPTE',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: DioufyColors.textPrimary,
                          fontWeight: DioufyTypography.extraBold,
                          fontSize: 14.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vous souhaitez juste réserver un billet sans ouvrir de compte ? C\'est direct et instantané.',
                    style: TextStyle(
                      fontFamily: DioufyTypography.fontFamily,
                      color: DioufyColors.textSecondary,
                      fontSize: DioufyTypography.caption,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _handleContinueAsGuest,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: DioufyColors.primary),
                      label: const Text(
                        'CONTINUER SANS COMPTE',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          fontWeight: DioufyTypography.bold,
                          fontSize: 14,
                          color: DioufyColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: DioufyColors.primary, width: 1.5),
                        shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                        backgroundColor: DioufyColors.primarySoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Séparateur harmonieux
            const Row(
              children: [
                Expanded(child: Divider(color: DioufyColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OU CONNECTEZ-VOUS',
                    style: TextStyle(
                      fontFamily: DioufyTypography.fontFamily,
                      color: DioufyColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: DioufyTypography.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: DioufyColors.border)),
              ],
            ),

            const SizedBox(height: 20),

            // 2. SÉLECTEUR DE MODE DE CONNEXION : MOT DE PASSE OU SMS OTP
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: DioufyColors.surfaceSoft,
                borderRadius: DioufyRadius.mdAll,
                border: Border.all(color: DioufyColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _usePhoneOtp = false),
                      borderRadius: DioufyRadius.smAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_usePhoneOtp ? DioufyColors.white : Colors.transparent,
                          borderRadius: DioufyRadius.smAll,
                          boxShadow: !_usePhoneOtp ? DioufyShadows.card : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Mot de passe',
                          style: TextStyle(
                            fontFamily: DioufyTypography.fontFamily,
                            color: !_usePhoneOtp ? DioufyColors.primary : DioufyColors.textSecondary,
                            fontWeight: !_usePhoneOtp ? DioufyTypography.bold : DioufyTypography.medium,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _usePhoneOtp = true),
                      borderRadius: DioufyRadius.smAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _usePhoneOtp ? DioufyColors.white : Colors.transparent,
                          borderRadius: DioufyRadius.smAll,
                          boxShadow: _usePhoneOtp ? DioufyShadows.card : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Code SMS (+221)',
                          style: TextStyle(
                            fontFamily: DioufyTypography.fontFamily,
                            color: _usePhoneOtp ? DioufyColors.primary : DioufyColors.textSecondary,
                            fontWeight: _usePhoneOtp ? DioufyTypography.bold : DioufyTypography.medium,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            if (!_usePhoneOtp) ...[
              // FORMULAIRE CLASSIQUE MOT DE PASSE
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _loginController,
                      style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (+221) ou Email',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: DioufyColors.primary, size: 22),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Veuillez saisir votre identifiant' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: DioufyColors.primary, size: 22),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 22),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Veuillez saisir votre mot de passe' : null,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                        child: const Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(
                            color: DioufyColors.primary,
                            fontWeight: DioufyTypography.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
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
                                'SE CONNECTER',
                                style: TextStyle(
                                  fontFamily: DioufyTypography.fontFamily,
                                  fontWeight: DioufyTypography.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // FORMULAIRE SMS OTP
              Column(
                children: [
                  TextFormField(
                    controller: _phoneOtpController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 16, color: DioufyColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone sénégalais',
                      hintText: 'ex: 77 123 45 67',
                      prefixIcon: Icon(Icons.phone_android_rounded, color: DioufyColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_otpCodeSent) ...[
                    TextFormField(
                      controller: _otpCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 3),
                      decoration: const InputDecoration(
                        labelText: 'Code secret SMS à 6 chiffres',
                        prefixIcon: Icon(Icons.sms_outlined, color: DioufyColors.primary, size: 22),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerifyOtpAndLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DioufyColors.emerald,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'VÉRIFIER ET ENTRER',
                                style: TextStyle(
                                  fontFamily: DioufyTypography.fontFamily,
                                  fontWeight: DioufyTypography.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DioufyColors.primary,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'RECEVOIR MON CODE PAR SMS',
                                style: TextStyle(
                                  fontFamily: DioufyTypography.fontFamily,
                                  fontWeight: DioufyTypography.bold,
                                  fontSize: 15.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

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

            const SizedBox(height: 24),

            // Lien Inscription
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Pas encore de compte ? ',
                  style: TextStyle(
                    fontFamily: DioufyTypography.fontFamily,
                    color: DioufyColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text(
                    'Créer un compte',
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
            const SizedBox(height: 24),

            // Panneau Accès Rapide & Test Souverain (Préremplissage 1-Clic)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DioufyRadius.mdAll,
                border: Border.all(color: DioufyColors.border),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.vpn_key_outlined, color: DioufyColors.primary, size: 20),
                  title: const Text(
                    'Comptes Officiels & Démo (1-Clic)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: DioufyColors.textPrimary,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  children: [
                    const Text(
                      'Cliquez sur un profil pour préremplir instantanément ses identifiants stricts :',
                      style: TextStyle(fontSize: 12, color: DioufyColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                          backgroundColor: const Color(0xFF1E293B),
                          label: const Text('👑 Super Admin (774787145)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _usePhoneOtp = false;
                              _loginController.text = '774787145';
                              _passwordController.text = 'Dioufy2026!';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.support_agent, color: Colors.white, size: 16),
                          backgroundColor: DioufyColors.primary,
                          label: const Text('🛡️ Support (774691379)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _usePhoneOtp = false;
                              _loginController.text = '774691379';
                              _passwordController.text = 'Dioufy2026!';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.account_balance, color: Colors.white, size: 16),
                          backgroundColor: const Color(0xFF059669),
                          label: const Text('🏢 GIE Thiès (771234567)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _usePhoneOtp = false;
                              _loginController.text = '771234567';
                              _passwordController.text = 'Dioufy2026!';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.directions_bus, color: Colors.white, size: 16),
                          backgroundColor: const Color(0xFFD97706),
                          label: const Text('🚌 Chauffeur (772345678)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _usePhoneOtp = false;
                              _loginController.text = '772345678';
                              _passwordController.text = 'Dioufy2026!';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.departure_board, color: Colors.white, size: 16),
                          backgroundColor: const Color(0xFF7C3AED),
                          label: const Text('🎫 Coxeur Quai (773456789)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _usePhoneOtp = false;
                              _loginController.text = '773456789';
                              _passwordController.text = 'Dioufy2026!';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
