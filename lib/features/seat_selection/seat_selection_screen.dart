import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../core/widgets/transaction_summary_pane.dart';
import '../../services/booking_service.dart';
import '../passenger/passenger_form_screen.dart';
import '../search/trip.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Trip trip;
  final int requestedPassengers;

  const SeatSelectionScreen({
    super.key,
    required this.trip,
    this.requestedPassengers = 1,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final List<String> selectedSeats = [];
  List<String> occupiedSeats = const ['A3', 'B2', 'C5', 'D1', 'A7'];
  bool _isLoadingSeats = false;
  bool _isLocking = false;
  String? _lockError;

  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _loadOccupiedSeats();
  }

  Future<void> _loadOccupiedSeats() async {
    setState(() {
      _isLoadingSeats = true;
      _lockError = null;
    });

    try {
      final seats = await _bookingService.getOccupiedSeats(widget.trip.id);
      if (mounted) {
        setState(() {
          occupiedSeats = seats;
          selectedSeats.removeWhere((s) => occupiedSeats.contains(s));
          _isLoadingSeats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSeats = false;
        });
      }
    }
  }

  void toggleSeat(String seat) {
    if (occupiedSeats.contains(seat)) return;

    setState(() {
      if (selectedSeats.contains(seat)) {
        selectedSeats.remove(seat);
      } else {
        if (selectedSeats.length >= widget.requestedPassengers &&
            widget.requestedPassengers == 1) {
          selectedSeats.clear();
        }
        selectedSeats.add(seat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int rowsCount = (widget.trip.seatsCount / 4).ceil();
    final int totalPrice = widget.trip.price * selectedSeats.length;

    return DesktopSplitScaffold(
      title: "Choix des Sièges • ${widget.trip.company}",
      subtitle: "${widget.trip.departure} → ${widget.trip.arrival} (${widget.trip.time})",
      showBackButton: true,
      rightPane: TransactionSummaryPane(
        trip: widget.trip,
        selectedSeats: selectedSeats,
        totalAmount: totalPrice,
      ),
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: DioufyColors.primary, size: 22),
          tooltip: "Actualiser les places",
          onPressed: _loadOccupiedSeats,
        ),
      ],
      child: Column(
        children: [
          // Bandeau instructions & Légende (Lumineux et Épuré)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: DioufyColors.white,
              border: Border(bottom: BorderSide(color: DioufyColors.border)),
            ),
            child: Column(
              children: [
                // Info sélection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Sélectionnez ${widget.requestedPassengers} place${widget.requestedPassengers > 1 ? 's' : ''}",
                      style: const TextStyle(
                        fontFamily: DioufyTypography.fontFamily,
                        color: DioufyColors.primary,
                        fontWeight: DioufyTypography.bold,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DioufyColors.primarySoft,
                        borderRadius: DioufyRadius.smAll,
                        border: Border.all(color: DioufyColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        "${selectedSeats.length}/${widget.requestedPassengers} choisi(s)",
                        style: const TextStyle(
                          fontFamily: DioufyTypography.fontFamily,
                          color: DioufyColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Légende visuelle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendItem(DioufyColors.emerald, "Libre"),
                    _legendItem(DioufyColors.primary, "Sélectionné"),
                    _legendItem(const Color(0xFF94A3B8), "Occupé"),
                  ],
                ),
              ],
            ),
          ),

          if (_isLoadingSeats)
            const LinearProgressIndicator(
              color: DioufyColors.primary,
              backgroundColor: DioufyColors.surfaceSoft,
              minHeight: 3,
            ),

          // Schéma réaliste du Car / Bus
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: DioufyRadius.lgAll,
                    boxShadow: DioufyShadows.card,
                    border: Border.all(color: DioufyColors.border, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      // Cabine Chauffeur & Pare-brise
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: DioufyColors.surfaceSoft,
                          borderRadius: DioufyRadius.mdAll,
                          border: Border.all(color: DioufyColors.border),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.airline_seat_recline_normal_rounded, color: DioufyColors.textPrimary, size: 24),
                                SizedBox(width: 6),
                                Text(
                                  "Chauffeur",
                                  style: TextStyle(
                                    fontFamily: DioufyTypography.fontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: DioufyColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Avant du Car",
                              style: TextStyle(
                                fontFamily: DioufyTypography.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: DioufyColors.primary,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.meeting_room_rounded, color: DioufyColors.emerald, size: 20),
                                SizedBox(width: 4),
                                Text(
                                  "Porte",
                                  style: TextStyle(
                                    fontFamily: DioufyTypography.fontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: DioufyColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grille des sièges (Rangées 1 à N)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rowsCount,
                        itemBuilder: (context, rowIndex) {
                          final rowNum = rowIndex + 1;
                          final seatA = 'A$rowNum';
                          final seatB = 'B$rowNum';
                          final seatC = 'C$rowNum';
                          final seatD = 'D$rowNum';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: _buildSeatWidget(seatA)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildSeatWidget(seatB)),
                                // Allée centrale
                                SizedBox(
                                  width: 32,
                                  child: Center(
                                    child: Text(
                                      '$rowNum',
                                      style: const TextStyle(
                                        fontFamily: DioufyTypography.fontFamily,
                                        fontSize: 12,
                                        color: DioufyColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(child: _buildSeatWidget(seatC)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildSeatWidget(seatD)),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Fond du car / Arrière
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DioufyColors.surfaceSoft,
                          borderRadius: DioufyRadius.smAll,
                        ),
                        child: const Text(
                          "Arrière du Car",
                          style: TextStyle(
                            fontFamily: DioufyTypography.fontFamily,
                            fontSize: 12,
                            color: DioufyColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Barre inférieure d'action (Prix en FCFA + Continuer)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: DioufyColors.border)),
              boxShadow: DioufyShadows.bottomBar,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${selectedSeats.length} place${selectedSeats.length > 1 ? 's' : ''} sélectionnée${selectedSeats.length > 1 ? 's' : ''}",
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              fontSize: 13,
                              color: DioufyColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "$totalPrice FCFA",
                                style: const TextStyle(
                                  fontFamily: DioufyTypography.fontFamily,
                                  fontSize: 22,
                                  fontWeight: DioufyTypography.black,
                                  color: DioufyColors.emerald,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const XofCurrencyBadge(size: 18),
                            ],
                          ),
                        ],
                      ),
                      if (selectedSeats.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: DioufyColors.primarySoft,
                            borderRadius: DioufyRadius.smAll,
                            border: Border.all(color: DioufyColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            selectedSeats.join(", "),
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              color: DioufyColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (_lockError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DioufyColors.coralSoft,
                        borderRadius: DioufyRadius.smAll,
                      ),
                      child: Text(
                        _lockError!,
                        style: const TextStyle(color: DioufyColors.coral, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: selectedSeats.isEmpty || _isLocking
                          ? null
                          : () async {
                              setState(() {
                                _isLocking = true;
                                _lockError = null;
                              });

                              try {
                                final bookingIds = await _bookingService.lockSeatsBatch(
                                  tripId: widget.trip.id,
                                  seatNumbers: selectedSeats,
                                );

                                if (!context.mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PassengerFormScreen(
                                      trip: widget.trip,
                                      selectedSeats: selectedSeats,
                                      bookingIds: bookingIds,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setState(() {
                                  _lockError = e.toString().replaceAll("Exception: ", "");
                                });
                                _loadOccupiedSeats();
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLocking = false;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DioufyColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                      ),
                      child: _isLocking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "CONTINUER VERS LES INFOS",
                                  style: TextStyle(
                                    fontFamily: DioufyTypography.fontFamily,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatWidget(String seatNumber) {
    final isOccupied = occupiedSeats.contains(seatNumber);
    final isSelected = selectedSeats.contains(seatNumber);

    Color bgColor;
    Color textColor;
    Border? border;

    if (isOccupied) {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF94A3B8);
      border = Border.all(color: DioufyColors.border);
    } else if (isSelected) {
      bgColor = DioufyColors.primary;
      textColor = Colors.white;
      border = Border.all(color: DioufyColors.gold, width: 2.5);
    } else {
      bgColor = DioufyColors.emeraldSoft;
      textColor = DioufyColors.emerald;
      border = Border.all(color: DioufyColors.emeraldLight.withValues(alpha: 0.4), width: 1.5);
    }

    return GestureDetector(
      onTap: () => toggleSeat(seatNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOccupied
                      ? Icons.lock_outline_rounded
                      : (isSelected ? Icons.check_circle_rounded : Icons.chair_outlined),
                  size: 16,
                  color: textColor,
                ),
                const SizedBox(height: 2),
                Text(
                  seatNumber,
                  style: TextStyle(
                    fontFamily: DioufyTypography.fontFamily,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: DioufyTypography.fontFamily,
            color: DioufyColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
