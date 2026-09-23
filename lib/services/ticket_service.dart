import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _storageKey = 'dioufy_local_tickets_v1';

  /// Sauvegarde un billet dans le stockage local du smartphone (offline-first).
  static Future<void> saveTicketLocally(Map<String, dynamic> ticketData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJsonList = prefs.getStringList(_storageKey) ?? [];
      
      // Éviter les doublons par référence
      final newRef = ticketData['ref']?.toString();
      final filteredList = existingJsonList.where((item) {
        try {
          final decoded = jsonDecode(item);
          return decoded['ref']?.toString() != newRef;
        } catch (_) {
          return true;
        }
      }).toList();

      filteredList.insert(0, jsonEncode(ticketData));
      await prefs.setStringList(_storageKey, filteredList);
    } catch (_) {
      // Ignorer silencieusement si stockage non disponible
    }
  }

  /// Récupère la liste de tous les billets stockés localement sur l'appareil.
  static Future<List<Map<String, dynamic>>> getLocalTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      final List<Map<String, dynamic>> tickets = [];

      for (var item in jsonList) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            tickets.add(decoded);
          }
        } catch (_) {}
      }
      return tickets;
    } catch (_) {
      return [];
    }
  }

  /// Marque un billet comme utilisé / validé à l'embarquement
  static Future<bool> markTicketUsed(String ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      final List<String> updatedList = [];
      bool found = false;

      for (var item in jsonList) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          final tId = decoded['ref']?.toString() ?? decoded['ticketId']?.toString() ?? decoded['id']?.toString();
          if (tId == ref) {
            decoded['status'] = 'used';
            decoded['used_at'] = DateTime.now().toIso8601String();
            updatedList.add(jsonEncode(decoded));
            found = true;
          } else {
            updatedList.add(item);
          }
        } catch (_) {
          updatedList.add(item);
        }
      }

      if (found) {
        await prefs.setStringList(_storageKey, updatedList);
      }
      return found;
    } catch (_) {
      return false;
    }
  }
}
