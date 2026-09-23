import 'package:flutter/foundation.dart';

/// États granulaires de la machine à états du scanner caméra
enum ScannerState {
  uninitialized,
  idle,
  requestingPermission,
  initializing,
  ready,
  scanning,
  candidateDetected,
  validating,
  success,
  invalid,
  paused,
  error,
}

/// Typologie des erreurs opérationnelles du sous-système caméra
enum ScannerErrorType {
  permissionDenied,
  cameraUnavailable,
  cameraBusy,
  lowLight,
  noDetection,
  hardwareError,
  decodingError,
  timeout,
  unknown,
}

/// Statuts stricts de validation cryptographique et métier du billet
enum TicketVerificationStatus {
  valid,
  duplicateInSession,
  duplicateServer,
  duplicatePersistent,
  forgedSignature,
  expiredDate,
  invalidRoute,
  invalidSeat,
  invalidFormat,
  ticketNotFound,
  networkError,
}

/// Modèle immuable représentant le résultat unifié et complet d'une analyse de billet Dioufy-TS
@immutable
class ScanResult {
  final String rawData;
  final TicketVerificationStatus status;
  final Map<String, dynamic>? payload;
  final String? ticketRef;
  final String? passengerName;
  final String? passengerPhone;
  final String? seats;
  final String? route;
  final String? departure;
  final String? arrival;
  final String? departureStation;
  final String? arrivalStation;
  final String? company;
  final String? date;
  final String? time;
  final int? amount;
  final DateTime timestamp;
  final DateTime? usedAt;
  final String? message;
  final bool isOfflineVerified;

  const ScanResult({
    required this.rawData,
    required this.status,
    this.payload,
    this.ticketRef,
    this.passengerName,
    this.passengerPhone,
    this.seats,
    this.route,
    this.departure,
    this.arrival,
    this.departureStation,
    this.arrivalStation,
    this.company,
    this.date,
    this.time,
    this.amount,
    required this.timestamp,
    this.usedAt,
    this.message,
    this.isOfflineVerified = false,
  });

  // Getters d'interopérabilité et de commodité
  String get rawValue => rawData;
  String? get ticketId => ticketRef;
  String? get seatNumber => seats;
  DateTime get scannedAt => timestamp;

  bool get isValid => status == TicketVerificationStatus.valid;
  bool get isDuplicate =>
      status == TicketVerificationStatus.duplicateInSession ||
      status == TicketVerificationStatus.duplicateServer ||
      status == TicketVerificationStatus.duplicatePersistent;
  bool get isAlreadyUsed => isDuplicate;
  bool get isForged => status == TicketVerificationStatus.forgedSignature;
  bool get isSigned =>
      status == TicketVerificationStatus.valid &&
      (payload != null &&
          (payload!.containsKey('sig') ||
              payload!.containsKey('signature') ||
              payload!.containsKey('hmac') ||
              isOfflineVerified));

  factory ScanResult.success({
    required String rawValue,
    required String ticketId,
    String? passengerName,
    String? passengerPhone,
    String? seatNumber,
    String? route,
    String? departure,
    String? arrival,
    String? departureStation,
    String? arrivalStation,
    String? company,
    String? date,
    String? time,
    int? amount,
    Map<String, dynamic>? payload,
    String? message,
    bool isOfflineVerified = false,
  }) {
    return ScanResult(
      rawData: rawValue,
      status: TicketVerificationStatus.valid,
      ticketRef: ticketId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      seats: seatNumber,
      route: route,
      departure: departure,
      arrival: arrival,
      departureStation: departureStation,
      arrivalStation: arrivalStation,
      company: company,
      date: date,
      time: time,
      amount: amount,
      payload: payload,
      message: message ?? 'Billet certifié authentique',
      timestamp: DateTime.now(),
      isOfflineVerified: isOfflineVerified,
    );
  }

  factory ScanResult.alreadyUsed({
    required String rawValue,
    String? ticketId,
    String? passengerName,
    String? passengerPhone,
    String? seatNumber,
    String? route,
    String? message,
    DateTime? usedAt,
    bool isDuplicateInSession = true,
  }) {
    return ScanResult(
      rawData: rawValue,
      status: isDuplicateInSession
          ? TicketVerificationStatus.duplicateInSession
          : TicketVerificationStatus.duplicatePersistent,
      ticketRef: ticketId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      seats: seatNumber,
      route: route,
      usedAt: usedAt,
      message: message ?? 'Attention : Ce billet a déjà été composté',
      timestamp: DateTime.now(),
    );
  }

  factory ScanResult.invalid({
    required String rawValue,
    String? message,
    TicketVerificationStatus status = TicketVerificationStatus.invalidFormat,
  }) {
    return ScanResult(
      rawData: rawValue,
      status: status,
      message: message ?? 'Format de billet QR non reconnu ou signature invalide',
      timestamp: DateTime.now(),
    );
  }
}
