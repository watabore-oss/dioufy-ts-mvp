import 'dart:async';
import 'dart:js_interop';
import 'qr_camera_controller.dart';

@JS('dioufyStartCamera')
external void dioufyStartCamera(
  JSString containerId,
  JSFunction onDetect,
  JSFunction onError,
  JSString? initialFacing,
);

@JS('dioufyStopCamera')
external void dioufyStopCamera(JSString containerId);

@JS('dioufyToggleTorch')
external JSPromise<JSBoolean> dioufyToggleTorch(JSString containerId);

@JS('dioufyIsTorchSupported')
external JSBoolean dioufyIsTorchSupported(JSString containerId);

@JS('dioufyIsTorchOn')
external JSBoolean dioufyIsTorchOn(JSString containerId);

@JS('dioufySwitchCamera')
external JSPromise<JSString> dioufySwitchCamera(JSString containerId);

@JS('dioufyCapturePhoto')
external JSPromise<JSString?> dioufyCapturePhoto(JSString containerId);

/// Implémentation Web durcie pilotant le moteur JavaScript dioufy_qr_engine.js
class WebQrCameraController implements QrCameraController {
  final String containerId;
  final _codeController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isTorchOn = false;
  QrCameraFacing _facing = QrCameraFacing.back;

  WebQrCameraController({required this.containerId});

  @override
  bool get isTorchSupported {
    try {
      return dioufyIsTorchSupported(containerId.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isTorchOn => _isTorchOn;

  @override
  bool get canSwitchCamera => true;

  @override
  QrCameraFacing get currentFacing => _facing;

  @override
  Stream<String> get onCodeDetected => _codeController.stream;

  @override
  Stream<String> get onError => _errorController.stream;

  @override
  Future<void> initialize() async {
    // Initialisation gérée au montage du composant DOM
  }

  @override
  Future<void> start() async {
    try {
      final facingStr = _facing == QrCameraFacing.back ? 'environment' : 'user';
      dioufyStartCamera(
        containerId.toJS,
        ((JSString rawCode) {
          if (!_codeController.isClosed) {
            _codeController.add(rawCode.toDart);
          }
        }).toJS,
        ((JSString errCode, JSString errMsg) {
          if (!_errorController.isClosed) {
            _errorController.add(errMsg.toDart);
          }
        }).toJS,
        facingStr.toJS,
      );
    } catch (e) {
      _errorController.add("Erreur démarrage flux caméra : $e");
    }
  }

  @override
  Future<void> stop() async {
    try {
      dioufyStopCamera(containerId.toJS);
    } catch (_) {}
  }

  @override
  Future<void> switchCamera() async {
    try {
      final promise = dioufySwitchCamera(containerId.toJS);
      final nextFacingJs = await promise.toDart;
      final nextStr = nextFacingJs.toDart;
      _facing = nextStr == 'user' ? QrCameraFacing.front : QrCameraFacing.back;
    } catch (e) {
      _errorController.add("Erreur bascule caméra : $e");
    }
  }

  @override
  Future<void> toggleTorch() async {
    if (!isTorchSupported) return;
    try {
      final promise = dioufyToggleTorch(containerId.toJS);
      final res = await promise.toDart;
      _isTorchOn = res.toDart;
    } catch (e) {
      _errorController.add("Erreur lampe torche : $e");
    }
  }

  @override
  Future<String?> capturePhoto() async {
    try {
      final promise = dioufyCapturePhoto(containerId.toJS);
      final res = await promise.toDart;
      return res?.toDart;
    } catch (e) {
      _errorController.add("Erreur capture photo HD : $e");
      return null;
    }
  }

  @override
  void dispose() {
    stop();
    _codeController.close();
    _errorController.close();
  }
}
