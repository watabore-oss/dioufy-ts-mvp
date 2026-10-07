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

/// Modèle d'un départ de bus réel géré par le régulateur
class QuaiDeparture {
  final String id;
  final String busMatricule;
  final String destination;
  final String heure;
  final int totalSeats;
  int boardedSeats;
  BusDepartureStatus status;
  final int price;

  QuaiDeparture({
    required this.id,
    required this.busMatricule,
    required this.destination,
    required this.heure,
    required this.totalSeats,
    required this.boardedSeats,
    required this.status,
    this.price = 5000,
  });
}

/// Tableau de bord dédié Régulateur de Quai & Coxeur Dioufy-TS
/// 100% Connecté à Supabase — Zéro données factices / mock.
class CoxeurDashboardScreen extends StatefulWidget {
  const CoxeurDashboardScreen({super.key});

  @override
  State<CoxeurDashboardScreen> createState() => _CoxeurDashboardScreenState();
}

class _CoxeurDashboardScreenState extends State<CoxeurDashboardScreen> {
  final List<String> _availableGares = [
    'Gare des Baux Maraîchers (Dakar)',
    'Gare Routière de Thiès',
    'Gare Routière de Touba',
    'Gare Routière de Saint-Louis',
    'Gare Routière de Mbour',
    'Gare Routière de Kaolack',
    'Gare Routière de Ziguinchor',
  ];

  late String _selectedGare;
  RealtimeChannel? _realtimeChannel;
  bool _isLoading = false;
  List<QuaiDeparture> _departures = [];

