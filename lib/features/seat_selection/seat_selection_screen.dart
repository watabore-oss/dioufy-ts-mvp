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
  final List<String> occupiedSeats = ["A3", "B2", "C5", "D1"];

  void toggleSeat(String seat) {
    setState(() {
      if (selectedSeats.contains(seat)) {
        selectedSeats.remove(seat);
      } else if (!occupiedSeats.contains(seat)) {
        selectedSeats.add(seat);
      }
    });
  }

  bool _isLocking = false;
  String? _lockError;

  final BookingService _bookingService = BookingService();

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
      ),
      body: Column(
        children: [
          // En-tête comme prototype
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                Text(widget.trip.company,
                    style: const TextStyle(
                        fontSize: 28,
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w900)),
                Text("${widget.trip.departure} → ${widget.trip.arrival}",
                    style: const TextStyle(fontSize: 18, color: Colors.white)),
              ],
            ),
          ),
          // Grille sièges
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12),
                itemCount: 36, // exemple 6 rangées x 6
                itemBuilder: (context, index) {
                  String seatNumber =
                      "${String.fromCharCode(65 + (index ~/ 6))}${index % 6 + 1}";
                  bool isOccupied = occupiedSeats.contains(seatNumber);
                  bool isSelected = selectedSeats.contains(seatNumber);

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
                            width: 3),
                      ),
                      child: Center(
                        child: Text(seatNumber,
                            style: TextStyle(
                                color: isSelected || isOccupied
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Récap + bouton comme prototype
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sièges choisis",
                        style: TextStyle(fontSize: 18)),
                    Text(selectedSeats.join(", "),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total", style: TextStyle(fontSize: 18)),
                    Text("${widget.trip.price * selectedSeats.length} XOF",
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: selectedSeats.isEmpty || _isLocking
                        ? null
                        : () async {
                            setState(() {
                              _isLocking = true;
                              _lockError = null;
                            });
                            List<String> bookingIds = [];
                            try {
                              // lock seats un par un
                              for (var seat in selectedSeats) {
                                final id = await _bookingService.lockSeat(
                                    tripId: widget.trip.id, seatNumber: seat);
                                bookingIds.add(id);
                              }
                              if (!mounted) return;
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PaymentScreen(
                                            trip: widget.trip,
                                            seats: selectedSeats,
                                            bookingIds: bookingIds,
                                          )));
                            } catch (e) {
                              // liberer ce qui est déjà verrouille
                              for (var id in bookingIds) {
                                await _bookingService.releaseSeat(
                                    bookingId: id);
                              }
                              setState(() {
                                _lockError = e.toString();
                              });
                            } finally {
                              setState(() {
                                _isLocking = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                    child: _isLocking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("RÉSERVER & PAYER",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                  ),
                ),
                if (_lockError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _lockError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
