import 'package:flutter/material.dart';
import '../seat_selection/seat_selection_screen.dart';
import 'trip.dart';

class SearchResultsScreen extends StatelessWidget {
  final String destination;
  SearchResultsScreen({super.key, required this.destination});

  // Liste complète des trajets (Dakar-Thiès + Dakar-Touba)
  final List<Trip> allTrips = [
    // Dakar → Thiès
    Trip(
        id: 't1',
        time: "08:30",
        type: "CONFORT",
        company: "Dioufy Trans",
        seatsLeft: 12,
        price: 7500,
        departure: "Dakar",
        arrival: "Thiès"),
    Trip(
        id: 't2',
        time: "10:15",
        type: "STANDARD",
        company: "Galsen Tour",
        seatsLeft: 4,
        price: 4500,
        departure: "Dakar",
        arrival: "Thiès"),
    Trip(
        id: 't3',
        time: "14:00",
        type: "CONFORT",
        company: "Dioufy Trans",
        seatsLeft: 20,
        price: 8200,
        departure: "Dakar",
        arrival: "Thiès"),
    // Dakar → Touba (nouveau !)
    Trip(
        id: 't4',
        time: "07:00",
        type: "CONFORT",
        company: "Dioufy Trans",
        seatsLeft: 18,
        price: 12500,
        departure: "Dakar",
        arrival: "Touba"),
    Trip(
        id: 't5',
        time: "09:45",
        type: "STANDARD",
        company: "Touba Express",
        seatsLeft: 8,
        price: 9500,
        departure: "Dakar",
        arrival: "Touba"),
    Trip(
        id: 't6',
        time: "13:30",
        type: "CONFORT",
        company: "Dioufy Trans",
        seatsLeft: 15,
        price: 13200,
        departure: "Dakar",
        arrival: "Touba"),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTrips =
        allTrips.where((t) => t.arrival == destination).toList();

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text("Départs vers $destination"),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredTrips.length,
        itemBuilder: (context, index) {
          final trip = filteredTrips[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              title: Text("${trip.time} • ${trip.type}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              subtitle:
                  Text("${trip.company} • ${trip.seatsLeft} places restantes"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${trip.price} XOF",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669))),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SeatSelectionScreen(trip: trip))),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    child: const Text("Choisir",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