  @override
  void initState() {
    super.initState();
    _selectedGare = _availableGares.first;
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
      debugPrint('Realtime quai en attente : $e');
    }
  }

  /// Chargement des départs réels depuis la table `trips` de Supabase
  Future<void> _fetchDeparturesFromSupabase() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final cityName = _selectedGare.contains('Dakar')
          ? 'Dakar'
          : _selectedGare.split(' ').last.replaceAll('(', '').replaceAll(')', '');

      final response = await client
          .from('trips')
          .select('id, from_loc, to_loc, depart_at, seats_count, status, price, seats(id, status)')
          .ilike('from_loc', '%$cityName%')
          .order('depart_at', ascending: true)
          .limit(15)
          .timeout(const Duration(seconds: 4));

      final list = response as List;
      final List<QuaiDeparture> remote = [];

      for (var row in list) {
        final id = row['id']?.toString() ?? '';
        final dest = row['to_loc']?.toString() ?? 'Gare';
        final shortId = id.length >= 4 ? id.substring(0, 4).toUpperCase() : '001';
        final matricule = 'DK-$shortId-SN';
        final departAt = DateTime.tryParse(row['depart_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
        final heure =
            '${departAt.hour.toString().padLeft(2, '0')}:${departAt.minute.toString().padLeft(2, '0')}';
        final total = (row['seats_count'] as num?)?.toInt() ?? 36;
        final st = _mapStatusFromDb(row['status']?.toString());
        final price = (row['price'] as num?)?.toInt() ?? 5000;

        // Calcul des passagers confirmés à partir des sièges vendus
        int soldCount = 0;
        if (row['seats'] is List) {
          final sList = row['seats'] as List;
          soldCount = sList.where((s) => s['status'] == 'sold' || s['status'] == 'occupied').length;
        }

        remote.add(QuaiDeparture(
          id: id,
          busMatricule: matricule,
          destination: dest,
          heure: heure,
          totalSeats: total,
          boardedSeats: soldCount,
          status: st,
          price: price,
        ));
      }

      if (mounted) {
        setState(() {
          _departures = remote;
        });
      }
    } catch (e) {
      debugPrint('Chargement départs quai Supabase : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static BusDepartureStatus _mapStatusFromDb(String? dbStatus) {
    switch (dbStatus?.toLowerCase()) {
      case 'boarding':
        return BusDepartureStatus.embarquement;
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

    try {
      Supabase.instance.client
          .from('trips')
          .update({'status': _statusToDbString(dep.status)})
          .eq('id', dep.id)
          .then((_) => debugPrint('Statut trip quai synchronisé : ${dep.id}'))
          .catchError((e) => debugPrint('Erreur synchro statut quai: $e'));
    } catch (_) {}

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

  /// Ouverture du scanner caméra pour validation optique de billets passagers
  Future<void> _openScanner({QuaiDeparture? dep}) async {
    ScannerService.instance.startNewSession(tripId: dep?.id);
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrCameraScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      final result = await ScannerService.instance.validateDirectCode(scannedCode, tripId: dep?.id);
      if (!mounted) return;
      final passenger = result.passengerName ?? 'Voyageur Dioufy';
      final seats = result.seatNumber ?? 'Libre';
      final route = result.route ?? (dep != null ? dep.destination : 'Ligne Directe');

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
      _fetchDeparturesFromSupabase();
    }
  }

  /// Vente immédiate d'un billet en espèces au quai par le Coxeur
  void _showSellCashTicketDialog(QuaiDeparture dep) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+221 77 ');
    final seatCtrl = TextEditingController(text: 'A${dep.boardedSeats + 1}');
    final formKey = GlobalKey<FormState>();
    bool isSelling = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('XOF', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              const SizedBox(width: 10),
              const Text('Vente Billet Quai (Espèces)', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ligne : ${dep.destination}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${dep.price} FCFA', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du Passager',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom du voyageur requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (v) => (v == null || v.trim().length < 9) ? 'Numéro requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: seatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de Siège (ex: A1, B3)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.airline_seat_recline_normal),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Siège requis' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSelling ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSelling
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSelling = true);
                      try {
                        final client = Supabase.instance.client;
                        final res = await client.rpc('sell_ticket_cash', params: {
                          'p_trip_id': dep.id,
                          'p_seat_number': seatCtrl.text.trim().toUpperCase(),
                          'p_passenger_name': nameCtrl.text.trim(),
                          'p_passenger_phone': phoneCtrl.text.trim(),
                          'p_amount': dep.price,
                        });

                        if (res is Map && res['success'] == false) {
                          throw Exception(res['message'] ?? 'Erreur lors de la vente du billet');
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _fetchDeparturesFromSupabase();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res?['message']?.toString() ?? 'Billet vendu et encaissé avec succès !'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSelling = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Échec de la vente : $e'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      }
                    },
              child: isSelling
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ENCAISSER & ÉMETTRE'),
            ),
          ],
        ),
      ),
    );
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
              // Sélecteur de Gare Dynamique
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          const Text('Gare Routière Assignée', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGare,
                              isExpanded: true,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              items: _availableGares.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (newGare) {
                                if (newGare != null) {
                                  setState(() => _selectedGare = newGare);
                                  _fetchDeparturesFromSupabase();
                                }
                              },
                            ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Départs du Jour & Workflow des Bus',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  if (_departures.isNotEmpty)
                    Text(
                      '${_departures.length} départ(s)',
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_departures.isEmpty && !_isLoading)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.departure_board, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucun départ programmé sur ce quai',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Les trajets attribués à cette gare apparaîtront ici dès leur programmation par le GIE.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _fetchDeparturesFromSupabase,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Actualiser'),
                        ),
                      ],
                    ),
                  ),
                )
              else
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

          // Actions : Vente Billet Guichet + Workflow départ + Scan embarquement
          Row(
            children: [
              if (dep.status != BusDepartureStatus.parti)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSellCashTicketDialog(dep),
                    icon: const Icon(Icons.point_of_sale, size: 16, color: Color(0xFF059669)),
                    label: const Text('VENTE BILLET', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (dep.status != BusDepartureStatus.parti) const SizedBox(width: 8),
              if (dep.status == BusDepartureStatus.embarquement || dep.status == BusDepartureStatus.aQuai) ...[
                IconButton.filled(
                  onPressed: () => _openScanner(dep: dep),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  tooltip: 'Scanner les billets pour ce départ',
                ),
                const SizedBox(width: 8),
              ],
              if (dep.status != BusDepartureStatus.parti)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _advanceStatus(dep),
                    icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                    label: Text(
                      _getNextActionLabel(dep.status),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getNextActionLabel(BusDepartureStatus status) {
    switch (status) {
      case BusDepartureStatus.preparation:
        return 'BUS À QUAI';
      case BusDepartureStatus.aQuai:
        return 'EMBARQUER';
      case BusDepartureStatus.embarquement:
        return 'BUS COMPLET';
      case BusDepartureStatus.complet:
        return 'VALIDER DÉPART';
      case BusDepartureStatus.parti:
        return 'EN ROUTE';
    }
  }
}
