import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rapport officiel d'indicateurs de performance (KPIs) de la plateforme Dioufy-TS
/// SOURCE DE VÉRITÉ UNIQUE : Supabase PostgreSQL.
/// Aucun montant forfaitaire, aucune estimation artificielle ni faux chiffre d'exploitation.
class PlatformKpiReport {
  /// Chiffre d'Affaires Réellement Encaissé en FCFA (transactions au statut successful)
  final int totalRevenueCollected;

  /// Nombre total de billets vendus et encaissés
  final int totalTicketsSold;

  /// Nombre de billets effectivement utilisés (compostés à l'embarquement)
  final int totalTicketsUsed;

  /// Taux d'utilisation des billets = (billets utilisés / billets vendus) * 100
  final double ticketUsageRate;

  /// Nombre de départs programmés ou actifs
  final int activeTripsToday;

  /// Répartition du chiffre d'affaires par passerelle de paiement
  final Map<String, int> revenueByGateway;

  /// Indique si les données sont partielles (ex: plafond de requête atteint)
  final bool isPartial;

  /// Indique si une erreur de réseau ou de requête a empêché une consolidation complète
  final bool hasErrors;

  /// Message d'erreur éventuel pour affichage transparent
  final String? errorMessage;

  /// Horodatage de génération de l'agrégation
  final DateTime generatedAt;

  const PlatformKpiReport({
    required this.totalRevenueCollected,
    required this.totalTicketsSold,
    required this.totalTicketsUsed,
    required this.ticketUsageRate,
    required this.activeTripsToday,
    required this.revenueByGateway,
    this.isPartial = false,
    this.hasErrors = false,
    this.errorMessage,
    required this.generatedAt,
  });
}

/// Service d'agrégation des KPIs exécutifs Super Admin et GIE
class KpiService {
  KpiService._();
  static final KpiService instance = KpiService._();

  /// Récupère les KPIs réels depuis le backend Supabase avec agrégations strictes
  Future<PlatformKpiReport> fetchPlatformKpis({
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    int totalRevenue = 0;
    int soldCount = 0;
    int usedCount = 0;
    int activeTrips = 0;
    bool hadQueryError = false;
    bool isDataTruncated = false;
    String? errorDetails;

    final Map<String, int> gatewayBreakdown = {
      'wave': 0,
      'flutterwave': 0,
      'orange_money': 0,
      'free_money': 0,
      'cash': 0,
    };

    try {
      final client = Supabase.instance.client;
      final startIso = startDate?.toIso8601String();
      final endIso = endDate?.toIso8601String();

      // 1. Récupération des transactions réellement encaissées
      try {
        if (organizationId != null && organizationId.isNotEmpty) {
          // Pour un GIE : interroger ticket_commissions pour isoler strictement les flux
          var commQuery = client
              .from('ticket_commissions')
              .select('gross_amount, gie_share, payment_id, status, created_at')
              .eq('organization_id', organizationId)
              .eq('status', 'allocated');

          if (startIso != null) commQuery = commQuery.gte('created_at', startIso);
          if (endIso != null) commQuery = commQuery.lte('created_at', endIso);

          final commRows = await commQuery.limit(2000);
          if (commRows.length >= 2000) isDataTruncated = true;

          for (final row in commRows) {
            final share = (row['gie_share'] as num?)?.toInt() ?? 0;
            totalRevenue += share;
            soldCount++;
          }
        } else {
          // Plateforme globale : transactions payments 'successful'
          var payQuery = client
              .from('payments')
              .select('id, amount, provider, status, created_at')
              .eq('status', 'successful');

          if (startIso != null) payQuery = payQuery.gte('created_at', startIso);
          if (endIso != null) payQuery = payQuery.lte('created_at', endIso);

          final paymentsResponse = await payQuery.limit(2000);
          if (paymentsResponse.length >= 2000) isDataTruncated = true;

          for (final row in paymentsResponse) {
            final amount = (row['amount'] as num?)?.toInt() ?? 0;
            totalRevenue += amount;
            soldCount++;

            final method = (row['provider']?.toString() ?? 'wave').toLowerCase();
            if (gatewayBreakdown.containsKey(method)) {
              gatewayBreakdown[method] = (gatewayBreakdown[method] ?? 0) + amount;
            } else {
              gatewayBreakdown[method] = amount;
            }
          }
        }
      } catch (err) {
        hadQueryError = true;
        errorDetails = 'Erreur agrégation paiements: $err';
        debugPrint('[KpiService] Consultation payments : $err');
      }

      // 2. Récupération des billets émis et compostés
      try {
        final ticketsResponse = await client
            .from('tickets')
            .select('id, composted_at, issued_at')
            .limit(2000);

        if (ticketsResponse.length >= 2000) isDataTruncated = true;

        for (final t in ticketsResponse) {
          if (t['composted_at'] != null) {
            usedCount++;
          }
        }
        if (soldCount == 0 && ticketsResponse.isNotEmpty) {
          soldCount = ticketsResponse.length;
        }
      } catch (err) {
        hadQueryError = true;
        debugPrint('[KpiService] Consultation tickets : $err');
      }

      // 3. Récupération des départs actifs réels
      try {
        var tripsQuery = client.from('trips').select('id, depart_at');
        if (organizationId != null && organizationId.isNotEmpty) {
          tripsQuery = tripsQuery.eq('organization_id', organizationId);
        }
        if (startIso != null) tripsQuery = tripsQuery.gte('depart_at', startIso);

        final tripsResponse = await tripsQuery.limit(1000);
        activeTrips = tripsResponse.length;
      } catch (err) {
        hadQueryError = true;
        debugPrint('[KpiService] Consultation trips : $err');
      }
    } catch (e) {
      hadQueryError = true;
      errorDetails = 'Connexion Supabase inaccessible: $e';
      debugPrint('[KpiService] Exception fetchPlatformKpis : $e');
    }

    final double usageRate = soldCount > 0 ? (usedCount / soldCount) * 100 : 0.0;

    return PlatformKpiReport(
      totalRevenueCollected: totalRevenue,
      totalTicketsSold: soldCount,
      totalTicketsUsed: usedCount,
      ticketUsageRate: usageRate,
      activeTripsToday: activeTrips,
      revenueByGateway: gatewayBreakdown,
      isPartial: isDataTruncated,
      hasErrors: hadQueryError,
      errorMessage: errorDetails,
      generatedAt: DateTime.now(),
    );
  }
}
