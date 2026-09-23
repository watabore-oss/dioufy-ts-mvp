import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants.dart';
import '../../core/scanner/qr_camera_controller.dart';
import '../../core/scanner/qr_camera_factory.dart';
import '../../core/scanner/native_qr_camera_controller.dart';
import '../../core/scanner/qr_image_decoder.dart';
import '../../core/scanner/scanner_models.dart';
import '../../core/scanner/web_qr_camera_view.dart';
import '../../services/scanner/scanner_service.dart';

/// Scanner Optique Professionnel Haute Définition (Zebra / Honeywell Cockpit Style)
/// Standard industriel universel (Android Chrome/APK, iOS Safari, PWA).
/// 100% des boutons connectés, zéro superposition de texte, affichage FCFA + XOF.
class QrCameraScannerScreen extends StatefulWidget {
  const QrCameraScannerScreen({super.key});

  @override
  State<QrCameraScannerScreen> createState() => _QrCameraScannerScreenState();
}

class _QrCameraScannerScreenState extends State<QrCameraScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final String _containerId;
  late final QrCameraController _cameraController;
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  final ImagePicker _picker = ImagePicker();
  ScanResult? _lastScanResult;
  bool _isDisposed = false;
  bool _isSheetOpen = false;
  bool _isAnalyzingImage = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _containerId = 'dioufy_cockpit_${DateTime.now().microsecondsSinceEpoch}';
    _cameraController = createQrCameraController(_containerId);

    // Initialisation et abonnement aux flux du contrôleur caméra
    _cameraController.initialize();
    _cameraController.onCodeDetected.listen((rawCode) {
      if (!_isDisposed && !_isSheetOpen && !_isAnalyzingImage) {
        _handleDetectedCode(rawCode);
      }
    });

    _cameraController.onError.listen((errorMsg) {
      if (!_isDisposed && mounted) {
        setState(() => _cameraErrorMessage = errorMsg);
      }
    });

    // Démarrage animation réticule laser industriel
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 8, end: 220).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    // Initialisation de la session d'embarquement
    ScannerService.instance.startNewSession();
    ScannerService.instance.setScanning();
    _cameraController.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed && !_isDisposed && !_isSheetOpen) {
      _cameraController.start();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  /// Traitement d'un code QR détecté (Caméra Live ou Photo HD)
  Future<void> _handleDetectedCode(String rawCode) async {
    if (_isSheetOpen || _isAnalyzingImage) return;

    // Arrêt temporaire de la caméra pour figer la scène lors de la validation
    _cameraController.stop();

    final result = await ScannerService.instance.onFrameDetected(rawCode);
    if (result != null && mounted) {
      setState(() => _lastScanResult = result);
      _showTicketResultSheet(result);
    } else {
      // Reprise si code non stabilisé
      _cameraController.start();
    }
  }

  /// Déclenchement de la capture Photo HD manuelle (Mode Secours QR difficile/froissé)
  Future<void> _triggerManualPhotoCapture() async {
    if (_isAnalyzingImage) return;
    setState(() => _isAnalyzingImage = true);

    try {
      String? detectedCode;

      if (kIsWeb) {
        // Extraction de frame haute définition directement depuis le flux vidéo
        detectedCode = await _cameraController.capturePhoto();
      }

      // Si non supporté sur le flux ou échec, bascule sur le capteur photo natif
      if (detectedCode == null) {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (photo != null) {
          detectedCode = await QrImageDecoder.decodeImageFile(photo);
        }
      }

      if (detectedCode != null && detectedCode.trim().isNotEmpty) {
        final result = await ScannerService.instance.validateDirectCode(detectedCode.trim());
        if (mounted) {
          setState(() {
            _isAnalyzingImage = false;
            _lastScanResult = result;
          });
          _showTicketResultSheet(result);
          return;
        }
      }

      if (mounted) {
        setState(() => _isAnalyzingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("Aucun QR Code net repéré sur la photo. Réessayez."),
              ],
            ),
            backgroundColor: Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Capture photo non conclue : $e"),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Import et décodage instantané depuis la galerie (Billet WhatsApp, photo, capture)
  Future<void> _pickAndScanFromGallery() async {
    if (_isAnalyzingImage) return;

    try {
      // Déclenchement direct synchrone pour préserver le contexte d'interaction utilisateur
      final String? code = await QrImageDecoder.pickAndDecodeFromGallery();

      if (code != null && code.trim().isNotEmpty) {
        final result = await ScannerService.instance.validateDirectCode(code.trim());
        if (mounted) {
          setState(() {
            _isAnalyzingImage = false;
            _lastScanResult = result;
          });
          _showTicketResultSheet(result);
          return;
        }
      } else {
        if (mounted) {
          setState(() => _isAnalyzingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.image_not_supported_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Aucun QR Code valide repéré sur cette image."),
                ],
              ),
              backgroundColor: Color(0xFF334155),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lecture de l'image interrompue : $e"),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Fiche modale d'inspection et validation du billet (Boarding Pass Industriel)
  void _showTicketResultSheet(ScanResult result) {
    setState(() => _isSheetOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (ctx) {
        final isValid = result.isValid;
        final isDuplicate = result.isAlreadyUsed;
        final passenger = result.passengerName ?? 'Voyageur Dioufy';
        final seats = result.seatNumber ?? 'Libre';
        final route = result.route ?? 'Ligne Interurbaine';
        final ref = result.ticketId ?? (result.rawValue.length > 20 ? '${result.rawValue.substring(0, 20)}...' : result.rawValue);
        final company = result.company ?? 'Dioufy Express';
        final amount = result.amount;

        Color headerColor = const Color(0xFF059669); // Vert émeraude sécurité
        IconData headerIcon = Icons.verified;
        String headerTitle = "BILLET AUTHENTIQUE CERTIFIÉ";

        if (isDuplicate) {
          headerColor = const Color(0xFFD97706); // Ambre avertissement
          headerIcon = Icons.warning_amber_rounded;
          headerTitle = "BILLET DÉJÀ COMPOSTÉ";
        } else if (!isValid) {
          headerColor = const Color(0xFFDC2626); // Rouge sécurité
          headerIcon = Icons.gpp_bad_outlined;
          headerTitle = "BILLET NON RECONNU OU SUSPECT";
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black87, blurRadius: 25, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // En-tête Statut de Contrôle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: headerColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(headerIcon, color: headerColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerTitle,
                              style: TextStyle(
                                color: headerColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              result.message ?? (isValid ? 'Embarquement autorisé' : 'Contrôle requis'),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Carte Détail Passager & Sièges
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF38BDF8), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('VOYAGEUR', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(
                                  passenger,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          // Siège Géant
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                            ),
                            child: Column(
                              children: [
                                const Text('SIÈGE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold)),
                                Text(seats, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TRAJET', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(
                                  route,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                Text(company, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          // Prix en FCFA avec Badge cercle XOF
                          if (amount != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('MONTANT PAYÉ', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$amount FCFA',
                                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    const XofCurrencyBadge(size: 14),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Empreinte Cryptographique & Référence
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            result.isSigned ? Icons.verified_user : Icons.lock_open,
                            size: 15,
                            color: result.isSigned ? const Color(0xFF34D399) : Colors.white38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            result.isSigned ? "HMAC SHA-256 Valide" : "Billet sans signature",
                            style: TextStyle(
                              color: result.isSigned ? const Color(0xFF34D399) : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Réf: $ref",
                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bouton d'action principal
                if (isValid) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text(
                      "VALIDER L'EMBARQUEMENT",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      ScannerService.instance.confirmBoarding(ref);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text("Passager $passenger composté avec succès !"),
                            ],
                          ),
                          backgroundColor: const Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Fermer"),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isSheetOpen = false);
        ScannerService.instance.setScanning();
        _cameraController.start();
      }
    });
  }

  /// Dialogue de saisie manuelle de secours
  void _showManualPrompt({String? title, String? message}) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title ?? "Saisie Manuelle de Référence",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            const Text(
              "Référence du billet (ex: TICK-88201) :",
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "TICK-...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final val = textController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                final result = await ScannerService.instance.validateDirectCode(val);
                if (mounted) {
                  setState(() => _lastScanResult = result);
                  _showTicketResultSheet(result);
                }
              }
            },
            child: const Text("Valider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Retour page précédente',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Scanner Optique Embarqué",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          // Bouton Torche Connecté avec Détection Réelle des Capacités
          IconButton(
            icon: Icon(
              _cameraController.isTorchSupported
                  ? (_cameraController.isTorchOn ? Icons.flash_on : Icons.flash_off)
                  : Icons.flash_off_outlined,
              color: _cameraController.isTorchSupported
                  ? (_cameraController.isTorchOn ? const Color(0xFFFBBF24) : Colors.white70)
                  : Colors.white24,
            ),
            tooltip: _cameraController.isTorchSupported
                ? (_cameraController.isTorchOn ? "Désactiver la torche" : "Activer la torche")
                : "Torche non disponible sur ce capteur",
            onPressed: _cameraController.isTorchSupported
                ? () async {
                    await _cameraController.toggleTorch();
                    if (mounted) setState(() {});
                  }
                : null,
          ),
          // Bouton Bascule Caméra Connecté (Web & Natif)
          if (_cameraController.canSwitchCamera)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
              tooltip: "Bascule capteur avant/arrière",
              onPressed: () async {
                await _cameraController.switchCamera();
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final totalWidth = constraints.maxWidth;

          // Dimensions rigides pour éviter toute superposition
          final topHudHeight = 64.0;
          final bottomBarHeight = 90.0;
          final availableScanHeight = totalHeight - topHudHeight - bottomBarHeight;

          final scanBoxSize = (totalWidth * 0.70).clamp(210.0, availableScanHeight.clamp(200.0, 310.0));

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Couche Vidéo Fond plein écran
              if (kIsWeb)
                WebQrCameraView(
                  containerId: _containerId,
                  onDetect: _handleDetectedCode,
                  onError: (code, msg) {
                    if (mounted) setState(() => _cameraErrorMessage = msg);
                  },
                )
              else if (_cameraController is NativeQrCameraController)
                MobileScanner(
                  controller: (_cameraController as NativeQrCameraController).mobileScannerController,
                  fit: BoxFit.cover,
                ),

              // 2. HUD Supérieur Industriel (Top Bar Compacte Zéro Chevauchement)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topHudHeight,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF0F172A).withOpacity(0.85),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "VISION OPTIQUE ACTIVE",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                          ),
                          child: Text(
                            "${ScannerService.instance.processedCount} Passagers",
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Cadre de Visée Industriel Centré (Zebra / Honeywell Réticule)
              Positioned(
                top: topHudHeight + (availableScanHeight - scanBoxSize) / 2,
                left: (totalWidth - scanBoxSize) / 2,
                width: scanBoxSize,
                height: scanBoxSize,
                child: _buildIndustrialViseur(scanBoxSize),
              ),

              // 4. Cartouche d'indication sous le viseur (Zéro collision)
              Positioned(
                top: topHudHeight + (availableScanHeight - scanBoxSize) / 2 + scanBoxSize + 12,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      ScannerService.instance.statusMessage ?? "Alignez le QR code dans le réticule",
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // 5. Indicateur d'Analyse en cours
              if (_isAnalyzingImage)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF38BDF8)),
                          SizedBox(height: 16),
                          Text(
                            "Décodage haute précision en mémoire...",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 6. Panneau de Contrôle Inférieur Cockpit (Photo / Galerie / Clavier)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: bottomBarHeight,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.95),
                      border: const Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Bouton Photo Haute Définition
                        _buildCockpitButton(
                          icon: Icons.camera_alt_outlined,
                          label: "Photo HD",
                          onTap: _triggerManualPhotoCapture,
                        ),
                        Container(width: 1, height: 28, color: Colors.white12),
                        // Bouton Galerie / WhatsApp
                        _buildCockpitButton(
                          icon: Icons.photo_library_outlined,
                          label: "Galerie",
                          onTap: _pickAndScanFromGallery,
                        ),
                        Container(width: 1, height: 28, color: Colors.white12),
                        // Bouton Clavier Manuel
                        _buildCockpitButton(
                          icon: Icons.keyboard_alt_outlined,
                          label: "Clavier",
                          onTap: () => _showManualPrompt(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCockpitButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustrialViseur(double size) {
    const borderColor = Color(0xFF10B981); // Vert d'acquisition industrielle

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor.withOpacity(0.35), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Coins biseautés renforcés
          Positioned(top: 0, left: 0, child: _cornerMarker(isTop: true, isLeft: true)),
          Positioned(top: 0, right: 0, child: _cornerMarker(isTop: true, isLeft: false)),
          Positioned(bottom: 0, left: 0, child: _cornerMarker(isTop: false, isLeft: true)),
          Positioned(bottom: 0, right: 0, child: _cornerMarker(isTop: false, isLeft: false)),

          // Réticule laser dynamique
          AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) {
              return Positioned(
                top: _laserAnimation.value.clamp(10.0, size - 20),
                left: 14,
                right: 14,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFF34D399),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF34D399).withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cornerMarker({required bool isTop, required bool isLeft}) {
    const color = Color(0xFF10B981);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: color, width: 3.5) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: color, width: 3.5) : BorderSide.none,
          left: isLeft ? const BorderSide(color: color, width: 3.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: color, width: 3.5) : BorderSide.none,
        ),
      ),
    );
  }
}
