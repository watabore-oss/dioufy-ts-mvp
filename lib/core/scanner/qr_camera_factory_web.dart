import 'qr_camera_controller.dart';
import 'web_qr_camera_controller.dart';

QrCameraController createPlatformQrCameraController(String containerId) {
  return WebQrCameraController(containerId: containerId);
}
