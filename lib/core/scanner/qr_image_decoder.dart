import 'package:image_picker/image_picker.dart';
import 'qr_image_decoder_stub.dart'
    if (dart.library.js_interop) 'qr_image_decoder_web.dart' as impl;

/// Décodeur universel d'images fixes pour QR Codes (Galerie, Photos, Captures).
/// Fonctionne 100% en local sans aucun transfert réseau :
/// - Sur le Web : conversion Base64 en RAM + BarcodeDetector / jsQR local
/// - Sur Natif : analyseur natif CameraX / MLKit
class QrImageDecoder {
  const QrImageDecoder._();

  static Future<String?> decodeImageFile(XFile file) async {
    return await impl.decodeImageFile(file);
  }

  /// Ouvre la galerie du terminal (ou de la PWA Web) et décode directement l'image
  static Future<String?> pickAndDecodeFromGallery() async {
    return await impl.pickAndDecodeFromGallery();
  }
}
