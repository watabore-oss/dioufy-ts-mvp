import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/permissions/app_role.dart';
import '../core/permissions/app_permission.dart';
import '../core/permissions/rbac_context.dart';
import '../core/permissions/rbac_service.dart';

/// Modèle Utilisateur Dioufy-TS
class AppUser {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final AppRole role;
  final String? organizationId;
  final bool isGuest; // Voyageur direct sans compte

  const AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    required this.role,
    this.organizationId,
    this.isGuest = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'avatarUrl': avatarUrl,
        'role': role.id,
        'organizationId': organizationId,
        'isGuest': isGuest,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? 'Utilisateur Dioufy',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        role: AppRole.fromId(json['role'] as String? ?? 'passenger'),
        organizationId: json['organizationId'] as String?,
        isGuest: json['isGuest'] as bool? ?? false,
      );

  factory AppUser.guest() => const AppUser(
        id: 'guest_traveler',
        fullName: 'Voyageur Direct (Sans Compte)',
        phone: '',
        role: AppRole.passenger,
        isGuest: true,
      );
}

/// Type de conflit d'unicité de compte
enum AccountConflictType { none, phone, email, both }

/// Résultat de la vérification préalable d'unicité Téléphone & E-mail
class AccountCheckResult {
  final bool exists;
  final AccountConflictType conflictType;
  final String? message;

  const AccountCheckResult({
    required this.exists,
    this.conflictType = AccountConflictType.none,
    this.message,
  });

  static const AccountCheckResult _clear = AccountCheckResult(exists: false);
  static AccountCheckResult clear() => _clear;
}

/// Service Central d'Authentification & Gestion de Session Dioufy-TS
/// Architecture de production :
/// Flutter -> Supabase Auth -> Session JWT -> auth.uid() -> Profil & Rôle Serveur -> RBAC -> Dashboard
class AuthService extends ChangeNotifier {
  static const String _userStorageKey = 'dioufy_auth_user_v1';
  static AuthService? _instance;

  AppUser _currentUser = AppUser.guest();
  String? _lastAuthError;

  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  AppUser get currentUser => _currentUser;
  bool get isLoggedIn => !_currentUser.isGuest;
  bool get isGuest => _currentUser.isGuest;
  AppRole get currentRole => _currentUser.role;
  bool get isSuperAdmin => _currentUser.role == AppRole.superAdmin;
  String? get currentOrganizationId => _currentUser.organizationId;
  String? get lastAuthError => _lastAuthError;

