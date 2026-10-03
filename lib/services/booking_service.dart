import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service responsable de la gestion des sièges et des réservations.
///
/// SOURCE DE VÉRITÉ UNIQUE : Supabase PostgreSQL.
/// RÈGLES DE SÉCURITÉ P0 :
/// - Verrouillage strict anti-doubles réservations (SELECT FOR UPDATE).
/// - Idempotence absolue via X-Request-ID.
/// - Aucun identifiant factice 'local_b_...' ni sièges de complaisance.
/// - Aucune confirmation de paiement unilatérale depuis le client sans validation serveur.
class BookingService {
  final SupabaseClient? _client;

  BookingService({SupabaseClient? client})
      : _client = client ?? _getSupabaseClientSafely();

  static SupabaseClient? _getSupabaseClientSafely() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isValidUuid(String str) => _uuidRegex.hasMatch(str);

  /// Génère un UUID unique pour l'idempotence
  String _generateRequestId(String operation) {
    return '$operation-${const Uuid().v4()}';
  }

  /// Récupère la liste des numéros de sièges occupés ou verrouillés pour un trajet
  Future<List<String>> getOccupiedSeats(String tripId) async {
    if (!_isValidUuid(tripId)) {
      return const [];
    }

    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from('seats')
            .select('seat_number, status, lock_until')
            .eq('trip_id', tripId)
            .timeout(const Duration(seconds: 4));

        final List list = response as List;
        final now = DateTime.now();
        final occupied = <String>[];

        for (var item in list) {
          if (item is Map) {
            final seatNumber = item['seat_number']?.toString();
            final status = item['status']?.toString();
            if (seatNumber == null) continue;

            if (status == 'occupied' || status == 'booked' || status == 'sold') {
              occupied.add(seatNumber);
            } else if (status == 'locked') {
              final lockUntilStr = item['lock_until']?.toString();
              if (lockUntilStr != null) {
                final lockUntil = DateTime.tryParse(lockUntilStr);
                if (lockUntil != null && lockUntil.isAfter(now)) {
                  occupied.add(seatNumber);
                }
              } else {
                occupied.add(seatNumber);
              }
            }
          }
        }
        return occupied;
      } catch (e) {
        debugPrint('[BookingService] Erreur récupération sièges Supabase : $e');
        return const [];
      }
    }

    return const [];
  }

  /// Verrouille un siège de façon transactionnelle via la fonction RPC `lock_seat`.
  /// Retourne le `booking_id` créé.
  Future<String> lockSeat({
    required String tripId,
    required String seatNumber,
    String? userId,
    int lockMinutes = 10,
    String? requestId,
  }) async {
    if (!_isValidUuid(tripId)) {
      throw ArgumentError('Identifiant de trajet non valide ($tripId).');
    }

    final client = _client;
    if (client == null) {
      throw Exception('Service de réservation non connecté.');
    }

    final reqId = requestId ?? _generateRequestId('lock-seat');

    try {
      final res = await client.rpc('lock_seat', params: {
        'p_trip_id': tripId,
        'p_seat_number': seatNumber,
        'p_user_id': userId,
        'p_lock_minutes': lockMinutes,
        'p_request_id': reqId,
      }).timeout(const Duration(seconds: 6));

      if (res != null) {
        return res.toString();
      }
      throw Exception('Échec de réservation du siège $seatNumber.');
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('not available') || errorMsg.contains('already')) {
        throw Exception('Le siège $seatNumber est déjà réservé ou en cours de réservation.');
      }
      debugPrint('[BookingService] Erreur lock_seat RPC : $e');
      throw Exception('Impossible de réserver le siège $seatNumber. Veuillez réessayer.');
    }
  }

  /// Verrouille plusieurs sièges de façon atomique avec rollback en cas d'échec
  Future<List<String>> lockSeatsBatch({
    required String tripId,
    required List<String> seatNumbers,
    String? userId,
    int lockMinutes = 10,
  }) async {
    final List<String> lockedBookingIds = [];

    try {
      for (var seat in seatNumbers) {
        final bookingId = await lockSeat(
          tripId: tripId,
          seatNumber: seat,
          userId: userId,
          lockMinutes: lockMinutes,
        );
        lockedBookingIds.add(bookingId);
      }
      return lockedBookingIds;
    } catch (e) {
      // Rollback immédiat des sièges déjà verrouillés
      for (var id in lockedBookingIds) {
        await releaseSeat(bookingId: id);
      }
      rethrow;
    }
  }

  /// Libère un siège associé à une réservation
  Future<void> releaseSeat({
    required String bookingId,
    String? requestId,
  }) async {
    if (!_isValidUuid(bookingId)) return;

    final client = _client;
    if (client != null) {
      try {
        final reqId = requestId ?? _generateRequestId('release-seat');
        await client.rpc('release_seat', params: {
          'p_booking_id': bookingId,
          'p_request_id': reqId,
        });
      } catch (e) {
        debugPrint('[BookingService] Erreur release_seat: $e');
      }
    }
  }

  /// Validation d'un paiement via la RPC sécurisée `confirm_payment`
  /// RÈGLE DE SÉCURITÉ P0 : Aucune altération directe non autorisée des tables `bookings`/`seats`/`payments`.
  Future<Map<String, dynamic>> confirmPayment({
    required List<String> bookingIds,
    required String provider,
    required String providerRef,
    required int amount,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Client Supabase non initialisé.');
    }

    final validIds = bookingIds.where(_isValidUuid).toList();
    if (validIds.isEmpty) {
      throw ArgumentError('Aucune réservation valide à confirmer.');
    }

    final unitAmount = amount ~/ validIds.length;
    Map<String, dynamic> lastResult = {};

    for (var bookingId in validIds) {
      final res = await client.rpc('confirm_payment', params: {
        'p_booking_id': bookingId,
        'p_provider': provider,
        'p_provider_ref': providerRef,
        'p_amount': unitAmount,
      });

      if (res is Map) {
        lastResult = Map<String, dynamic>.from(res);
        if (lastResult['success'] != true) {
          throw Exception(lastResult['message'] ?? 'Échec de confirmation du paiement.');
        }
      }
    }

    return lastResult;
  }
}
