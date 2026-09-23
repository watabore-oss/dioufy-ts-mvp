import 'package:flutter/material.dart';
import '../theme/dioufy_tokens.dart';
import '../constants.dart';
import '../../features/search/trip.dart';

/// ============================================================
/// TRANSACTION SUMMARY PANE : Volet Droit Desktop pour le Tunnel d'Achat
/// ------------------------------------------------------------
/// Accompagne l'utilisateur sur grand écran durant :
/// - La sélection de siège (SeatSelectionScreen)
/// - La saisie des informations passagers (PassengerFormScreen)
/// - Le règlement sécurisé (PaymentScreen)
/// ============================================================
class TransactionSummaryPane extends StatelessWidget {
  final Trip trip;
  final List<String> selectedSeats;
  final int totalAmount;
  final String? passengerName;
  final String? passengerPhone;

  const TransactionSummaryPane({
    super.key,
    required this.trip,
    required this.selectedSeats,
    required this.totalAmount,
    this.passengerName,
    this.passengerPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DioufyColors.darkBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. En-tête du volet compagnon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DioufyColors.primary.withValues(alpha: 0.2),
                    borderRadius: DioufyRadius.mdAll,
                    border: Border.all(color: DioufyColors.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF38BDF8),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RÉCAPITULATIF DE VOYAGE',
                      style: TextStyle(
                        fontFamily: DioufyTypography.fontFamily,
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Votre réservation en direct',
                      style: TextStyle(
                        fontFamily: DioufyTypography.fontFamily,
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 2. Carte Trajet & Compagnie
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: DioufyColors.darkSurface,
                borderRadius: DioufyRadius.lgAll,
                border: Border.all(color: DioufyColors.darkBorder),
                boxShadow: DioufyShadows.cardElevated,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compagnie et badge type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_bus_rounded, color: Color(0xFF38BDF8), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            trip.company,
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: DioufyColors.emerald.withValues(alpha: 0.2),
                          borderRadius: DioufyRadius.smAll,
                          border: Border.all(color: DioufyColors.emeraldLight.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          trip.type,
                          style: const TextStyle(
                            fontFamily: DioufyTypography.fontFamily,
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),

                  // Itinéraire Gare départ -> Gare arrivée
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.radio_button_checked, color: Color(0xFF38BDF8), size: 16),
                          Container(width: 2, height: 40, color: Colors.white24),
                          const Icon(Icons.location_on, color: DioufyColors.gold, size: 18),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Départ
                            Text(
                              trip.departure,
                              style: const TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${trip.departureStation} • ${trip.time}',
                              style: const TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Arrivée
                            Text(
                              trip.arrival,
                              style: const TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              trip.arrivalStation,
                              style: const TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Carte Sièges & Passager
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: DioufyColors.darkSurface,
                borderRadius: DioufyRadius.lgAll,
                border: Border.all(color: DioufyColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sièges réservés',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${selectedSeats.length} place${selectedSeats.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: DioufyColors.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (selectedSeats.isEmpty)
                    const Text(
                      'Aucun siège sélectionné pour le moment.',
                      style: TextStyle(
                        fontFamily: DioufyTypography.fontFamily,
                        color: Colors.white38,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedSeats.map((seat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: DioufyColors.primary.withValues(alpha: 0.3),
                            borderRadius: DioufyRadius.smAll,
                            border: Border.all(color: const Color(0xFF38BDF8)),
                          ),
                          child: Text(
                            'Siège $seat',
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  if (passengerName != null && passengerName!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, color: Colors.white60, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            passengerName!,
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (passengerPhone != null)
                          Text(
                            passengerPhone!,
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Carte Total Financier (FCFA avec XOF)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: DioufyRadius.lgAll,
                border: Border.all(color: const Color(0xFF059669)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL À RÉGLER',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Taxes & assurance incluses',
                        style: TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '$totalAmount FCFA',
                        style: const TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const XofCurrencyBadge(size: 24),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 5. Piliers de Réassurance Dioufy-TS
            _buildTrustPillar(
              icon: Icons.qr_code_2_rounded,
              title: 'Billet officiel sécurisé',
              subtitle: 'Génération instantanée d\'un QR Code HMAC infalsifiable.',
            ),
            const SizedBox(height: 14),
            _buildTrustPillar(
              icon: Icons.support_agent_rounded,
              title: 'Assistance voyageur 7j/7',
              subtitle: 'Ligne directe WhatsApp au +221 77 469 13 79.',
            ),
            const SizedBox(height: 14),
            _buildTrustPillar(
              icon: Icons.shield_outlined,
              title: 'Paiement local certifié',
              subtitle: 'Wave, Orange Money, Free Money, Carte bancaire.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustPillar({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: DioufyTypography.fontFamily,
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: DioufyTypography.fontFamily,
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
