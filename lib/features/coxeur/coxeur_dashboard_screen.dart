import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/audit_service.dart';
import '../../services/scanner/scanner_service.dart';
import '../chauffeur/qr_camera_scanner_screen.dart';

/// Workflow d'état d'un départ de bus en gare
enum BusDepartureStatus {
  preparation('En Préparation', Color(0xFF64748B)),
  aQuai('Bus à Quai', Color(0xFF0284C7)),
  embarquement('Embarquement en cours', Color(0xFFD97706)),
  complet('Bus Complet', Color(0xFF059669)),
  parti('Départ effectué', Color(0xFF475569));

  final String label;
  final Color color;
  const BusDepartureStatus(this.label, this.color);
}

/// Modèle local d'un départ de bus géré par le régulateur
class QuaiDeparture {
  final String id;
  final String busMatricule;
  final String destination;
  final String heure;
  final int totalSeats;
  int boardedSeats;
  BusDepartureStatus status;

  QuaiDeparture({
    required this.id,
    required this.busMatricule,
    required this.destination,
    required this.heure,
    required this.totalSeats,
    required this.boardedSeats,
    required this.status,
  });
}

/// Tableau de bord dédié Régulateur de Quai & Coxeur Dioufy-TS
class CoxeurDashboardScreen extends StatefulWidget {
  const CoxeurDashboardScreen({super.key});

  @override
  State<CoxeurDashboardScreen> createState() => _CoxeurDashboardScreenState();
}

class _CoxeurDashboardScreenState extends State<CoxeurDashboardScreen> {
  final String _selectedGare = 'Gare des Baux Maraîchers (Dakar)';
  RealtimeChannel? _realtimeChannel;
  bool _isLoading = false;

