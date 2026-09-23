import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../services/ticket_service.dart';
import '../search/trip.dart';
import 'my_tickets_screen.dart';

/// Écran Billet Numérique / Carte d'Embarquement Dioufy-TS
/// Refondu avec la charte Dioufy Pure & Lumineuse et support DesktopSplitScaffold.
class TicketScreen extends StatelessWidget {
  final Trip trip;
  final List<String> seats;
  final String ref;
  final List<String>? bookingIds;
  final String passengerName;
  final String? passengerPhone;

  const TicketScreen({
    super.key,
    required this.trip,
    required this.seats,
    required this.ref,
    this.bookingIds,
    required this.passengerName,
    this.passengerPhone,
  });

  int get _totalPrice => trip.price * seats.length;

  Map<String, dynamic> get _ticketPayload => {
        'trip': {
          'departure': trip.departure,
          'arrival': trip.arrival,
          'time': trip.time,
          'company': trip.company,
          'departureStation': trip.departureStation,
          'arrivalStation': trip.arrivalStation,
          'date': trip.date,
        },
        'seats': seats,
        'ref': ref,
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'bookingIds': bookingIds,
        'amount': _totalPrice,
      };

  @override
  Widget build(BuildContext context) {
    final encodedTicketString = TicketService.encodeTicket(_ticketPayload);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
      child: DesktopSplitScaffold(
        title: 'Billet Officiel Dioufy-TS',
        showBackButton: true,
        onBack: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
        appBarActions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined, color: DioufyColors.primary),
            tooltip: 'Mes Billets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
              );
            },
          ),
        ],
        rightPane: _buildTicketCompanionPane(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Badge de confirmation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: DioufyColors.accentGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Paiement validé • Billet Confirmé',
                      style: DioufyTypography.bodyMedium.copyWith(
                        color: DioufyColors.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Carte d'embarquement stylisée
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DioufyColors.borderSubtle),
                  boxShadow: DioufyShadows.cardElevated,
                ),
                child: Column(
                  children: [
                    // Partie haute du ticket
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête Agence et logo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.company,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: DioufyColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: DioufyColors.primarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      trip.type,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: DioufyColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Image.asset('assets/logo.png', height: 42),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Trajet Départ -> Arrivée
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "DÉPART",
                                      style: TextStyle(
                                        color: DioufyColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      trip.departure,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: DioufyColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      trip.departureStation,
                                      style: const TextStyle(
                                        color: DioufyColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward, color: DioufyColors.primary, size: 20),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      "ARRIVÉE",
                                      style: TextStyle(
                                        color: DioufyColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      trip.arrival,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: DioufyColors.textPrimary,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                    Text(
                                      trip.arrivalStation,
                                      style: const TextStyle(
                                        color: DioufyColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Date, Heure et Sièges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _infoBox("DATE", trip.date)),
                              const SizedBox(width: 8),
                              Expanded(child: _infoBox("DÉPART", trip.time)),
                              const SizedBox(width: 8),
                              Expanded(child: _infoBox("SIÈGE(S)", seats.join(", "))),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Passager & Montant
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "VOYAGEUR",
                                    style: TextStyle(
                                      color: DioufyColors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    passengerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: DioufyColors.textPrimary,
                                    ),
                                  ),
                                  if (passengerPhone != null && passengerPhone!.isNotEmpty)
                                    Text(
                                      passengerPhone!,
                                      style: const TextStyle(
                                        color: DioufyColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "PRIX TOTAL",
                                    style: TextStyle(
                                      color: DioufyColors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        "$_totalPrice FCFA",
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
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Ligne pointillée de découpe avec encoches adaptées au fond perle #F8FAFC
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: List.generate(
                            30,
                            (index) => Expanded(
                              child: Container(
                                color: index % 2 == 0 ? Colors.transparent : const Color(0xFFCBD5E1),
                                height: 2,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Partie basse avec QR Code
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: DioufyColors.borderSubtle),
                              ),
                              child: QrImageView(
                                data: encodedTicketString,
                                size: 180.0,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: DioufyColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'RÉF : $ref',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.2,
                                color: DioufyColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Présentez ce QR Code au contrôleur lors de l\'embarquement',
                            textAlign: TextAlign.center,
                            style: DioufyTypography.bodySmall.copyWith(
                              color: DioufyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: "Billet Dioufy-TS: ${trip.departure} -> ${trip.arrival} ($ref)"));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: DioufyColors.accentGreen,
                              content: Text('Référence copiée ! Prêt à partager sur WhatsApp.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.share, color: Colors.white, size: 20),
                        label: Text(
                          'Partager le Billet',
                          style: DioufyTypography.button.copyWith(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DioufyColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: DioufyRadius.button),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                            (route) => route.isFirst,
                          );
                        },
                        icon: const Icon(Icons.confirmation_number_outlined, color: DioufyColors.primary, size: 20),
                        label: Text(
                          'Mes Billets',
                          style: DioufyTypography.button.copyWith(color: DioufyColors.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: DioufyColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: DioufyRadius.button),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bouton de retour direct vers l'Accueil / Barre de Navigation
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                  icon: const Icon(Icons.home_outlined, color: DioufyColors.textPrimary, size: 22),
                  label: const Text(
                    'RETOUR À L\'ACCUEIL (GARE NUMÉRIQUE)',
                    style: TextStyle(
                      color: DioufyColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: DioufyColors.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: DioufyRadius.button),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: DioufyColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: DioufyColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Volet droit informatif pour le grand écran Desktop
  Widget _buildTicketCompanionPane(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: DioufyColors.accentGreen, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Réservation Validée',
            style: DioufyTypography.h2.copyWith(fontSize: 22, color: DioufyColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre place à bord du car ${trip.company} est réservée et garantie. Ce billet électronique est officiel et reconnu par toutes les gares routières du réseau Dioufy-TS.',
            style: DioufyTypography.bodyLarge.copyWith(color: DioufyColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Divider(color: DioufyColors.borderSubtle),
          const SizedBox(height: 20),
          Text(
            'Consignes d\'embarquement',
            style: DioufyTypography.h3.copyWith(fontSize: 17, color: DioufyColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildCompanionStep(
            step: '1',
            title: 'Arrivée à la gare',
            desc: 'Présentez-vous à la ${trip.departureStation} au moins 15 minutes avant le départ (${trip.time}).',
          ),
          const SizedBox(height: 16),
          _buildCompanionStep(
            step: '2',
            title: 'Présentation du QR code',
            desc: 'Montrez ce billet au contrôleur de quai. Il scannera le code même si votre téléphone est hors-ligne.',
          ),
          const SizedBox(height: 16),
          _buildCompanionStep(
            step: '3',
            title: 'Installation à bord',
            desc: 'Prenez place sur le(s) siège(s) ${seats.join(", ")}. Bon voyage avec Dioufy-TS !',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DioufyColors.primarySoft,
              borderRadius: DioufyRadius.card,
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: DioufyColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Retrouvez ce billet à tout moment dans l\'onglet "Mes Billets", sans connexion Internet requise.',
                    style: DioufyTypography.bodyMedium.copyWith(
                      color: DioufyColors.primary,
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

  Widget _buildCompanionStep({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: DioufyColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
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
