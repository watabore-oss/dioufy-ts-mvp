import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service responsable de la gestion des sieges et des reservations.
///
/// Utilise la procedure PostgreSQL atomique `lock_seat` garantissant :
/// - Le verrouillage strict anti-doubles reservations (SELECT FOR UPDATE).
/// - L''idempotence absolue via X-Request-ID.
/// - La liberation automatique ou manuelle en cas d''annulation.
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

  /// Genere un UUID unique pour l''idempotence
  String _generateRequestId(String operation) {
    return '$operation-${const Uuid().v4()}';
  }

  /// Recupere la liste des numeros de sieges occupes ou verrouilles pour un trajet
  Future<List<String>> getOccupiedSeats(String tripId) async {
    // Si l'identifiant n'est pas un UUID valide, repli local instantané (0ms)
    if (!_isValidUuid(tripId)) {
      return const ['A3', 'B2', 'C5', 'D1'];
    }

    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from('seats')
            .select('seat_number, status, lock_until')
            .eq('trip_id', tripId)
            .timeout(const Duration(milliseconds: 1500));

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
        debugPrint('Recuperation sieges Supabase : $e');
        return const [];
      }
    }

    return const [];
  }

  /// Verrouille un siege de facon transactionnelle via la fonction RPC `lock_seat`.
  ///
  /// Retourne le `booking_id` cree.
  /// Leve une exception explicite en cas de siege indisponible ou de collision.
  Future<String> lockSeat({
    required String tripId,
    required String seatNumber,
    String? userId,
    int lockMinutes = 10,
    String? requestId,
  }) async {
    final reqId = requestId ?? _generateRequestId('lock-seat');

    // Trajets locaux / démo hors-ligne (identifiants non-UUID)
    if (!_isValidUuid(tripId)) {
      final prefix = tripId.length >= 4 ? tripId.substring(0, 4) : tripId;
      return 'local_b_$prefix-$seatNumber';
    }

    final client = _client;
    if (client != null) {
      try {
        final res = await client.rpc('lock_seat', params: {
          'p_trip_id': tripId,
          'p_seat_number': seatNumber,
          'p_user_id': userId,
          'p_lock_minutes': lockMinutes,
          'p_request_id': reqId,
        }).timeout(const Duration(milliseconds: 4000));

        if (res != null) {
          return res.toString();
        }
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('not available') || errorMsg.contains('already')) {
          throw Exception('Le siège $seatNumber est déjà réservé ou en cours de réservation.');
        }
        debugPrint('Erreur lock_seat RPC Supabase : $e');
        throw Exception('Impossible de réserver le siège $seatNumber. Veuillez vérifier votre connexion et réessayer.');
      }
    }

    throw Exception('Service de réservation temporairement indisponible. Veuillez réessayer.');
  }

  /// Verrouille plusieurs sieges de facon atomique.
  ///
  /// Si un seul siege echoue (collision), tous les sieges deja verrouilles
  /// de ce lot sont automatiquement liberes (rollback applicatif).
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
      // Rollback : liberation immediate des sieges deja verrouilles
      for (var id in lockedBookingIds) {
        await releaseSeat(bookingId: id);
      }
      rethrow;
    }
  }

  /// Libere un siege associe a une reservation.
  Future<void> releaseSeat({
    required String bookingId,
    String? requestId,
  }) async {
    // Si c'est un identifiant local ou démo, aucun appel réseau nécessaire
    if (bookingId.startsWith('local_') || bookingId.startsWith('demo-')) {
      return;
    }

    final client = _client;
    if (client != null) {
      try {
        final reqId = requestId ?? _generateRequestId('release-seat');
        await client.rpc('release_seat', params: {
          'p_booking_id': bookingId,
          'p_request_id': reqId,
        });
      } catch (e) {
        debugPrint('Erreur release_seat: $e');
      }
    }
  }

  /// Confirme le paiement et bascule les sieges en vendus via RPC securisee ou mise a jour directe.
  Future<void> confirmPayment({
    required List<String> bookingIds,
    required String provider,
    required String providerRef,
    required int amount,
  }) async {
    final client = _client;
    if (client == null) return;

    final unitAmount = amount ~/ (bookingIds.isEmpty ? 1 : bookingIds.length);

    for (var bookingId in bookingIds) {
      if (bookingId.startsWith('local_') || bookingId.startsWith('demo-')) {
        continue;
      }

      bool rpcSuccess = false;
      try {
        await client.rpc('confirm_payment', params: {
          'p_booking_id': bookingId,
          'p_provider': provider,
          'p_provider_ref': providerRef,
          'p_amount': unitAmount,
        });
        rpcSuccess = true;
      } catch (e) {
        debugPrint('Tentative RPC confirm_payment ($e) -> bascule mise a jour directe Supabase');
      }

      if (!rpcSuccess) {
        try {
          // 1. Mettre a jour la reservation a 'paid'
          await client
              .from('bookings')
              .update({'status': 'paid'})
              .eq('id', bookingId);

          // 2. Mettre a jour les sieges lies a 'sold'
          await client
              .from('seats')
              .update({'status': 'sold', 'lock_until': null})
              .eq('locked_by', bookingId);

          // 3. Inserer le paiement de facon idempotente
          final idempKey = '${providerRef}_$bookingId';
          await client.from('payments').upsert({
            'booking_id': bookingId,
            'amount': unitAmount,
            'provider': provider,
            'provider_ref': providerRef,
            'status': 'successful',
            'idempotency_key': idempKey,
          }, onConflict: 'idempotency_key');
        } catch (dbErr) {
          debugPrint('Erreur confirmation directe Supabase: $dbErr');
        }
      }
    }
  }
}
