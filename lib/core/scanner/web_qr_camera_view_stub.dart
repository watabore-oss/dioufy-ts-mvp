import 'package:flutter/material.dart';

/// Implémentation factice pour VM native (Android, iOS) et tests unitaires
class WebQrCameraView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
