import 'package:flutter/material.dart';

import '../../data/sample_trips.dart';
import '../booking/booking_screen.dart';
import 'widgets/trip_card.dart';

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({
    super.key,
    required this.departure,
    required this.arrival,
  });

  final String departure;
  final String arrival;

  @override
  Widget build(BuildContext context) {
    final trips = searchTrips(departure, arrival);

    return Scaffold(
      appBar: AppBar(title: Text('$departure → $arrival')),
      body: trips.isEmpty
          ? _EmptyResults(departure: departure, arrival: arrival)
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: trips.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      '${trips.length} trajet${trips.length > 1 ? 's' : ''} disponible${trips.length > 1 ? 's' : ''} aujourd’hui',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  );
                }

                final trip = trips[index - 1];
                return TripCard(
                  trip: trip,
                  onReserve: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(trip: trip),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.departure, required this.arrival});

  final String departure;
  final String arrival;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucun trajet trouvé',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essaie une autre gare de départ ou destination. '
              'Recherche: $departure → $arrival',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
