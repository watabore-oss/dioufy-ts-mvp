import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:image_picker/image_picker.dart';

@JS('dioufyDecodeImage')
external JSPromise<JSString?> dioufyDecodeImage(JSString dataUrl);

/// Décodage local d'image sur le Web via le moteur universel DioufyQR (BarcodeDetector + jsQR)
Future<String?> decodeImageFile(XFile file) async {
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    String mime = 'image/jpeg';
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) {
      mime = 'image/png';
    } else if (lower.endsWith('.webp')) {
      mime = 'image/webp';
    }

    final base64Data = base64Encode(bytes);
    final dataUrl = 'data:$mime;base64,$base64Data';

    final jsPromise = dioufyDecodeImage(dataUrl.toJS);
    final jsResult = await jsPromise.toDart;
    final result = jsResult?.toDart;
    if (result != null && result.trim().isNotEmpty) {
      return result.trim();
    }
  } catch (e) {
    // Erreur JSInterop ou décodage
  }
  return null;
}

@JS('dioufyPickImageFromGallery')
external JSPromise<JSString?> dioufyPickImageFromGallery();

/// Sélecteur Galerie Web Direct & Infaillible (contourne les restrictions des navigateurs mobiles)
Future<String?> pickAndDecodeFromGallery() async {
  try {
    final jsPromise = dioufyPickImageFromGallery();
    final jsResult = await jsPromise.toDart;
    final result = jsResult?.toDart;
    if (result != null && result.trim().isNotEmpty) {
      return result.trim();
    }
  } catch (_) {}
  return null;
}

