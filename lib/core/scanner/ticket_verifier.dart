import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ticket_service.dart';
import 'qr_decoder.dart';
import 'scan_session.dart';
import 'scanner_models.dart';

/// Vérificateur cryptographique HMAC et métier de billets Dioufy (Offline-First & Persistant)
class TicketVerifier {
  static const String _offlineQueueKey = 'dioufy_offline_scans_queue_v1';

  static SupabaseClient? _getSupabaseClientSafely() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Alias de compatibilité ascendante
  static Future<ScanResult> verifyAndProcessTicket({
    required String rawValue,
    required ScanSession session,
    String? tripId,
  }) =>
      verifyTicket(rawValue: rawValue, session: session, tripId: tripId);

  /// Vérifie et composte un billet à partir d'une chaîne brute stabilisée ou directe
  static Future<ScanResult> verifyTicket({
    required String rawValue,
    required ScanSession session,
    String? tripId,
  }) async {
    final cleanValue = rawValue.trim();
    if (cleanValue.isEmpty) {
      return ScanResult.invalid(
        rawValue: cleanValue,
        message: 'Code vide ou illisible.',
      );
    }

    // 1. Décodage structurel et extraction des champs
    final decoded = QRDecoder.decode(cleanValue);

    // 2. Déduplication stricte dans la session en RAM active
    if (session.isProcessed(cleanValue) || session.isProcessed(decoded.ticketId)) {
      return ScanResult.alreadyUsed(
        rawValue: cleanValue,
        ticketId: decoded.ticketId,
        passengerName: decoded.passengerName,
        passengerPhone: decoded.passengerPhone,
        seatNumber: decoded.seatNumber,
        route: decoded.route,
        message: 'Ce billet a déjà été validé dans cette session d\'embarquement.',
        isDuplicateInSession: true,
      );
    }

    try {
      // 3. Consultation prioritaire du serveur central PostgreSQL via la RPC atomique compost_ticket / board_ticket
      final client = _getSupabaseClientSafely();
      if (client != null) {
        try {
          final refToQuery = decoded.ticketId.isNotEmpty ? decoded.ticketId : cleanValue;
          final dynamic rpcRes = await client.rpc('compost_ticket', params: {
            'p_ticket_ref': refToQuery,
            if (tripId != null && tripId.isNotEmpty) 'p_trip_id': tripId,
          }).timeout(const Duration(milliseconds: 3000));

          if (rpcRes is Map) {
            final isSuccess = rpcRes['success'] == true;
            final statusStr = rpcRes['status']?.toString();
            final message = rpcRes['message']?.toString();

            if (statusStr == 'ALREADY_USED') {
              final usedAtStr = rpcRes['used_at']?.toString();
              final usedAt = usedAtStr != null ? DateTime.tryParse(usedAtStr) : null;
              return ScanResult.alreadyUsed(
                rawValue: cleanValue,
                ticketId: decoded.ticketId,
                passengerName: decoded.passengerName,
                passengerPhone: decoded.passengerPhone,
                seatNumber: decoded.seatNumber,
                route: decoded.route,
                usedAt: usedAt,
                message: message ?? 'Attention : Ce billet a déjà été composté.',
                isDuplicateInSession: false,
              );
            }

            if (statusStr == 'UNPAID') {
              return ScanResult.invalid(
                rawValue: cleanValue,
                status: TicketVerificationStatus.ticketNotFound,
                message: message ?? 'Billet non payé ou annulé.',
              );
            }

            if (statusStr == 'WRONG_TRIP') {
              return ScanResult.invalid(
                rawValue: cleanValue,
                status: TicketVerificationStatus.invalidRoute,
                message: message ?? 'Billet valide pour un autre trajet.',
              );
            }

            if (isSuccess && statusStr == 'VALIDATED') {
              session.registerProcessed(cleanValue);
              session.registerProcessed(decoded.ticketId);
              await TicketService.markTicketUsed(decoded.ticketId);

              return ScanResult.success(
                rawValue: cleanValue,
                ticketId: decoded.ticketId,
                passengerName: decoded.passengerName,
                passengerPhone: decoded.passengerPhone,
                seatNumber: decoded.seatNumber,
                route: decoded.route,
                departure: decoded.departure,
                arrival: decoded.arrival,
                departureStation: decoded.departureStation,
                arrivalStation: decoded.arrivalStation,
                company: decoded.company,
                date: decoded.date,
                time: decoded.time,
                amount: decoded.amount,
                payload: decoded.payload,
                message: message ?? 'Billet certifié et composté sur le serveur central',
                isOfflineVerified: false,
              );
            }
          }
        } catch (e) {
          debugPrint('Vérification temps réel Supabase non disponible (repli hors-ligne): $e');
        }
      }

      // 4. Consultation du stockage local persistant (SharedPreferences)
      final localTickets = await TicketService.getLocalTickets();
      Map<String, dynamic>? matchingTicket;

      for (final t in localTickets) {
        final tRef = t['ref']?.toString() ?? t['ticketId']?.toString() ?? t['id']?.toString();
        if (tRef != null && (tRef == decoded.ticketId || tRef == cleanValue)) {
          matchingTicket = t;
          break;
        }
      }

      // 5. Cas : Billet déjà composté dans l'historique persistant local
      if (matchingTicket != null && matchingTicket['status'] == 'used') {
        final usedAtStr = matchingTicket['used_at']?.toString();
        final usedAt = usedAtStr != null ? DateTime.tryParse(usedAtStr) : null;
        final passName = matchingTicket['passenger_name']?.toString() ?? decoded.passengerName;
        final passPhone = matchingTicket['passenger_phone']?.toString() ?? decoded.passengerPhone;
        final seats = _extractSeats(matchingTicket['seats']) ?? decoded.seatNumber;
        final route = _extractRoute(matchingTicket['trip']) ?? decoded.route;

        return ScanResult.alreadyUsed(
          rawValue: cleanValue,
          ticketId: decoded.ticketId,
          passengerName: passName,
          passengerPhone: passPhone,
          seatNumber: seats,
          route: route,
          usedAt: usedAt,
          message: 'Attention : Ce billet a déjà été composté${usedAt != null ? ' à ${_formatTime(usedAt)}' : ''}.',
          isDuplicateInSession: false,
        );
      }

      // 6. Cas : Billet structuré avec signature cryptographique HMAC-SHA256 (Mode secours hors-ligne)
      if (decoded.isStructuredJson && decoded.payload != null) {
        final signature = decoded.signature;
        final isValidSignature = signature != null && TicketService.verify(decoded.payload!, signature);

        if (!isValidSignature) {
          return ScanResult.invalid(
            rawValue: cleanValue,
            status: TicketVerificationStatus.forgedSignature,
            message: 'Signature cryptographique invalide (HMAC). Billet suspect ou contrefait.',
          );
        }

        // Billet authentique certifié : marquer comme utilisé
        await TicketService.markTicketUsed(decoded.ticketId);

        // Si le billet n'était pas encore en base locale, on l'enregistre comme utilisé
        if (matchingTicket == null) {
          await TicketService.saveTicketLocally({
            'ref': decoded.ticketId,
            'trip': decoded.payload!['trip'] ?? {
              'departure': decoded.departure ?? 'Dakar',
              'arrival': decoded.arrival ?? 'Région',
              'company': decoded.company ?? 'Dioufy Express',
              'date': decoded.date ?? '',
              'time': decoded.time ?? '',
            },
            'seats': decoded.payload!['seats'] ?? [decoded.seatNumber],
            'passenger_name': decoded.passengerName,
            'passenger_phone': decoded.passengerPhone,
            'amount': decoded.amount ?? 0,
            'status': 'used',
            'used_at': DateTime.now().toIso8601String(),
          });
        }

        // Inscrire dans la session d'embarquement en RAM
        session.registerProcessed(cleanValue);
        session.registerProcessed(decoded.ticketId);

        // Mettre en file d'attente hors-ligne pour synchronisation ultérieure
        await _enqueueOfflineScan(
          ticketId: decoded.ticketId,
          rawValue: cleanValue,
          scannedAt: DateTime.now(),
        );

        return ScanResult.success(
          rawValue: cleanValue,
          ticketId: decoded.ticketId,
          passengerName: decoded.passengerName,
          passengerPhone: decoded.passengerPhone,
          seatNumber: decoded.seatNumber,
          route: decoded.route,
          departure: decoded.departure,
          arrival: decoded.arrival,
          departureStation: decoded.departureStation,
          arrivalStation: decoded.arrivalStation,
          company: decoded.company,
          date: decoded.date,
          time: decoded.time,
          amount: decoded.amount,
          payload: decoded.payload,
          message: 'Billet certifié authentique (validé hors-ligne)',
          isOfflineVerified: true,
        );
      }

      // 7. Cas : Billet non structuré mais trouvé dans les réservations locales (ex: Saisie manuelle de référence)
      if (matchingTicket != null) {
        await TicketService.markTicketUsed(decoded.ticketId);
        session.registerProcessed(cleanValue);
        session.registerProcessed(decoded.ticketId);

        final tripMap = matchingTicket['trip'] is Map ? matchingTicket['trip'] as Map<String, dynamic> : null;
        final passName = matchingTicket['passenger_name']?.toString() ?? 'Voyageur Dioufy';
        final passPhone = matchingTicket['passenger_phone']?.toString();
        final seats = _extractSeats(matchingTicket['seats']) ?? 'Libre';
        final route = _extractRoute(tripMap) ?? 'Ligne Directe';
        final amount = matchingTicket['amount'] is num ? (matchingTicket['amount'] as num).toInt() : null;

        await _enqueueOfflineScan(
          ticketId: decoded.ticketId,
          rawValue: cleanValue,
          scannedAt: DateTime.now(),
        );

        return ScanResult.success(
          rawValue: cleanValue,
          ticketId: decoded.ticketId,
          passengerName: passName,
          passengerPhone: passPhone,
          seatNumber: seats,
          route: route,
          departure: tripMap?['departure']?.toString(),
          arrival: tripMap?['arrival']?.toString(),
          departureStation: tripMap?['departureStation']?.toString(),
          arrivalStation: tripMap?['arrivalStation']?.toString(),
          company: tripMap?['company']?.toString() ?? 'Dioufy Express',
          date: tripMap?['date']?.toString(),
          time: tripMap?['time']?.toString(),
          amount: amount,
          payload: matchingTicket,
          message: 'Billet vérifié avec succès (base locale)',
          isOfflineVerified: true,
        );
      }

      // 8. Billet non reconnu : AUCUN passe-droit sans preuve serveur ou cryptographique
      return ScanResult.invalid(
        rawValue: cleanValue,
        status: TicketVerificationStatus.ticketNotFound,
        message: 'Billet non reconnu ou référence inconnue.',
      );
    } catch (e) {
      return ScanResult.invalid(
        rawValue: cleanValue,
        status: TicketVerificationStatus.invalidFormat,
        message: 'Erreur lors de la vérification du billet ($e)',
      );
    }
  }

  static String? _extractSeats(dynamic rawSeats) {
    if (rawSeats is List) {
      return rawSeats.map((e) => e.toString()).join(', ');
    } else if (rawSeats != null) {
      return rawSeats.toString();
    }
    return null;
  }

  static String? _extractRoute(dynamic rawTrip) {
    if (rawTrip is Map) {
      final dep = rawTrip['departure']?.toString();
      final arr = rawTrip['arrival']?.toString();
      if (dep != null && arr != null) return '$dep → $arr';
    }
    return null;
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Sauvegarde le scan dans la file d'attente hors-ligne
  static Future<void> _enqueueOfflineScan({
    required String ticketId,
    required String rawValue,
    required DateTime scannedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? <String>[];
      final item = jsonEncode({
        'ticketId': ticketId,
        'rawValue': rawValue,
        'scannedAt': scannedAt.toIso8601String(),
        'status': 'scanned_offline',
      });
      queue.add(item);
      await prefs.setStringList(_offlineQueueKey, queue);
    } catch (_) {}
  }

  /// Retourne le nombre de scans en attente de synchronisation backend
  static Future<int> getPendingSyncCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_offlineQueueKey) ?? <String>[]).length;
    } catch (_) {
      return 0;
    }
  }
}
