import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Service responsable des appels backend liés à la réservation.
///
/// Utilise les Edge Functions `lock-seat` et `release-seat`.
/// Tous les appels sont **idempotents** via request_id.
class BookingService {
  // L'URL de votre projet Supabase (obtenue depuis les settings)
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  // Le chemin de l'API fonctions (même host que Supabase + `/functions/v1`)
  static const _functionsBase = '$_supabaseUrl/functions/v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'supabase_access_token');
  }

  /// Génère un UUID unique pour l'idempotence
  String _generateRequestId(String operation) {
    return '$operation-${const Uuid().v4()}';
  }

  /// Tente de verrouiller le siège et crée une réservation en base.
  ///
  /// - Retourne l'ID de la réservation (booking_id) si succès.
  /// - La même `requestId` retourne toujours le même booking_id (idempotent).
  /// - Lance une [Exception] avec le message d'erreur.
  Future<String> lockSeat({
    required String tripId,
    required String seatNumber,
    int lockMinutes = 10,
    String? requestId,
  }) async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Utilisateur non authentifié');

    final reqId = requestId ?? _generateRequestId('lock-seat');

    final res = await http.post(
      Uri.parse('$_functionsBase/lock-seat'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Request-ID': reqId,
      },
      body: jsonEncode({
        'trip_id': tripId,
        'seat_number': seatNumber,
        'lock_minutes': lockMinutes,
        'request_id': reqId,
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Erreur de verrouillage');
    }

    return body['booking_id'] as String;
  }

  /// Libère un siège pour une réservation annulée.
  ///
  /// - Sûr à appeler plusieurs fois : la même `requestId` n'a aucun effet secondaire après la 1ère call.
  Future<void> releaseSeat({
    required String bookingId,
    String? requestId,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return;

    final reqId = requestId ?? _generateRequestId('release-seat');

    await http.post(
      Uri.parse('$_functionsBase/release-seat'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Request-ID': reqId,
      },
      body: jsonEncode({
        'booking_id': bookingId,
        'request_id': reqId,
      }),
    );
  }
}
