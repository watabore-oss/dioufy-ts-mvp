import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service utilitaire pour génération et vérification de tickets QR.
/// Le secret de signature doit être injecté via la variable d'environnement
/// `TICKET_SECRET` au moment du build (flutter build --dart-define=TICKET_SECRET=...) .
class TicketService {
  static final _secret =
      const String.fromEnvironment('TICKET_SECRET', defaultValue: 'changeme');

  /// Calcule la signature HMAC-SHA256 d'un payload JSON.
  static String signPayload(Map<String, dynamic> payload) {
    final key = utf8.encode(_secret);
    final msg = utf8.encode(jsonEncode(payload));
    final hmac = Hmac(sha256, key);
    return hmac.convert(msg).toString();
  }

  /// Vérifie que [signature] correspond bien au [payload].
  static bool verify(Map<String, dynamic> payload, String signature) {
    final expected = signPayload(payload);
    return expected == signature;
  }

  /// Emballe un ticket dans une chaîne prête à encoder en QR.
  /// Le format est {"payload":...,"signature":"..."}
  static String encodeTicket(Map<String, dynamic> payload) {
    final sig = signPayload(payload);
    final map = {'payload': payload, 'signature': sig};
    return jsonEncode(map);
  }

  /// Décode un texte de ticket et retourne les deux parties.
  /// Lance [FormatException] si le JSON est invalide.
  static Map<String, dynamic> decodeTicket(String text) {
    final data = jsonDecode(text);
    if (data is Map &&
        data.containsKey('payload') &&
        data.containsKey('signature')) {
      return data as Map<String, dynamic>;
    }
    throw FormatException('Ticket invalide');
  }
}
