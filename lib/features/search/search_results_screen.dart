import 'package:flutter/material.dart';
import '../../services/trip_service.dart';
import '../seat_selection/seat_selection_screen.dart';
import 'trip.dart';

class SearchResultsScreen extends StatefulWidget {
  final String departure;
  final String destination;

  const SearchResultsScreen({
    super.key,
    required this.departure,
    required this.destination,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TripService _tripService = TripService();
  List<Trip> _trips = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 1. Affichage instantané (0ms) depuis le cache ou le catalogue local
    _trips = _tripService.getInstantTrips(
      departure: widget.departure,
      destination: widget.destination,
    );
    // 2. Revalidation asynchrone non-bloquante avec Supabase
    _revalidateTrips();
  }

  Future<void> _revalidateTrips() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final remoteTrips = await _tripService.searchTrips(
        departure: widget.departure,
        destination: widget.destination,
      );
      if (mounted) {
        setState(() {
          _trips = remoteTrips;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
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
        title: Text(
          "${widget.departure} → ${widget.destination}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualiser",
            onPressed: _revalidateTrips,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRefreshing)
            const LinearProgressIndicator(
              color: Color(0xFF1E3A8A),
              backgroundColor: Color(0xFFE2E8F0),
              minHeight: 3,
            ),
          Expanded(
            child: _trips.isEmpty
                ? Center(
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
                            'Aucun départ direct prévu pour le moment sur la ligne :\n'
                            '${widget.departure} → ${widget.destination}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text("Modifier la recherche", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          title: Text(
                            "${trip.time} • ${trip.type}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          subtitle: Text("${trip.company} • ${trip.seatsLeft} places restantes"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${trip.price} XOF",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SeatSelectionScreen(trip: trip),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("Choisir", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
