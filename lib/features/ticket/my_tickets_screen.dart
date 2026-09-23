import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../services/ticket_service.dart';
import '../search/trip.dart';
import 'ticket_screen.dart';

/// Écran affichant l'historique des billets enregistrés localement sur l'appareil (Offline-First)
/// Refondu avec la charte Dioufy Pure & Lumineuse et support DesktopSplitScaffold.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final tickets = await TicketService.getLocalTickets();
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopSplitScaffold(
      title: 'Mes Billets Dioufy-TS',
      showBackButton: true,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: DioufyColors.primary),
          tooltip: 'Actualiser',
          onPressed: _loadTickets,
        ),
      ],
      rightPane: _buildAssistancePane(context),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DioufyColors.primary),
            )
          : _tickets.isEmpty
              ? _buildEmptyState(context)
              : _buildTicketList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: DioufyColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: 64,
                color: DioufyColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun billet trouvé',
              style: DioufyTypography.h2.copyWith(color: DioufyColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Vos billets de transport réservés apparaîtront ici et seront consultables même sans connexion Internet.',
                textAlign: TextAlign.center,
                style: DioufyTypography.bodyLarge.copyWith(color: DioufyColors.textSecondary),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.search, color: Colors.white, size: 20),
                label: Text(
                  'Réserver un trajet',
                  style: DioufyTypography.button.copyWith(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DioufyColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: DioufyRadius.button),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketList(BuildContext context) {
    return ListView.builder(
      padding: DioufySpacing.pagePadding(context),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final item = _tickets[index];
        final tripMap = item['trip'] is Map ? item['trip'] as Map<String, dynamic> : <String, dynamic>{};
        final seats = item['seats'] is List
            ? (item['seats'] as List).map((e) => e.toString()).toList()
            : <String>[];
        final ref = item['ref']?.toString() ?? 'N/A';
        final passengerName = item['passenger_name']?.toString() ?? 'Passager Dioufy';
        final isUsed = item['status'] == 'used';
        final price = (item['amount'] as num?)?.toInt() ?? ((tripMap['price'] as num?)?.toInt() ?? 0) * seats.length;

        final trip = Trip(
          id: tripMap['id']?.toString() ?? '',
          company: tripMap['company']?.toString() ?? 'Dioufy Trans',
          departure: tripMap['departure']?.toString() ?? 'Dakar',
          arrival: tripMap['arrival']?.toString() ?? 'Thiès',
          time: tripMap['time']?.toString() ?? '08:00',
          price: (tripMap['price'] as num?)?.toInt() ?? (seats.isNotEmpty ? price ~/ seats.length : price),
          type: tripMap['type']?.toString() ?? 'CONFORT',
          seatsLeft: 0,
          departureStation: tripMap['departureStation']?.toString() ?? "Gare des Baux Maraîchers",
          arrivalStation: tripMap['arrivalStation']?.toString() ?? "Gare Routière",
          date: tripMap['date']?.toString() ?? "Aujourd'hui",
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: DioufyRadius.card,
            border: Border.all(
              color: isUsed ? DioufyColors.borderSubtle : const Color(0xFFBFDBFE),
              width: 1.2,
            ),
            boxShadow: DioufyShadows.card,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketScreen(
                      trip: trip,
                      seats: seats,
                      ref: ref,
                      passengerName: passengerName,
                      passengerPhone: item['passenger_phone']?.toString(),
                    ),
                  ),
                ).then((_) => _loadTickets());
              },
              borderRadius: DioufyRadius.card,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statut et Référence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isUsed ? const Color(0xFFF1F5F9) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUsed ? Icons.check_circle_outline : Icons.verified,
                                size: 14,
                                color: isUsed ? DioufyColors.textSecondary : DioufyColors.accentGreen,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isUsed ? 'BILLET UTILISÉ' : 'CONFIRMÉ & PAYÉ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isUsed ? DioufyColors.textSecondary : DioufyColors.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          ref,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: DioufyColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Ligne Trajet & Prix
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${trip.departure} → ${trip.arrival}",
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: DioufyColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${trip.company} • ${trip.time} • ${trip.date}",
                                style: DioufyTypography.bodyMedium.copyWith(
                                  color: DioufyColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$price FCFA",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: DioufyColors.accentGreen,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const XofCurrencyBadge(size: 18),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: Color(0xFFF1F5F9)),

                    // Détails Sièges et Voyageur
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.event_seat, size: 18, color: DioufyColors.primary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Sièges : ${seats.join(', ')}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: DioufyColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18, color: DioufyColors.textSecondary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  passengerName,
                                  style: DioufyTypography.bodyMedium.copyWith(
                                    color: DioufyColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: DioufyColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Volet droit informatif pour le grand écran Desktop
  Widget _buildAssistancePane(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DioufyColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.offline_pin, color: DioufyColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Billets Disponibles Hors-Ligne',
            style: DioufyTypography.h2.copyWith(fontSize: 22, color: DioufyColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Tous vos billets achetés sont synchronisés localement sur votre appareil. Vous pouvez présenter le QR code aux contrôleurs sans aucune connexion 4G.',
            style: DioufyTypography.bodyLarge.copyWith(color: DioufyColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Divider(color: DioufyColors.borderSubtle),
          const SizedBox(height: 24),
          _buildInfoRow(
            icon: Icons.access_time_filled,
            color: DioufyColors.primary,
            title: 'Ponctualité garantie',
            desc: 'Présentez-vous 15 minutes avant le départ à la gare indiquée pour faciliter l\'embarquement.',
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.luggage,
            color: const Color(0xFFD97706),
            title: 'Bagages inclus',
            desc: 'Un bagage principal en soute et un bagage à main sont inclus dans chaque réservation.',
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.support_agent,
            color: DioufyColors.accentGreen,
            title: 'Support voyageur 24/7',
            desc: 'Une question ou une modification de trajet ? Contactez l\'assistance Dioufy au +221 33 800 00 00.',
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: DioufyRadius.card,
              border: Border.all(color: DioufyColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: DioufyColors.accentGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Validation instantanée par scan QR sécurisé aux gares partenaires.',
                    style: DioufyTypography.bodyMedium.copyWith(
                      color: DioufyColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: DioufyColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: DioufyTypography.bodyMedium.copyWith(
                  color: DioufyColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
