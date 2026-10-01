import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle d'une passerelle de paiement paramétrable par le Super Admin
class PaymentGatewayConfig {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final String? merchantCode; // Ex: 774691379 pour Wave Sénégal
  final String? apiKey;
  final String? apiSecret;
  final String? webhookUrl;
  final bool isTestMode;
  final int brandColorValue;
  final String iconIdentifier;

  const PaymentGatewayConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    this.merchantCode,
    this.apiKey,
    this.apiSecret,
    this.webhookUrl,
    this.isTestMode = true,
    required this.brandColorValue,
    required this.iconIdentifier,
  });

  Color get brandColor => Color(brandColorValue);

  IconData get iconData {
    switch (iconIdentifier) {
      case 'wave':
        return Icons.qr_code_2;
      case 'paydunya':
        return Icons.account_balance_wallet_outlined;
      case 'flutterwave':
        return Icons.credit_card;
      case 'paytech':
        return Icons.payments_outlined;
      case 'orange_money':
        return Icons.phone_android;
      case 'free_money':
        return Icons.account_balance_wallet;
      case 'cash':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  PaymentGatewayConfig copyWith({
    String? name,
    String? description,
    bool? isEnabled,
    String? merchantCode,
    String? apiKey,
    String? apiSecret,
    String? webhookUrl,
    bool? isTestMode,
    int? brandColorValue,
    String? iconIdentifier,
  }) {
    return PaymentGatewayConfig(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      merchantCode: merchantCode ?? this.merchantCode,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      isTestMode: isTestMode ?? this.isTestMode,
      brandColorValue: brandColorValue ?? this.brandColorValue,
      iconIdentifier: iconIdentifier ?? this.iconIdentifier,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'isEnabled': isEnabled,
        'merchantCode': merchantCode,
        'apiKey': apiKey,
        'apiSecret': apiSecret,
        'webhookUrl': webhookUrl,
        'isTestMode': isTestMode,
        'brandColorValue': brandColorValue,
        'iconIdentifier': iconIdentifier,
      };

  factory PaymentGatewayConfig.fromJson(Map<String, dynamic> json) =>
      PaymentGatewayConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
        merchantCode: json['merchantCode'] as String?,
        apiKey: json['apiKey'] as String?,
        apiSecret: json['apiSecret'] as String?,
        webhookUrl: json['webhookUrl'] as String?,
        isTestMode: json['isTestMode'] as bool? ?? true,
        brandColorValue: json['brandColorValue'] as int? ?? 0xFF1E3A8A,
        iconIdentifier: json['iconIdentifier'] as String? ?? 'payment',
      );
}

/// Service Singleton gérant le catalogue et l'état d'activation des moyens de paiement
class PaymentConfigService extends ChangeNotifier {
  static const String _storageKey = 'dioufy_payment_gateways_v1';
  static PaymentConfigService? _instance;

  final Map<String, PaymentGatewayConfig> _gateways = {};

  PaymentConfigService._();

  static PaymentConfigService get instance {
    _instance ??= PaymentConfigService._();
    return _instance!;
  }

  List<PaymentGatewayConfig> get allGateways => _gateways.values.toList();

  List<PaymentGatewayConfig> get activeGateways =>
      _gateways.values.where((g) => g.isEnabled).toList();

  PaymentGatewayConfig? getGateway(String id) => _gateways[id];

  /// Initialise la configuration par défaut avec le numéro marchand Wave officiel (774691379)
  Future<void> initialize() async {
    _initDefaults();
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null) {
        final List<dynamic> list = jsonDecode(rawJson);
        for (final item in list) {
          final cfg = PaymentGatewayConfig.fromJson(item as Map<String, dynamic>);
          _gateways[cfg.id] = cfg;
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture configuration paiements : $e');
    }
    notifyListeners();
  }

  void _initDefaults() {
    _gateways['wave'] = const PaymentGatewayConfig(
      id: 'wave',
      name: 'Wave Sénégal',
      description: 'Paiement instantané 0% frais via QR Code ou Push Wave',
      isEnabled: true,
      merchantCode: '774691379', // Numéro de compte marchand officiel
      isTestMode: true,
      brandColorValue: 0xFF00B2FE,
      iconIdentifier: 'wave',
    );

    _gateways['orange_money'] = const PaymentGatewayConfig(
      id: 'orange_money',
      name: 'Orange Money (OM)',
      description: 'Paiement sécurisé via code d\'autorisation #144#391#',
      isEnabled: true,
      merchantCode: 'OM-DIOUFY-SN',
      isTestMode: true,
      brandColorValue: 0xFFFF7900,
      iconIdentifier: 'orange_money',
    );

    _gateways['free_money'] = const PaymentGatewayConfig(
      id: 'free_money',
      name: 'Free Money',
      description: 'Paiement direct compte Free Money Sénégal',
      isEnabled: true,
      merchantCode: 'FREE-DIOUFY-SN',
      isTestMode: true,
      brandColorValue: 0xFFE60000,
      iconIdentifier: 'free_money',
    );

    _gateways['paydunya'] = const PaymentGatewayConfig(
      id: 'paydunya',
      name: 'PayDunya',
      description: 'Agrégateur multi-opérateurs (Wave, OM, Carte Bancaire, Free Money)',
      isEnabled: true,
      merchantCode: 'PAYDUNYA-DIOUFY',
      // Les secrets API résident exclusivement sur Supabase Edge Functions / Vault
      apiKey: null,
      apiSecret: null,
      isTestMode: true,
      brandColorValue: 0xFF059669,
      iconIdentifier: 'paydunya',
    );

    _gateways['flutterwave'] = const PaymentGatewayConfig(
      id: 'flutterwave',
      name: 'Flutterwave',
      description: 'Paiement Panafricain (Cartes Visa/Mastercard & Mobile Money)',
      isEnabled: true,
      merchantCode: 'FLW-DIOUFY-SN',
      // Clé publique configurable via environnement, secret strictement côté serveur
      apiKey: String.fromEnvironment('FLW_PUBLIC_KEY', defaultValue: ''),
      apiSecret: null,
      isTestMode: true,
      brandColorValue: 0xFFFB923C,
      iconIdentifier: 'flutterwave',
    );

    _gateways['paytech'] = const PaymentGatewayConfig(
      id: 'paytech',
      name: 'PayTech Sénégal',
      description: 'Passerelle locale sénégalaise rapide (Wave, OM, Carte)',
      isEnabled: true,
      merchantCode: 'PAYTECH-774691379',
      apiKey: null,
      apiSecret: null,
      isTestMode: true,
      brandColorValue: 0xFF6366F1,
      iconIdentifier: 'paytech',
    );

    _gateways['cash'] = const PaymentGatewayConfig(
      id: 'cash',
      name: 'Espèces au Quai / Guichet',
      description: 'Encaissement liquide direct par le coxeur ou le chauffeur',
      isEnabled: true,
      merchantCode: 'CASH-GARE',
      isTestMode: false,
      brandColorValue: 0xFF10B981,
      iconIdentifier: 'cash',
    );
  }

  /// Activer ou désactiver une passerelle de paiement
  Future<void> toggleGateway(String id, bool isEnabled) async {
    final existing = _gateways[id];
    if (existing == null) return;
    _gateways[id] = existing.copyWith(isEnabled: isEnabled);
    notifyListeners();
    await _persist();
  }

  /// Mettre à jour les paramètres techniques d'une passerelle (Code Marchand, Clés API)
  Future<void> updateGateway(PaymentGatewayConfig updated) async {
    _gateways[updated.id] = updated;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _gateways.values.map((g) => g.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Erreur persistance passerelles de paiement : $e');
    }
  }
}
