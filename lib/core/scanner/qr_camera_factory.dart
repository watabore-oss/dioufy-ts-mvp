import 'qr_camera_controller.dart';
import 'qr_camera_factory_stub.dart'
    if (dart.library.js_interop) 'qr_camera_factory_web.dart' as impl;

/// Fabrique universelle fournissant l'instance de QrCameraController appropriée
QrCameraController createQrCameraController(String containerId) {
  return impl.createPlatformQrCameraController(containerId);
}