  List<QuaiDeparture> _departures = [
    QuaiDeparture(
      id: 'DEP-01',
      busMatricule: 'DK-882-SN',
      destination: 'Touba',
      heure: '08:00',
      totalSeats: 45,
      boardedSeats: 32,
      status: BusDepartureStatus.embarquement,
    ),
    QuaiDeparture(
      id: 'DEP-02',
      busMatricule: 'TH-310-SN',
      destination: 'Thiès',
      heure: '08:30',
      totalSeats: 36,
      boardedSeats: 15,
      status: BusDepartureStatus.aQuai,
    ),
    QuaiDeparture(
      id: 'DEP-03',
      busMatricule: 'SL-492-SN',
      destination: 'Saint-Louis',
      heure: '09:00',
      totalSeats: 50,
      boardedSeats: 0,
      status: BusDepartureStatus.preparation,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDeparturesFromSupabase();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToRealtime() {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client
          .channel('public:trips:quai')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trips',
            callback: (payload) {
              _fetchDeparturesFromSupabase();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime quai en attente (mode hors-ligne): $e');
    }
  }

  Future<void> _fetchDeparturesFromSupabase() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('trips')
          .select('id, from_loc, to_loc, depart_at, seats_total, status, bus_id')
          .order('depart_at', ascending: true)
          .limit(10)
          .timeout(const Duration(seconds: 3));

      final list = response as List;
      if (list.isNotEmpty) {
        final List<QuaiDeparture> remote = [];
        for (var row in list) {
          final id = row['id']?.toString() ?? '';
          final dest = row['to_loc']?.toString() ?? 'Gare';
          final matricule = row['bus_id']?.toString() ??
              'DK-${id.length >= 3 ? id.substring(0, 3).toUpperCase() : "001"}-SN';
          final departAt = DateTime.tryParse(row['depart_at']?.toString() ?? '') ?? DateTime.now();
          final heure =
              '${departAt.hour.toString().padLeft(2, '0')}:${departAt.minute.toString().padLeft(2, '0')}';
          final total = (row['seats_total'] as num?)?.toInt() ?? 45;
          final st = _mapStatusFromDb(row['status']?.toString());

          remote.add(QuaiDeparture(
            id: id,
            busMatricule: matricule,
            destination: dest,
            heure: heure,
            totalSeats: total,
            boardedSeats: 0,
            status: st,
          ));
        }

        if (remote.isNotEmpty && mounted) {
          setState(() {
            _departures = remote;
          });
        }
      }
    } catch (e) {
      debugPrint('Chargement départs quai (repli local): $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static BusDepartureStatus _mapStatusFromDb(String? dbStatus) {
    switch (dbStatus?.toLowerCase()) {
      case 'boarding':
        return BusDepartureStatus.embarquement;
      case 'ready':
      case 'at_dock':
        return BusDepartureStatus.aQuai;
      case 'full':
        return BusDepartureStatus.complet;
      case 'departed':
      case 'completed':
        return BusDepartureStatus.parti;
      default:
        return BusDepartureStatus.preparation;
    }
  }

  static String _statusToDbString(BusDepartureStatus status) {
    switch (status) {
      case BusDepartureStatus.preparation:
        return 'scheduled';
      case BusDepartureStatus.aQuai:
        return 'at_dock';
      case BusDepartureStatus.embarquement:
        return 'boarding';
      case BusDepartureStatus.complet:
        return 'full';
      case BusDepartureStatus.parti:
        return 'departed';
    }
  }

  static bool _isValidUuid(String val) {
    final uuidRegex =
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(val);
  }

  void _advanceStatus(QuaiDeparture dep) {
    setState(() {
      switch (dep.status) {
        case BusDepartureStatus.preparation:
          dep.status = BusDepartureStatus.aQuai;
          break;
        case BusDepartureStatus.aQuai:
          dep.status = BusDepartureStatus.embarquement;
          break;
        case BusDepartureStatus.embarquement:
          dep.status = BusDepartureStatus.complet;
          break;
        case BusDepartureStatus.complet:
          dep.status = BusDepartureStatus.parti;
          break;
        case BusDepartureStatus.parti:
          break;
      }
    });

    if (_isValidUuid(dep.id)) {
      try {
        Supabase.instance.client
            .from('trips')
            .update({'status': _statusToDbString(dep.status)})
            .eq('id', dep.id)
            .then((_) => debugPrint('Statut trip quai synchronisé : ${dep.id}'))
            .catchError((e) => debugPrint('Erreur synchro statut quai: $e'));
      } catch (_) {}
    }

    AuditService.instance.logAction(
      action: 'departure.status_update',
      targetType: 'trip_departure',
      targetId: dep.id,
      details: {
        'bus': dep.busMatricule,
        'destination': dep.destination,
        'new_status': dep.status.name,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dep.busMatricule} (${dep.destination}) ➔ ${dep.status.label}'),
        backgroundColor: dep.status.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openScanner() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrCameraScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      final result = await ScannerService.instance.validateDirectCode(scannedCode);
      if (!mounted) return;
      final passenger = result.passengerName ?? 'Voyageur Dioufy';
      final seats = result.seatNumber ?? 'Libre';
      final route = result.route ?? 'Ligne Directe';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: result.isValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(
                result.isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.isValid
                      ? 'Billet Validé : $passenger (Siège: $seats) • $route'
                      : (result.message ?? 'Billet non conforme'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Régulation de Quai',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.5, color: Color(0xFF0F172A)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
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
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
                    )
                  : const Icon(Icons.refresh, color: Color(0xFF0F172A)),
              tooltip: 'Actualiser les départs',
              onPressed: _fetchDeparturesFromSupabase,
            ),
            Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.traffic, color: Color(0xFFB45309), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'COXEUR',
                    style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cartouche Gare
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city, color: Color(0xFF1D4ED8), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gare Routière Assignée', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            _selectedGare,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // BOUTON MAJEUR SCANNER ACCÈS QUAI
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(
                    'SCANNER DE VALIDATION QUAI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // LISTE DES DÉPARTS DU JOUR
              const Text(
                'Départs du Jour & Workflow des Bus',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),

              ..._departures.map((dep) => _buildDepartureCard(dep)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartureCard(QuaiDeparture dep) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Color(0xFF1D4ED8), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    dep.busMatricule,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dep.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dep.status.color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  dep.status.label,
                  style: TextStyle(color: dep.status.color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ligne : ${dep.destination} (${dep.heure})',
                style: const TextStyle(color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '${dep.boardedSeats}/${dep.totalSeats} passagers',
                style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: dep.totalSeats > 0 ? (dep.boardedSeats / dep.totalSeats) : 0,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(dep.status.color),
            borderRadius: BorderRadius.circular(8),
            minHeight: 7,
          ),

          const SizedBox(height: 14),

          // Action Workflow
          if (dep.status != BusDepartureStatus.parti)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _advanceStatus(dep),
                icon: const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF1D4ED8)),
                label: Text(
                  _getNextActionLabel(dep.status),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1D4ED8)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getNextActionLabel(BusDepartureStatus status) {
    switch (status) {
      case BusDepartureStatus.preparation:
        return 'PASSER LE BUS À QUAI';
      case BusDepartureStatus.aQuai:
        return 'OUVRIR L EMBARQUEMENT';
      case BusDepartureStatus.embarquement:
        return 'DÉCLARER BUS COMPLET';
      case BusDepartureStatus.complet:
        return 'VALIDER LE DÉPART DU BUS';
      case BusDepartureStatus.parti:
        return 'VOYAGE EN COURS';
    }
  }
}
