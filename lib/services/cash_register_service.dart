import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle d'une session de clôture de caisse chauffeur
class CashRegisterSession {
  final String id;
  final String tripId;
  final String busId;
  final String route;
  final String date;
  final int totalPassengers;
  final int digitalRevenue; // Encaissements Wave / Orange Money / Free Money
  final int cashRevenue;    // Encaissements en espèces au quai
  final double driverCommissionRate; // Ex: 0.05 pour 5%
  final int coxeurCommission;        // Ex: 2000 FCFA
  final double platformFeeRate;      // Ex: 0.025 pour 2.5%
  final DateTime closedAt;
  final bool isClosed;

  const CashRegisterSession({
    required this.id,
    required this.tripId,
    this.busId = "DK-882-SN",
    this.route = "Dakar → Touba",
    required this.date,
    required this.totalPassengers,
    required this.digitalRevenue,
    required this.cashRevenue,
    this.driverCommissionRate = 0.05,
    this.coxeurCommission = 2000,
    this.platformFeeRate = 0.025,
    required this.closedAt,
    this.isClosed = true,
  });

  /// Total brut généré par le voyage
  int get totalRevenue => digitalRevenue + cashRevenue;

  /// Commission instantanée du chauffeur (5% du total brut)
  int get driverCommission => (totalRevenue * driverCommissionRate).round();

  /// Frais de service plateforme Dioufy-TS
  int get platformFee => (totalRevenue * platformFeeRate).round();

  /// Solde net en espèces que le chauffeur doit physiquement remettre au GIE / Transporteur
  int get netCashToDeposit => cashRevenue - driverCommission - coxeurCommission;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'busId': busId,
      'route': route,
      'date': date,
      'totalPassengers': totalPassengers,
      'digitalRevenue': digitalRevenue,
      'cashRevenue': cashRevenue,
      'driverCommissionRate': driverCommissionRate,
      'coxeurCommission': coxeurCommission,
      'platformFeeRate': platformFeeRate,
      'closedAt': closedAt.toIso8601String(),
      'isClosed': isClosed,
    };
  }

  factory CashRegisterSession.fromMap(Map<String, dynamic> map) {
    return CashRegisterSession(
      id: map['id'] ?? '',
      tripId: map['tripId'] ?? '',
      busId: map['busId'] ?? 'DK-882-SN',
      route: map['route'] ?? 'Dakar → Touba',
      date: map['date'] ?? '',
      totalPassengers: (map['totalPassengers'] as num?)?.toInt() ?? 0,
      digitalRevenue: (map['digitalRevenue'] as num?)?.toInt() ?? 0,
      cashRevenue: (map['cashRevenue'] as num?)?.toInt() ?? 0,
      driverCommissionRate: (map['driverCommissionRate'] as num?)?.toDouble() ?? 0.05,
      coxeurCommission: (map['coxeurCommission'] as num?)?.toInt() ?? 2000,
      platformFeeRate: (map['platformFeeRate'] as num?)?.toDouble() ?? 0.025,
      closedAt: map['closedAt'] != null
          ? DateTime.parse(map['closedAt'].toString())
          : DateTime.now(),
      isClosed: map['isClosed'] ?? true,
    );
  }
}

/// Service de gestion et de persistance des clôtures de caisse
class CashRegisterService {
  static const String _storageKey = 'dioufy_cash_sessions_v1';

  /// Enregistre une clôture de caisse en local (persistance hors-ligne)
  static Future<void> saveSession(CashRegisterSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      list.insert(0, jsonEncode(session.toMap()));
      await prefs.setStringList(_storageKey, list);
    } catch (_) {}
  }

  /// Récupère toutes les clôtures enregistrées
  static Future<List<CashRegisterSession>> getSessionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      final List<CashRegisterSession> sessions = [];
      for (var item in list) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            sessions.add(CashRegisterSession.fromMap(decoded));
          }
        } catch (_) {}
      }
      return sessions;
    } catch (_) {
      return [];
    }
  }

  /// Génère le texte formaté du bordereau de clôture pour envoi WhatsApp
  static String generateReceiptText(CashRegisterSession s) {
    return """
━━━━━━━━━━━━━━━━━━━━━
🚌 *DIOUFY-TS • BORDEREAU DE CLÔTURE DE CAISSE*
━━━━━━━━━━━━━━━━━━━━━
📍 *Trajet :* ${s.route}
🆔 *Bus :* ${s.busId}
📅 *Date :* ${s.date} à ${s.closedAt.hour.toString().padLeft(2, '0')}:${s.closedAt.minute.toString().padLeft(2, '0')}
👥 *Passagers à bord :* ${s.totalPassengers}

💰 *VENTILATION DES RECETTES :*
• Digital (Wave / OM) : ${s.digitalRevenue} FCFA
• Espèces (au quai)   : ${s.cashRevenue} FCFA
👉 *TOTAL RECETTES :* ${s.totalRevenue} FCFA

✂️ *COMMISSIONS DÉDUITES :*
• Chauffeur (5%) : ${s.driverCommission} FCFA
• Coxeur / Gare  : ${s.coxeurCommission} FCFA
• Plateforme     : ${s.platformFee} FCFA

💵 *SOLDE NET ESPÈCES À REVERSER AU GIE :*
👉 *${s.netCashToDeposit} FCFA*
━━━━━━━━━━━━━━━━━━━━━
Bordereau certifié conforme par Dioufy-TS Live.
""";
  }
}
