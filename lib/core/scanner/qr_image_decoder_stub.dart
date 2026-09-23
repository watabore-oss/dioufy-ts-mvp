import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Décodage local d'image sur mobile natif (Android APK / iOS) et tests unitaires
Future<String?> decodeImageFile(XFile file) async {
  try {
    final controller = MobileScannerController();
    final capture = await controller.analyzeImage(file.path);
    await controller.dispose();
    if (capture != null && capture.barcodes.isNotEmpty) {
      final code = capture.barcodes.first.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        return code.trim();
      }
    }
  } catch (_) {
    // Repli silencieux en cas d'absence de support natif
  }
  return null;
}

/// Sélecteur Galerie Natif (Android APK / iOS)
Future<String?> pickAndDecodeFromGallery() async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file != null) {
      return await decodeImageFile(file);
    }
  } catch (_) {}
  return null;
}
