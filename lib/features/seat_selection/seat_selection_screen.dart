import 'package:flutter/material.dart';

import '../payment/payment_screen.dart';
import '../search/trip.dart';
import '../../services/booking_service.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Trip trip;
  const SeatSelectionScreen({super.key, required this.trip});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final List<String> selectedSeats = [];
  List<String> occupiedSeats = const ['A3', 'B2', 'C5', 'D1'];
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
          // Retirer de la selection si un siege devenu occupe y etait
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
        selectedSeats.add(seat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text("Quai Virtuel • ${widget.trip.time}"),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualiser les places",
            onPressed: _loadOccupiedSeats,
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tete récapitulatif
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                Text(
                  widget.trip.company,
                  style: const TextStyle(
                    fontSize: 26,
                    color: Color(0xFFFBBF24),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.trip.departure} → ${widget.trip.arrival}",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // Legende visuelle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendItem(const Color(0xFF059669), "Libre"),
                    _legendItem(const Color(0xFF1E3A8A), "Sélectionné"),
                    _legendItem(Colors.grey[400]!, "Occupé"),
                  ],
                ),
              ],
            ),
          ),

          if (_isLoadingSeats)
            const LinearProgressIndicator(
              color: Color(0xFF1E3A8A),
              backgroundColor: Color(0xFFE2E8F0),
              minHeight: 3,
            ),

          // Grille des sieges
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: widget.trip.seatsCount,
                      itemBuilder: (context, index) {
                        final seatNumber =
                            "${String.fromCharCode(65 + (index ~/ 6))}${index % 6 + 1}";
                        final isOccupied = occupiedSeats.contains(seatNumber);
                        final isSelected = selectedSeats.contains(seatNumber);

                        return GestureDetector(
                          onTap: () => toggleSeat(seatNumber),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isOccupied
                                  ? Colors.grey[300]
                                  : (isSelected
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFF059669)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFBBF24)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                seatNumber,
                                style: TextStyle(
                                  color: isOccupied
                                      ? Colors.grey[600]
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // Récapitulatif et bouton de validation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sièges choisis", style: TextStyle(fontSize: 16)),
                    Text(
                      selectedSeats.isEmpty ? "Aucun" : selectedSeats.join(", "),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total à payer", style: TextStyle(fontSize: 16)),
                    Text(
                      "${widget.trip.price * selectedSeats.length} XOF",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                if (_lockError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lockError!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: selectedSeats.isEmpty || _isLocking
                        ? null
                        : () async {
                            setState(() {
                              _isLocking = true;
                              _lockError = null;
                            });

                            try {
                              // Verrouillage transactionnel avec gestion atomique
                              final bookingIds = await _bookingService.lockSeatsBatch(
                                tripId: widget.trip.id,
                                seatNumbers: selectedSeats,
                              );

                              if (!mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(
                                    trip: widget.trip,
                                    seats: selectedSeats,
                                    bookingIds: bookingIds,
                                  ),
                                ),
                              );
                            } catch (e) {
                              setState(() {
                                _lockError = e.toString().replaceAll("Exception: ", "");
                              });
                              // Actualisation immédiate pour afficher le siège pris par l'autre
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
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLocking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "RÉSERVER & PAYER",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
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

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
