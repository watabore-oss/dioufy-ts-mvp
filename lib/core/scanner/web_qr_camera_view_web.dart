import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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

/// Vue Caméra durcie pour Flutter Web (Safari iOS, Chrome Android, PWA)
/// Utilise la balise vidéo HTML5 durcie avec playsinline et sans dépendance CDN
class WebQrCameraView extends StatefulWidget {
  final String? containerId;
  final void Function(String rawCode) onDetect;
  final void Function(String errorCode, String message)? onError;

  const WebQrCameraView({
    super.key,
    this.containerId,
    required this.onDetect,
    this.onError,
  });

  @override
  State<WebQrCameraView> createState() => _WebQrCameraViewState();
}

class _WebQrCameraViewState extends State<WebQrCameraView> {
  late final String _containerId;
  late final String _viewType;
  late final web.HTMLDivElement _div;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _containerId = widget.containerId ?? 'dioufy_cam_${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'dioufy-qr-camera-$_containerId';

    _div = web.HTMLDivElement()
      ..id = _containerId
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = '#000000';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _div,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _startCamera();
      }
    });
  }

  void _startCamera() {
    try {
      dioufyStartCamera(
        _containerId.toJS,
        ((JSString rawCode) {
          if (!mounted || _isDisposed) return;
          widget.onDetect(rawCode.toDart);
        }).toJS,
        ((JSString errCode, JSString errMsg) {
          if (!mounted || _isDisposed) return;
          widget.onError?.call(errCode.toDart, errMsg.toDart);
        }).toJS,
        'environment'.toJS,
      );
    } catch (e) {
      if (mounted && !_isDisposed) {
        widget.onError?.call('CAMERA_INIT_FAILED', e.toString());
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      dioufyStopCamera(_containerId.toJS);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
