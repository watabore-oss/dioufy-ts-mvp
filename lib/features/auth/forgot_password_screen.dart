import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';

/// Écran de Récupération et Réinitialisation de Mot de Passe
/// Supporte le SMS (+221 Sénégal) avec code OTP et l'Email
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPhoneMode = true; // true = SMS (+221), false = Email
  int _currentStep = 1; // 1: Saisie coordonnée, 2: Code OTP, 3: Nouveau mot de passe
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final identifier = _isPhoneMode ? _phoneController.text.trim() : _emailController.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPhoneMode ? 'Veuillez saisir votre numéro de téléphone' : 'Veuillez saisir votre adresse email'),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isPhoneMode) {
      final ok = await AuthService.instance.signInWithPhoneOtp(phone: identifier);
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (ok) {
        setState(() => _currentStep = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code SMS de vérification envoyé au $identifier'),
            backgroundColor: DioufyColors.emerald,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'envoyer le code SMS. Vérifiez votre numéro.'),
            backgroundColor: DioufyColors.coral,
          ),
        );
      }
    } else {
      final ok = await AuthService.instance.resetPasswordForEmail(email: identifier);
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (ok) {
        setState(() => _currentStep = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code OTP et lien envoyés à $identifier'),
            backgroundColor: DioufyColors.emerald,
          ),
        );
      } else {
        final err = AuthService.instance.lastAuthError ?? 'Impossible d\'envoyer l\'email de réinitialisation. Vérifiez l\'adresse.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: DioufyColors.coral,
          ),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le code de vérification à 6 chiffres'),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final ok = _isPhoneMode
        ? await AuthService.instance.verifyPhoneOtpForReset(
            phone: _phoneController.text.trim(),
            token: code,
          )
        : await AuthService.instance.verifyEmailOtp(
            email: _emailController.text.trim(),
            token: code,
            type: OtpType.recovery,
          );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (ok) {
      setState(() => _currentStep = 3);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code vérifié avec succès ! Vous pouvez définir votre nouveau mot de passe.'),
          backgroundColor: DioufyColors.emerald,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code de vérification invalide ou expiré. Veuillez vérifier le code reçu.'),
          backgroundColor: DioufyColors.coral,
        ),
      );
    }
  }

  Future<void> _handleUpdatePassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mot de passe doit contenir au moins 6 caractères'),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les deux mots de passe ne correspondent pas'),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final ok = _isPhoneMode
        ? await AuthService.instance.resetPasswordWithPhoneOtp(
            phone: _phoneController.text.trim(),
            token: _otpController.text.trim(),
            newPassword: newPass,
          )
        : await AuthService.instance.resetPasswordWithEmailOtp(
            email: _emailController.text.trim(),
            token: _otpController.text.trim(),
            newPassword: newPass,
          );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre mot de passe a été modifié avec succès ! Connectez-vous.'),
          backgroundColor: DioufyColors.emerald,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour du mot de passe. Veuillez réessayer.'),
          backgroundColor: DioufyColors.coral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 24),
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mot de Passe Oublié',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.5, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicateur d'étapes
            Row(
              children: [
                _buildStepBadge(1, 'Identifiant', _currentStep >= 1),
                Expanded(child: Container(height: 2, color: _currentStep >= 2 ? DioufyColors.emerald : Colors.grey.shade300)),
                _buildStepBadge(2, 'Code SMS', _currentStep >= 2),
                Expanded(child: Container(height: 2, color: _currentStep >= 3 ? DioufyColors.emerald : Colors.grey.shade300)),
                _buildStepBadge(3, 'Nouveau MDP', _currentStep >= 3),
              ],
            ),

            const SizedBox(height: 24),

            if (_currentStep == 1) ...[
              // Choix du canal (SMS ou Email)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isPhoneMode = true),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isPhoneMode ? DioufyColors.primaryDark : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Par SMS (+221)',
                            style: TextStyle(
                              color: _isPhoneMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isPhoneMode = false),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isPhoneMode ? DioufyColors.primaryDark : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(13)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Par E-mail',
                            style: TextStyle(
                              color: !_isPhoneMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_isPhoneMode) ...[
                const Text(
                  'Recevoir un code OTP par SMS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DioufyColors.primaryDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Saisissez votre numéro de téléphone sénégalais enregistré :',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '77 469 13 79',
                    prefixText: '+221 ',
                    prefixIcon: const Icon(Icons.phone_android, color: DioufyColors.emerald),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ] else ...[
                const Text(
                  'Réinitialisation par E-mail',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DioufyColors.primaryDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Saisissez l\'adresse e-mail associée à votre compte Dioufy-TS :',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Adresse E-mail',
                    hintText: 'utilisateur@dioufy.sn',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSendCode,
                  icon: const Icon(Icons.send, size: 18),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(
                          _isPhoneMode ? 'ENVOYER LE CODE SMS' : 'ENVOYER LE LIEN DE RÉINITIALISATION',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DioufyColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else if (_currentStep == 2) ...[
              // Étape 2 : Saisie du code OTP ou validation du lien email
              if (!_isPhoneMode) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, color: DioufyColors.primary, size: 36),
                      const SizedBox(height: 10),
                      const Text(
                        'Lien de Réinitialisation Envoyé !',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DioufyColors.primaryDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Un e-mail officiel Dioufy-TS contenant votre lien sécurisé vient d\'être envoyé à ${_emailController.text}.\n\nCliquez directement sur « Réinitialiser mon mot de passe » dans votre boîte de réception.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/reset-password'),
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: const Text('J\'AI CLIQUÉ SUR LE LIEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DioufyColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    '— OU si vous avez reçu un code numérique —',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                const Text(
                  'Entrez le code SMS de vérification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DioufyColors.primaryDark),
                ),
                const SizedBox(height: 6),
                Text(
                  'Un code à 6 chiffres a été envoyé par SMS au ${_phoneController.text}.',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '123456',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DioufyColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('VÉRIFIER LE CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _handleSendCode,
                child: Text(
                  _isPhoneMode ? 'Renvoyer un nouveau code par SMS' : 'Renvoyer l\'email de réinitialisation',
                  style: const TextStyle(color: DioufyColors.primary),
                ),
              ),
            ] else if (_currentStep == 3) ...[
              // Étape 3 : Saisie du nouveau mot de passe
              const Text(
                'Définissez votre nouveau mot de passe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DioufyColors.primaryDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Créez un mot de passe robuste d\'au moins 6 caractères :',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF1D4ED8),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Confirmez le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DioufyColors.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('ENREGISTRER LE NOUVEAU MOT DE PASSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepBadge(int step, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? DioufyColors.emerald : Colors.grey.shade300,
          child: Text(
            '$step',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? DioufyColors.primaryDark : Colors.grey,
          ),
        ),
      ],
    );
  }
}
