import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ticket_service.dart';
import '../core/scanner/camera_adapter.dart';
import '../core/scanner/frame_processor.dart';
import '../core/scanner/native_camera_adapter.dart';
import '../core/scanner/scan_session.dart';
import '../core/scanner/scan_stabilizer.dart';
import '../core/scanner/scanner_models.dart';
import '../core/scanner/ticket_verifier.dart';
import '../core/scanner/web_camera_adapter.dart';

export '../core/scanner/camera_adapter.dart';
export '../core/scanner/camera_lifecycle_controller.dart';
export '../core/scanner/coordinate_transformer.dart';
export '../core/scanner/frame_processor.dart';
export '../core/scanner/native_camera_adapter.dart';
export '../core/scanner/qr_decoder.dart';
export '../core/scanner/scan_session.dart';
export '../core/scanner/scan_stabilizer.dart';
export '../core/scanner/scanner_models.dart';
export '../core/scanner/ticket_verifier.dart';
export '../core/scanner/web_camera_adapter.dart';

/// Orchestrateur central unifié du pipeline de contrôle de billets Dioufy-TS
class ScannerService extends ChangeNotifier {
  static final ScannerService instance = ScannerService();

  ScannerState _state = ScannerState.idle;
  ScannerErrorType? _lastError;
  String? _statusMessage;
  ScanSession _session = ScanSession();
  final ScanStabilizer _stabilizer = ScanStabilizer();
  final FrameProcessor _frameProcessor = FrameProcessor();
  CameraAdapter? _adapter;

  String? _activeTripId;

  ScannerState get state => _state;
  ScannerErrorType? get lastError => _lastError;
  String? get statusMessage => _statusMessage;
  ScanSession get session => _session;
  int get processedCount => _session.processedCount;
  CameraAdapter? get adapter => _adapter;
  String? get activeTripId => _activeTripId;

  /// Initialise le capteur caméra approprié selon la plateforme (Natif CameraX ou Web)
  Future<CameraAdapter> initializeAdapter({bool preferNative = true}) async {
    if (kIsWeb || !preferNative) {
      _adapter = WebCameraAdapter();
    } else {
      _adapter = NativeCameraAdapter();
    }
    await _adapter!.initialize();
    _state = _adapter!.currentState;
    notifyListeners();
    return _adapter!;
  }

  /// Démarre une nouvelle session d'embarquement / contrôle avec rattachement au départ
  void startNewSession({String? sessionId, String? tripId}) {
    _activeTripId = tripId;
    _session = ScanSession(sessionId: sessionId);
    _stabilizer.reset();
    _state = ScannerState.ready;
    _statusMessage = 'Prêt à scanner';
    notifyListeners();
  }

  /// Passe la machine d'état en mode SCANNING
  void setScanning() {
    if (_state != ScannerState.scanning) {
      _state = ScannerState.scanning;
      _statusMessage = 'Alignez le QR code dans le cadre';
      notifyListeners();
    }
  }

  /// Traite une frame brute issue du flux vidéo continu
  /// Retourne un [ScanResult] uniquement lorsque le QR est stabilisé et validé
  Future<ScanResult?> onFrameDetected(String? rawBarcode) async {
    // 1. Cadencement adaptatif (throttling ~16 FPS)
    final accepted = _frameProcessor.process(rawBarcode);
    if (!accepted) return null;

    // 2. Stabilisation multi-frames (2 lectures concordantes consécutives)
    final stabilizedValue = _stabilizer.processCandidate(rawBarcode);
    if (stabilizedValue == null) {
      if (_stabilizer.hasCandidate && _state != ScannerState.candidateDetected) {
        _state = ScannerState.candidateDetected;
        _statusMessage = 'Stabilisation du QR Code...';
        notifyListeners();
      }
      return null;
    }

    // 3. Validation cryptographique HMAC-SHA256, validité et déduplication
    _state = ScannerState.validating;
    _statusMessage = 'Vérification cryptographique du billet...';
    notifyListeners();

    final result = await TicketVerifier.verifyTicket(
      rawValue: stabilizedValue,
      session: _session,
      tripId: _activeTripId,
    );

    // 4. Retours haptiques et mise à jour de l'état
    if (result.isValid) {
      _state = ScannerState.success;
      final passenger = result.passengerName ?? 'Passager';
      final seat = result.seatNumber ?? 'Libre';
      _statusMessage = 'Billet validé : $passenger ($seat)';
      HapticFeedback.heavyImpact();
    } else if (result.isAlreadyUsed) {
      _state = ScannerState.invalid;
      _statusMessage = result.message ?? 'Attention : Ce billet a déjà été composté';
      HapticFeedback.vibrate();
    } else {
      _state = ScannerState.invalid;
      _statusMessage = result.message ?? 'Billet non reconnu';
      HapticFeedback.vibrate();
    }

    notifyListeners();

    // 5. Réarmement automatique vers SCANNING après un bref délai
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_state == ScannerState.success || _state == ScannerState.invalid) {
        _state = ScannerState.scanning;
        _statusMessage = 'Alignez le prochain billet';
        notifyListeners();
      }
    });

    return result;
  }

  /// Traite directement un code issu d'une image fixe (Galerie) ou saisie manuelle (Clavier)
  /// sans passer par le stabilisateur multi-frames ni le régulateur FPS
  Future<ScanResult> validateDirectCode(String rawCode, {String? tripId}) async {
    final clean = rawCode.trim();
    if (clean.isEmpty) {
      _state = ScannerState.invalid;
      _statusMessage = 'Code vide';
      notifyListeners();
      return ScanResult.invalid(
        rawValue: '',
        message: 'Le code fourni est vide.',
      );
    }

    _stabilizer.processDirectValue(clean);

    _state = ScannerState.validating;
    _statusMessage = 'Vérification du billet...';
    notifyListeners();

    final result = await TicketVerifier.verifyTicket(
      rawValue: clean,
      session: _session,
      tripId: tripId ?? _activeTripId,
    );

    if (result.isValid) {
      _state = ScannerState.success;
      final passenger = result.passengerName ?? 'Passager';
      final seat = result.seatNumber ?? 'Libre';
      _statusMessage = 'Billet validé : $passenger ($seat)';
      HapticFeedback.heavyImpact();
    } else if (result.isAlreadyUsed) {
      _state = ScannerState.invalid;
      _statusMessage = result.message ?? 'Attention : Ce billet a déjà été composté';
      HapticFeedback.vibrate();
    } else {
      _state = ScannerState.invalid;
      _statusMessage = result.message ?? 'Billet non reconnu';
      HapticFeedback.vibrate();
    }

    notifyListeners();
    return result;
  }

  /// Confirme définitivement l'embarquement du passager pour la référence de billet donnée
  Future<void> confirmBoarding(String ticketRef) async {
    _session.registerProcessed(ticketRef);
    await TicketService.markTicketUsed(ticketRef);
    notifyListeners();
  }

  /// Enregistre une anomalie capteur
  void setError(ScannerErrorType error, String message) {
    _state = ScannerState.error;
    _lastError = error;
    _statusMessage = message;
    notifyListeners();
  }

  /// Réinitialise le stabilisateur
  void reset() {
    _stabilizer.reset();
    _state = ScannerState.ready;
    notifyListeners();
  }

  @override
  void dispose() {
    _frameProcessor.dispose();
    _adapter?.dispose();
    super.dispose();
  }
}
