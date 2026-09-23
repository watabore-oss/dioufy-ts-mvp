import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Données structurelles décodées d'un QR code de billet Dioufy-TS
class DecodedTicketData {
  final String raw;
  final bool isStructuredJson;
  final Map<String, dynamic>? rawJson;
  final Map<String, dynamic>? payload;
  final String? signature;
  final String ticketId;
  final String passengerName;
  final String? passengerPhone;
  final String seatNumber;
  final String route;
  final String? departure;
  final String? arrival;
  final String? departureStation;
  final String? arrivalStation;
  final String? company;
  final String? date;
  final String? time;
  final int? amount;

  const DecodedTicketData({
    required this.raw,
    required this.isStructuredJson,
    this.rawJson,
    this.payload,
    this.signature,
    required this.ticketId,
    required this.passengerName,
    this.passengerPhone,
    required this.seatNumber,
    required this.route,
    this.departure,
    this.arrival,
    this.departureStation,
    this.arrivalStation,
    this.company,
    this.date,
    this.time,
    this.amount,
  });
}

/// Décodeur spécialisé et robuste pour les billets Dioufy-TS
class QRDecoder {
  /// Décode une chaîne brute (JSON signé, JSON simple ou référence texte) en données de billet typées
  static DecodedTicketData decode(String rawInput) {
    final clean = rawInput.trim();

    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final dynamic parsed = jsonDecode(clean);
        if (parsed is Map<String, dynamic>) {
          Map<String, dynamic> payloadMap;
          String? signature = parsed['signature']?.toString();

          if (parsed.containsKey('payload') && parsed['payload'] is Map) {
            payloadMap = Map<String, dynamic>.from(parsed['payload'] as Map);
          } else {
            payloadMap = parsed;
          }

          return _fromPayload(clean, true, parsed, payloadMap, signature);
        }
      } catch (e) {
        debugPrint('[QRDecoder] Erreur parsing JSON: $e');
      }
    }

    // Format référence brute ou URL
    String ref = clean;
    if (clean.contains('ticket?ref=')) {
      final uri = Uri.tryParse(clean);
      if (uri != null && uri.queryParameters.containsKey('ref')) {
        ref = uri.queryParameters['ref']!;
      }
    } else if (clean.contains('/ticket/')) {
      ref = clean.split('/ticket/').last.split('?').first;
    }

    return DecodedTicketData(
      raw: clean,
      isStructuredJson: false,
      ticketId: ref,
      passengerName: 'Voyageur Dioufy',
      seatNumber: 'Libre',
      route: 'Ligne Directe',
    );
  }

  static DecodedTicketData _fromPayload(
    String raw,
    bool isStructuredJson,
    Map<String, dynamic> rawJson,
    Map<String, dynamic> payload,
    String? signature,
  ) {
    // 1. Référence / TicketId
    final ticketId = payload['ref']?.toString() ??
        payload['ticketId']?.toString() ??
        payload['id']?.toString() ??
        raw;

    // 2. Passager & Contact
    final passengerName = payload['passenger_name']?.toString() ??
        payload['passengerName']?.toString() ??
        payload['passenger']?.toString() ??
        payload['nom']?.toString() ??
        'Voyageur Dioufy';

    final passengerPhone = payload['passenger_phone']?.toString() ??
        payload['phone']?.toString() ??
        payload['telephone']?.toString();

    // 3. Sièges (Support Liste ou chaîne)
    String seatNumber = 'Libre';
    final rawSeats = payload['seats'] ?? payload['seat'] ?? payload['seatNumber'];
    if (rawSeats is List) {
      seatNumber = rawSeats.map((e) => e.toString()).join(', ');
    } else if (rawSeats != null) {
      seatNumber = rawSeats.toString();
    }

    // 4. Trajet & Compagnies
    Map<String, dynamic>? tripMap;
    if (payload['trip'] is Map) {
      tripMap = Map<String, dynamic>.from(payload['trip'] as Map);
    }

    final departure = tripMap?['departure']?.toString() ?? payload['departure']?.toString();
    final arrival = tripMap?['arrival']?.toString() ?? payload['arrival']?.toString();
    final departureStation = tripMap?['departureStation']?.toString() ?? payload['departureStation']?.toString();
    final arrivalStation = tripMap?['arrivalStation']?.toString() ?? payload['arrivalStation']?.toString();
    final company = tripMap?['company']?.toString() ?? payload['company']?.toString() ?? 'Dioufy Express';
    final date = tripMap?['date']?.toString() ?? payload['date']?.toString();
    final time = tripMap?['time']?.toString() ?? payload['time']?.toString();

    String route = 'Ligne Directe';
    if (departure != null && departure.isNotEmpty && arrival != null && arrival.isNotEmpty) {
      route = '$departure → $arrival';
    } else if (payload['route'] != null) {
      route = payload['route'].toString();
    }

    // 5. Montant
    int? amount;
    final rawAmount = payload['amount'] ?? payload['price'] ?? payload['prix'] ?? tripMap?['price'];
    if (rawAmount is num) {
      amount = rawAmount.toInt();
    } else if (rawAmount is String) {
      amount = int.tryParse(rawAmount);
    }

    return DecodedTicketData(
      raw: raw,
      isStructuredJson: isStructuredJson,
      rawJson: rawJson,
      payload: payload,
      signature: signature,
      ticketId: ticketId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      seatNumber: seatNumber,
      route: route,
      departure: departure,
      arrival: arrival,
      departureStation: departureStation,
      arrivalStation: arrivalStation,
      company: company,
      date: date,
      time: time,
      amount: amount,
    );
  }
}
