import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/scanner/scanner_service.dart';
import 'cloture_caisse_screen.dart';
import 'qr_camera_scanner_screen.dart';

class ChauffeurScreen extends StatefulWidget {
  const ChauffeurScreen({super.key});

  @override
  State<ChauffeurScreen> createState() => _ChauffeurScreenState();
}

class _ChauffeurScreenState extends State<ChauffeurScreen> {
  int _scannedCount = 0;
  int _totalCapacity = 36;
  String _routeLine = "Chargement...";
  String _busMatricule = "EN ATTENTE";
  String? _currentTripId;
  bool _isLoadingTrip = true;
  final List<Map<String, dynamic>> _validationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadDriverAssignedTrip();
  }

  /// Chargement du trajet réel assigné au chauffeur connecté depuis Supabase
  Future<void> _loadDriverAssignedTrip() async {
    setState(() => _isLoadingTrip = true);
    try {
      final currentUserId = AuthService.instance.currentUser.id;

      // Si l'utilisateur n'est pas identifié ou n'a pas d'identifiant chauffeur réel
      if (currentUserId.isEmpty || currentUserId.startsWith('guest_')) {
        if (mounted) {
          setState(() {
            _currentTripId = null;
            _routeLine = "Aucun trajet assigné";
            _busMatricule = "NON ASSIGNÉ";
            _totalCapacity = 0;
            _scannedCount = 0;
            _isLoadingTrip = false;
          });
        }
        return;
      }

      final client = Supabase.instance.client;

      // Recherche STRICTEMENT restreinte aux trajets assignés à ce chauffeur précis
      final tripsRes = await client
          .from('trips')
          .select('id, from_loc, to_loc, seats_count, status, vehicles(plate_number, capacity), seats(id, status)')
          .eq('driver_id', currentUserId)
          .order('depart_at', ascending: false)
          .limit(1);

      if (tripsRes.isNotEmpty) {
        final trip = tripsRes.first;
        final tId = trip['id']?.toString();
        final from = trip['from_loc']?.toString() ?? 'Départ';
        final to = trip['to_loc']?.toString() ?? 'Arrivée';
        final vMap = trip['vehicles'] as Map?;
        final plate = vMap?['plate_number']?.toString() ?? 'AFFECTATION EN COURS';
        final cap = (vMap?['capacity'] as num?)?.toInt() ?? (trip['seats_count'] as num?)?.toInt() ?? 36;

        // Calculer les passagers déjà à bord (sièges sold/occupied)
        int boarded = 0;
        if (trip['seats'] is List) {
          final sList = trip['seats'] as List;
          boarded = sList.where((s) => s['status'] == 'sold' || s['status'] == 'occupied').length;
        }

        if (mounted) {
          setState(() {
            _currentTripId = tId;
            _routeLine = '$from → $to';
            _busMatricule = plate;
            _totalCapacity = cap;
            _scannedCount = boarded;
            _isLoadingTrip = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[ChauffeurScreen] Erreur chargement trajet assigné: $e');
    }

    if (mounted) {
      setState(() {
        _currentTripId = null;
        _routeLine = "Aucun trajet assigné";
        _busMatricule = "NON ASSIGNÉ";
        _totalCapacity = 0;
        _scannedCount = 0;
        _isLoadingTrip = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 24),
            tooltip: 'Retour',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          title: const Text(
            'Poste Chef de Bord',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
              tooltip: 'Actualiser',
              onPressed: _loadDriverAssignedTrip,
            ),
            Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: Center(
                child: Text(
                  'BUS: $_busMatricule',
                  style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
        body: _isLoadingTrip
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
            : SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tableau de bord indicateurs
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _stat(
                              'Passagers à bord',
                              '$_scannedCount/$_totalCapacity',
                              const Color(0xFF0F172A),
                              Icons.group,
                            ),
                          ),
                          Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _stat(
                              'Ligne en cours',
                              _routeLine,
                              const Color(0xFF1D4ED8),
                              Icons.route,
                              isTextSmall: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.volume_up, color: Color(0xFFB45309), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _totalCapacity > _scannedCount
                                  ? 'Il reste ${_totalCapacity - _scannedCount} passagers attendus avant départ'
                                  : 'Capacité atteinte (Complet)',
                              style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

              // Bouton Principal 1 : Scanner Caméra & Galerie
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
                label: const Text(
                  'SCANNER CAMÉRA / GALERIE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                ),
                onPressed: _openCameraScanner,
              ),

              const SizedBox(height: 10),

              // Bouton Principal 2 : Clôture de Caisse Chauffeur
              ElevatedButton.icon(
                icon: const Icon(Icons.point_of_sale, size: 24, color: Colors.white),
                label: const Text(
                  'CLÔTURE DE CAISSE DU VOYAGE',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClotureCaisseScreen(
                        totalPassengers: _scannedCount,
                        busId: _busMatricule,
                        route: _routeLine,
                        tripId: _currentTripId,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Option de saisie manuelle de secours
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.keyboard_alt_outlined, color: Color(0xFF1D4ED8), size: 20),
                  label: const Text(
                    "Saisie manuelle d'un code billet",
                    style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showManualScannerDialog,
                ),
              ),

              const SizedBox(height: 14),

              // Historique des scans récents
              const Text(
                'Dernières validations',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _validationHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.history, color: Color(0xFF94A3B8), size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Aucun billet scanné pour ce voyage.\nUtilisez le scanner caméra ci-dessus.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _validationHistory.length,
                        itemBuilder: (context, index) {
                          final item = _validationHistory[index];
                          final isValid = item['isValid'] as bool;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isValid ? Icons.check_circle : Icons.cancel,
                                  color: isValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Inconnu',
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Sièges: ${item['seats'] ?? '-'} • ${item['time'] ?? ''}",
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isValid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isValid ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Text(
                                    isValid ? 'AUTORISÉ' : 'REJETÉ',
                                    style: TextStyle(
                                      color: isValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 10),

              // Statut de transmission
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text(
                      'Système de synchronisation Dioufy-TS Live',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _stat(String label, String value, Color color, IconData icon, {bool isTextSmall = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1D4ED8), size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isTextSmall ? 19 : 25,
            fontWeight: FontWeight.w900,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _openCameraScanner() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrCameraScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _processTicketVerification(scannedCode);
    }
  }

  void _showManualScannerDialog() {
    final ticketController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.qr_code_scanner, color: Color(0xFFFBBF24)),
            SizedBox(width: 10),
            Text('Validation Manuelle', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collez le jeton signé ou le code du billet :',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ticketController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Collez la chaîne QR ou le code du billet...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final code = ticketController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(context);
              _processTicketVerification(code);
            },
            child: const Text('Vérifier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processTicketVerification(String code) async {
    final result = await ScannerService.instance.validateDirectCode(code);
    final String passengerName = result.passengerName ?? 'Voyageur Dioufy';
    final String seatsStr = result.seatNumber ?? '1';
    final String ticketId = result.ticketId ?? code;
    final bool isValid = result.isValid;
    final bool isDuplicate = result.isAlreadyUsed;

    setState(() {
      if (isValid) {
        _scannedCount++;
      }
      _validationHistory.insert(0, {
        'isValid': isValid,
        'isDuplicate': isDuplicate,
        'name': passengerName,
        'seats': seatsStr,
        'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      });
    });

    _showResultSheet(
      isValid: isValid,
      isDuplicate: isDuplicate,
      passengerName: passengerName,
      seatsStr: seatsStr,
      ticketId: ticketId,
      route: result.route,
      errorMessage: !isValid ? result.message : null,
    );
  }

  void _showResultSheet({
    required bool isValid,
    bool isDuplicate = false,
    required String passengerName,
    required String seatsStr,
    required String ticketId,
    String? route,
    String? errorMessage,
  }) {
    Color statusColor = const Color(0xFF34D399);
    IconData statusIcon = Icons.check_circle;
    String statusTitle = 'BILLET AUTHENTIQUE';
    String defaultMsg = 'Embarquement autorisé pour ce voyageur';

    if (isDuplicate) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.warning_amber_rounded;
      statusTitle = 'BILLET DÉJÀ COMPOSTÉ';
      defaultMsg = errorMessage ?? 'Ce billet a déjà été validé à l\'embarquement';
    } else if (!isValid) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
      statusTitle = 'BILLET NON CONFORME';
      defaultMsg = errorMessage ?? 'Signature invalide ou référence inconnue';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusTitle,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              defaultMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _sheetRow('Passager', passengerName),
                  if (route != null) ...[
                    const Divider(color: Colors.white12),
                    _sheetRow('Trajet', route),
                  ],
                  const Divider(color: Colors.white12),
                  _sheetRow('Siège(s)', seatsStr),
                  const Divider(color: Colors.white12),
                  _sheetRow('Réf. Billet', ticketId),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? const Color(0xFF059669) : (isDuplicate ? const Color(0xFFD97706) : Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'TERMINER',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
