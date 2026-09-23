import 'qr_camera_controller.dart';
import 'native_qr_camera_controller.dart';

QrCameraController createPlatformQrCameraController(String containerId) {
  return NativeQrCameraController();
}