  /// Initialisation de la session au démarrage.
  /// PRINCIPE ABSOLU : Supabase Auth est l'unique source de vérité.
  /// SharedPreferences ne décide JAMAIS si un utilisateur est authentifié.
  Future<void> initialize() async {
    try {
      final client = Supabase.instance.client;
      final currentSession = client.auth.currentSession;

      if (currentSession != null && !currentSession.isExpired) {
        // Session Supabase active : charger le profil vérifié depuis le serveur
        await _loadServerProfileAndPermissions(currentSession.user);
      } else {
        // Aucune session serveur valide : état invité strict
        await _handleSignOutCleanup();
      }

      // Écoute dynamique et réactive des événements d'authentification Supabase
      client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        final event = data.event;

        if (session != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.tokenRefreshed ||
                event == AuthChangeEvent.userUpdated)) {
          await _loadServerProfileAndPermissions(session.user);
        } else if (event == AuthChangeEvent.signedOut) {
          await _handleSignOutCleanup();
        }
      });
    } catch (e) {
      debugPrint('[AuthService] Initialisation session : mode offline ($e)');
      // En cas d'impossibilité de joindre le serveur, vérifier si un snapshot RBAC récent existe
      if (RbacService.instance.context.isExpired) {
        _currentUser = AppUser.guest();
        await RbacService.instance.clearAndResetToPassenger();
      }
    }
    notifyListeners();
  }

  /// Charge le profil serveur, résout le rôle vérifié et synchronise le contexte RBAC.
  /// Le client ne participe JAMAIS à la détermination de son propre rôle.
  Future<void> _loadServerProfileAndPermissions(User sbUser) async {
    try {
      final client = Supabase.instance.client;
      Map<String, dynamic>? profileData;

      // 1. Tenter la RPC optimisée get_my_profile_and_permissions()
      try {
        final rpcRes = await client.rpc('get_my_profile_and_permissions');
        if (rpcRes is Map) {
          profileData = Map<String, dynamic>.from(rpcRes);
        }
      } catch (rpcErr) {
        debugPrint('[AuthService] RPC get_my_profile_and_permissions unavailable: $rpcErr');
      }

      String roleId = 'passenger';
      String fullName = 'Utilisateur Dioufy';
      String phone = sbUser.phone ?? '';
      String? organizationId;
      String? avatarUrl;
      Set<String> permissions = {};

      if (profileData != null && profileData['error'] == null) {
        roleId = profileData['role']?.toString() ?? 'passenger';
        fullName = profileData['full_name']?.toString() ??
            (sbUser.userMetadata?['full_name']?.toString() ?? 'Utilisateur Dioufy');
        phone = profileData['phone']?.toString() ?? (sbUser.phone ?? '');
        organizationId = profileData['organization_id']?.toString();
        avatarUrl = profileData['avatar_url']?.toString();
        if (profileData['permissions'] is List) {
          permissions = (profileData['permissions'] as List)
              .map((e) => e.toString())
              .toSet();
        }
      } else {
        // Fallback requêtes directes sécurisées
        try {
          // Résolution de l'appartenance de plus haut niveau
          final memberships = await client
              .from('organization_memberships')
              .select('role_id, organization_id')
              .eq('user_id', sbUser.id)
              .eq('is_active', true);

          if (memberships.isNotEmpty) {
            // Prendre le rôle ayant le niveau le plus élevé
            roleId = memberships.first['role_id']?.toString() ?? 'passenger';
            organizationId = memberships.first['organization_id']?.toString();
          } else {
            // Vérifier app_users
            final userRow = await client
                .from('app_users')
                .select('role, full_name, phone, organization_id, avatar_url')
                .eq('id', sbUser.id)
                .maybeSingle();

            if (userRow != null) {
              roleId = userRow['role']?.toString() ?? 'passenger';
              organizationId = userRow['organization_id']?.toString();
              fullName = userRow['full_name']?.toString() ?? fullName;
              phone = userRow['phone']?.toString() ?? phone;
              avatarUrl = userRow['avatar_url']?.toString();
            }
          }
        } catch (dbErr) {
          debugPrint('[AuthService] Fallback DB profiles error: $dbErr');
        }
      }

      final verifiedRole = AppRole.fromId(roleId);

      // Si permissions non reçues de la RPC, utiliser la matrice du rôle vérifié
      if (permissions.isEmpty) {
        permissions = Set<String>.from(AppPermission.getDefaultPermissions(verifiedRole));
      }

      final appUser = AppUser(
        id: sbUser.id,
        fullName: fullName.isEmpty ? 'Utilisateur Dioufy' : fullName,
        phone: phone,
        email: sbUser.email,
        avatarUrl: avatarUrl,
        role: verifiedRole,
        organizationId: organizationId,
        isGuest: false,
      );

      final rbacContext = RbacContext(
        userId: sbUser.id,
        role: verifiedRole,
        organizationId: organizationId,
        permissions: permissions,
        snapshotTimestamp: DateTime.now(),
      );

      await RbacService.instance.setAuthenticatedContext(rbacContext);
      await _setCurrentUser(appUser);
      debugPrint('[AuthService] Utilisateur synchronisé avec succès : ${appUser.fullName} (${verifiedRole.name})');
    } catch (e) {
      debugPrint('[AuthService] Erreur synchronisation profil serveur : $e');
    }
  }

  /// Nettoyage complet lors de la déconnexion
  Future<void> _handleSignOutCleanup() async {
    _currentUser = AppUser.guest();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userStorageKey);
    } catch (_) {}
    await RbacService.instance.clearAndResetToPassenger();
    notifyListeners();
  }

  /// 1. Achat Direct Sans Compte (Guest Checkout)
  void continueAsGuest() {
    _currentUser = AppUser.guest();
    RbacService.instance.clearAndResetToPassenger();
    notifyListeners();
  }

  /// Extrait uniquement les chiffres d'une chaîne
  static String extractDigits(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  /// 2. Connexion Robuste (Email / Téléphone + Mot de passe)
  /// FLUX STRICT : Aucun identifiant en dur. Tout passe par Supabase Auth.
  Future<bool> loginWithCredentials({
    required String login,
    required String password,
  }) async {
    _lastAuthError = null;
    final trimmedLogin = login.trim();
    final trimmedPassword = password.trim();

    if (trimmedLogin.isEmpty || trimmedPassword.isEmpty) {
      _lastAuthError = 'Veuillez saisir votre identifiant et votre mot de passe.';
      return false;
    }

    try {
      final client = Supabase.instance.client;
      String effectiveEmail = trimmedLogin;

      // Si l'utilisateur a saisi un numéro de téléphone à la place d'un email
      if (!trimmedLogin.contains('@')) {
        final digits = extractDigits(trimmedLogin);
        final normalized = _normalizeSenegalPhone(trimmedLogin);

        try {
          final userRow = await client
              .from('app_users')
              .select('email')
              .or('phone.eq.$trimmedLogin,phone.eq.$normalized,phone.ilike.%$digits%')
              .limit(1)
              .maybeSingle();

          if (userRow != null &&
              userRow['email'] != null &&
              (userRow['email'] as String).isNotEmpty) {
            effectiveEmail = userRow['email'] as String;
          } else {
            _lastAuthError =
                'Aucun compte associé à ce numéro de téléphone. Veuillez vérifier votre saisie ou vous connecter par code SMS.';
            return false;
          }
        } catch (e) {
          debugPrint('[AuthService] Recherche e-mail associé : $e');
          _lastAuthError =
              'Impossible de retrouver le compte associé à ce numéro. Veuillez utiliser votre e-mail ou le code SMS.';
          return false;
        }
      }

      // Authentification serveur auprès de Supabase Auth
      final res = await client.auth.signInWithPassword(
        email: effectiveEmail,
        password: trimmedPassword,
      );

      if (res.session == null || res.user == null) {
        _lastAuthError = 'Échec de connexion : session invalide.';
        return false;
      }

      // Charger le profil serveur et les permissions
      await _loadServerProfileAndPermissions(res.user!);
      return true;
    } on AuthException catch (authErr) {
      debugPrint('[AuthService] Échec Supabase Auth : ${authErr.message} (code: ${authErr.statusCode})');
      final msg = authErr.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
        _lastAuthError = 'Identifiants incorrects. Veuillez vérifier votre identifiant ou mot de passe.';
      } else if (msg.contains('email not confirmed') || msg.contains('email_not_confirmed')) {
        _lastAuthError =
            'Adresse e-mail non encore confirmée. Veuillez consulter votre boîte de réception.';
      } else {
        _lastAuthError = authErr.message;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Erreur technique de connexion : $e');
      _lastAuthError = 'Erreur de connexion. Veuillez vérifier votre connexion réseau.';
      return false;
    }
  }

  /// Vérification préventive d'unicité Téléphone & E-mail (Anti-Doublon strict)
  Future<AccountCheckResult> checkAccountExists({
    required String phone,
    String? email,
  }) async {
    final cleanPhone = phone.trim();
    final cleanEmail = (email != null && email.trim().isNotEmpty) ? email.trim() : null;

    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('check_account_exists', params: {
        'p_phone': cleanPhone,
        'p_email': cleanEmail,
      });

      if (res is Map) {
        final phoneExists = res['phone_exists'] == true;
        final emailExists = res['email_exists'] == true;

        if (phoneExists && emailExists) {
          return const AccountCheckResult(
            exists: true,
            conflictType: AccountConflictType.both,
            message:
                'Ce numéro de téléphone et cette adresse e-mail sont déjà enregistrés sur Dioufy-TS. Veuillez vous connecter.',
          );
        } else if (phoneExists) {
          return const AccountCheckResult(
            exists: true,
            conflictType: AccountConflictType.phone,
            message:
                'Ce numéro de téléphone est déjà enregistré sur Dioufy-TS. Veuillez vous connecter avec ce compte.',
          );
        } else if (emailExists) {
          return const AccountCheckResult(
            exists: true,
            conflictType: AccountConflictType.email,
            message:
                'Cette adresse e-mail est déjà associée à un compte Dioufy-TS. Veuillez vous connecter.',
          );
        }
      }
    } catch (e) {
      debugPrint('[AuthService] check_account_exists RPC non disponible : $e');
    }

    return AccountCheckResult.clear();
  }

  /// 3. Inscription / Ouverture de Compte Passager
  /// RÈGLE DE SÉCURITÉ : Toute inscription publique reçoit STRICTEMENT le rôle 'passenger'.
  Future<bool> register({
    required String fullName,
    required String phone,
    String? email,
    required String password,
  }) async {
    _lastAuthError = null;

    final check = await checkAccountExists(phone: phone, email: email);
    if (check.exists) {
      _lastAuthError = check.message;
      return false;
    }

    try {
      final client = Supabase.instance.client;
      final cleanPhone = _normalizeSenegalPhone(phone);
      final effectiveEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : 'passager.${extractDigits(cleanPhone)}@dioufy.sn';

      final res = await client.auth.signUp(
        email: effectiveEmail,
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': cleanPhone,
          // AUCUN rôle n'est spécifié ici : le trigger PostgreSQL attribue 'passenger' obligatoirement
        },
      );

      final sbUser = res.user;
      if (sbUser == null) {
        _lastAuthError = "Échec de création du compte auprès du serveur.";
        return false;
      }

      if (res.session != null) {
        await _loadServerProfileAndPermissions(sbUser);
      }
      return true;
    } on AuthException catch (authErr) {
      final msg = authErr.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        _lastAuthError = "Ce compte ou cet e-mail est déjà enregistré. Veuillez vous connecter.";
      } else {
        _lastAuthError = authErr.message;
      }
      return false;
    } catch (e) {
      _lastAuthError = 'Erreur technique lors de l\'inscription : $e';
      return false;
    }
  }

  /// 4. Authentification par Numéro de Téléphone & OTP SMS (+221 Sénégal)
  /// AUCUN FALLBACK SIMULÉ : Si l'envoi échoue, l'erreur réelle est propagée.
  Future<bool> signInWithPhoneOtp({required String phone}) async {
    _lastAuthError = null;
    final cleanPhone = _normalizeSenegalPhone(phone);
    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithOtp(phone: cleanPhone);
      return true;
    } on AuthException catch (e) {
      debugPrint('[AuthService] Échec envoi OTP Supabase : ${e.message}');
      _lastAuthError = 'Échec de l\'envoi du SMS : ${e.message}';
      return false;
    } catch (e) {
      debugPrint('[AuthService] Erreur technique SMS OTP : $e');
      _lastAuthError = 'Service SMS temporairement indisponible. Veuillez réessayer plus tard.';
      return false;
    }
  }

  /// 5. Vérification du Code SMS OTP & Connexion automatique
  /// ZÉRO CODE DE TEST : Tout code est vérifié par Supabase Auth.
  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    _lastAuthError = null;
    final cleanPhone = _normalizeSenegalPhone(phone);
    final trimmedToken = token.trim();

    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        phone: cleanPhone,
        token: trimmedToken,
        type: OtpType.sms,
      );

      if (res.session != null && res.user != null) {
        await _loadServerProfileAndPermissions(res.user!);
        return true;
      }

      _lastAuthError = 'Code secret SMS invalide ou expiré.';
      return false;
    } on AuthException catch (e) {
      _lastAuthError = 'Code SMS invalide : ${e.message}';
      return false;
    } catch (e) {
      _lastAuthError = 'Erreur lors de la validation du code SMS : $e';
      return false;
    }
  }

  /// Vérifie le code SMS OTP pour la réinitialisation de mot de passe
  Future<bool> verifyPhoneOtpForReset({
    required String phone,
    required String token,
  }) async {
    final cleanPhone = _normalizeSenegalPhone(phone);
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        phone: cleanPhone,
        token: token.trim(),
        type: OtpType.sms,
      );
      return res.user != null;
    } catch (e) {
      debugPrint('Vérification Phone OTP reset : $e');
      return false;
    }
  }

  /// 6. Réinitialisation de Mot de Passe par SMS OTP (+221)
  Future<bool> resetPasswordWithPhoneOtp({
    required String phone,
    required String token,
    required String newPassword,
  }) async {
    final cleanPhone = _normalizeSenegalPhone(phone);
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        phone: cleanPhone,
        token: token.trim(),
        type: OtpType.sms,
      );
      if (res.user != null) {
        await client.auth.updateUser(UserAttributes(password: newPassword));
        await client.auth.signOut();
        return true;
      }
    } catch (e) {
      debugPrint('Reset password SMS OTP : $e');
    }
    return false;
  }

  /// 7. Réinitialisation de Mot de Passe par Email
  Future<bool> resetPasswordForEmail({required String email}) async {
    try {
      final client = Supabase.instance.client;
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'com.dioufy.app://reset-password',
      );
      return true;
    } catch (e) {
      debugPrint('Reset password email : $e');
      return false;
    }
  }

  /// 7b. Vérification Code OTP Email
  Future<bool> verifyEmailOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: type,
      );
      return res.user != null;
    } catch (e) {
      debugPrint('Vérification Email OTP : $e');
      return false;
    }
  }

  /// 7c. Réinitialisation de Mot de Passe par Code OTP Email
  Future<bool> resetPasswordWithEmailOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );
      if (res.user != null) {
        await client.auth.updateUser(UserAttributes(password: newPassword));
        await client.auth.signOut();
        return true;
      }
    } catch (e) {
      debugPrint('Reset password email OTP : $e');
    }
    return false;
  }

  /// 8. Mise à jour directe du Mot de Passe pour l'utilisateur connecté
  Future<bool> updatePassword({required String newPassword}) async {
    if (newPassword.length < 6) return false;
    try {
      final client = Supabase.instance.client;
      await client.auth.updateUser(UserAttributes(password: newPassword));
      await client.auth.signOut();
      return true;
    } catch (e) {
      debugPrint('Mise à jour mot de passe : $e');
      return false;
    }
  }

  /// 9. Connexion Google OAuth préparée pour Supabase
  Future<bool> signInWithGoogle() async {
    _lastAuthError = null;
    try {
      final client = Supabase.instance.client;
      final redirectUrl = kIsWeb
          ? '${Uri.base.origin}/'
          : 'com.dioufy.app://login-callback';

      final res = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return res;
    } on AuthException catch (authErr) {
      _lastAuthError = authErr.message;
      return false;
    } catch (e) {
      _lastAuthError = e.toString();
      return false;
    }
  }

  /// Helper de normalisation des numéros sénégalais (+221)
  String _normalizeSenegalPhone(String phone) {
    var p = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    if (!p.startsWith('+')) {
      if (p.startsWith('221')) {
        p = '+$p';
      } else {
        p = '+221$p';
      }
    }
    return p;
  }

  /// Création d'un compte managé par le Super Admin / Gestionnaire GIE via RPC sécurisée
  Future<Map<String, dynamic>> createManagedUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required AppRole role,
    String? organizationId,
  }) async {
    if (!currentRole.canManageRole(role)) {
      return {
        'success': false,
        'message': 'Privilège insuffisant pour créer un compte avec le rôle [${role.name}].',
      };
    }

    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('create_managed_user', params: {
        'p_email': email.trim().isEmpty ? null : email.trim(),
        'p_phone': phone.trim().isEmpty ? null : phone.trim(),
        'p_password': password,
        'p_full_name': fullName.trim(),
        'p_role': role.id,
        'p_organization_id': organizationId,
      });

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': true, 'message': 'Compte créé avec succès.'};
    } catch (e) {
      debugPrint('Erreur createManagedUser RPC ($e)');
      return {'success': false, 'message': 'Erreur serveur : $e'};
    }
  }

  /// 10. Déconnexion sécurisée
  Future<void> logout() async {
    try {
      final client = Supabase.instance.client;
      await client.auth.signOut();
    } catch (_) {}

    await _handleSignOutCleanup();
  }

  Future<void> _setCurrentUser(AppUser user) async {
    _currentUser = user;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Erreur persistance cache UI utilisateur : $e');
    }
    notifyListeners();
  }
}
