import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modèle d'une session de clôture de caisse chauffeur certifiée
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
  final String? serverSignature;    // Empreinte cryptographique générée par Supabase
  final bool isSynced;              // Indique si la session a été confirmée sur le serveur

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
    this.serverSignature,
    this.isSynced = false,
  });

  /// Total brut généré par le voyage
  int get totalRevenue => digitalRevenue + cashRevenue;

  /// Commission instantanée du chauffeur (5% du total brut)
  int get driverCommission => (totalRevenue * driverCommissionRate).round();

  /// Frais de service plateforme Dioufy-TS
  int get platformFee => (totalRevenue * platformFeeRate).round();

  /// Solde net en espèces que le chauffeur doit physiquement remettre au GIE / Transporteur
  int get netCashToDeposit => cashRevenue - driverCommission - coxeurCommission;

  CashRegisterSession copyWith({
    String? id,
    String? tripId,
    String? busId,
    String? route,
    String? date,
    int? totalPassengers,
    int? digitalRevenue,
    int? cashRevenue,
    double? driverCommissionRate,
    int? coxeurCommission,
    double? platformFeeRate,
    DateTime? closedAt,
    bool? isClosed,
    String? serverSignature,
    bool? isSynced,
  }) {
    return CashRegisterSession(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      busId: busId ?? this.busId,
      route: route ?? this.route,
      date: date ?? this.date,
      totalPassengers: totalPassengers ?? this.totalPassengers,
      digitalRevenue: digitalRevenue ?? this.digitalRevenue,
      cashRevenue: cashRevenue ?? this.cashRevenue,
      driverCommissionRate: driverCommissionRate ?? this.driverCommissionRate,
      coxeurCommission: coxeurCommission ?? this.coxeurCommission,
      platformFeeRate: platformFeeRate ?? this.platformFeeRate,
      closedAt: closedAt ?? this.closedAt,
      isClosed: isClosed ?? this.isClosed,
      serverSignature: serverSignature ?? this.serverSignature,
      isSynced: isSynced ?? this.isSynced,
    );
  }

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
      'serverSignature': serverSignature,
      'isSynced': isSynced,
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
      serverSignature: map['serverSignature'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }
}

/// Service de gestion, calcul et persistance des clôtures de caisse
class CashRegisterService {
  static const String _storageKey = 'dioufy_cash_sessions_v1';

  /// Enregistre une clôture de caisse en local puis la synchronise avec Supabase
  static Future<CashRegisterSession> saveSession(CashRegisterSession session) async {
    // 1. Sauvegarde locale immédiate (résistance hors-ligne 100%)
    await _insertLocalSession(session);

    // 2. Synchronisation Supabase RPC
    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('close_cash_session', params: {
        'p_trip_id': session.tripId,
        'p_bus_id': session.busId,
        'p_route': session.route,
        'p_session_date': session.date,
        'p_total_passengers': session.totalPassengers,
        'p_digital_revenue': session.digitalRevenue,
        'p_cash_revenue': session.cashRevenue,
        'p_driver_commission_rate': session.driverCommissionRate,
        'p_coxeur_commission': session.coxeurCommission,
        'p_platform_fee_rate': session.platformFeeRate,
      }).timeout(const Duration(seconds: 4));

      if (res != null && res is Map) {
        final synced = session.copyWith(
          serverSignature: res['signature']?.toString(),
          isSynced: true,
        );
        await _updateLocalSession(synced);
        return synced;
      }
    } catch (e) {
      debugPrint('Enregistrement Supabase caisse en attente (mode hors-ligne): $e');
    }

    return session;
  }

  static Future<void> _insertLocalSession(CashRegisterSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      list.insert(0, jsonEncode(session.toMap()));
      await prefs.setStringList(_storageKey, list);
    } catch (_) {}
  }

  static Future<void> _updateLocalSession(CashRegisterSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      final updatedList = <String>[];
      for (final item in list) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          if (decoded['id'] == session.id) {
            updatedList.add(jsonEncode(session.toMap()));
          } else {
            updatedList.add(item);
          }
        } catch (_) {
          updatedList.add(item);
        }
      }
      await prefs.setStringList(_storageKey, updatedList);
    } catch (_) {}
  }

  /// Récupère toutes les clôtures enregistrées localement
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

  /// Tente de synchroniser les sessions hors-ligne non encore envoyées
  static Future<int> syncPendingSessions() async {
    int syncedCount = 0;
    try {
      final sessions = await getSessionHistory();
      final pending = sessions.where((s) => !s.isSynced).toList();
      for (final session in pending) {
        final synced = await saveSession(session);
        if (synced.isSynced) {
          syncedCount++;
        }
      }
    } catch (e) {
      debugPrint('Erreur sync sessions caisse: $e');
    }
    return syncedCount;
  }

  /// Génère le texte formaté du bordereau de clôture certifié pour envoi WhatsApp
  static String generateReceiptText(CashRegisterSession s) {
    final certifNotice = s.serverSignature != null
        ? "✅ Certifié par Dioufy Server (${s.serverSignature!.substring(0, 8)}...)"
        : "ℹ️ Enregistré localement (en attente sync réseau)";

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
$certifNotice
""";
  }
}
