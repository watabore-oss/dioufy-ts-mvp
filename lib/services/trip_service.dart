import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/search/trip.dart';

/// Service responsable de la recherche et de la recuperation des trajets.
///
/// Interroge la table `trips` de Supabase avec jointures et calcul des disponibilites.
/// Propose un repli local (offline-capable) en cas d'absence de reseau ou table vide.
class TripService {
  final SupabaseClient? _client;

  TripService({SupabaseClient? client})
      : _client = client ?? _getSupabaseClientSafely();

  static SupabaseClient? _getSupabaseClientSafely() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Trajets par defaut utilises en mode hors-ligne ou si la base distante est vide.
  static final List<Trip> _fallbackTrips = [
    // Dakar -> Thies
    const Trip(
      id: 't1',
      time: "08:30",
      type: "CONFORT",
      company: "Dioufy Trans",
      seatsLeft: 12,
      price: 7500,
      departure: "Dakar",
      arrival: "Thies",
      seatsCount: 36,
    ),
    const Trip(
      id: 't2',
      time: "10:15",
      type: "STANDARD",
      company: "Galsen Tour",
      seatsLeft: 4,
      price: 4500,
      departure: "Dakar",
      arrival: "Thies",
      seatsCount: 36,
    ),
    const Trip(
      id: 't3',
      time: "14:00",
      type: "CONFORT",
      company: "Dioufy Trans",
      seatsLeft: 20,
      price: 8200,
      departure: "Dakar",
      arrival: "Thies",
      seatsCount: 36,
    ),
    // Dakar -> Touba
    const Trip(
      id: 't4',
      time: "07:00",
      type: "CONFORT",
      company: "Dioufy Trans",
      seatsLeft: 18,
      price: 12500,
      departure: "Dakar",
      arrival: "Touba",
      seatsCount: 36,
    ),
    const Trip(
      id: 't5',
      time: "09:45",
      type: "STANDARD",
      company: "Touba Express",
      seatsLeft: 8,
      price: 9500,
      departure: "Dakar",
      arrival: "Touba",
      seatsCount: 36,
    ),
    const Trip(
      id: 't6',
      time: "13:30",
      type: "CONFORT",
      company: "Dioufy Trans",
      seatsLeft: 15,
      price: 13200,
      departure: "Dakar",
      arrival: "Touba",
      seatsCount: 36,
    ),
  ];

  /// Recherche les trajets correspondants au depart et a la destination
  Future<List<Trip>> searchTrips({
    required String departure,
    required String destination,
  }) async {
    final cleanDep = _cleanCityName(departure);
    final cleanDest = _cleanCityName(destination);

    if (_client != null) {
      try {
        final response = await _client!
            .from('trips')
            .select('*, agencies(name), seats(id, status, lock_until)')
            .ilike('from_loc', '%$cleanDep%')
            .ilike('to_loc', '%$cleanDest%')
            .order('depart_at', ascending: true);

        final List list = response as List;
        if (list.isNotEmpty) {
          return list.map((item) => Trip.fromMap(item as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Avertissement Supabase searchTrips: $e');
      }
    }

    // Repli local en cas d'echec reseau ou si la table n'a pas encore de donnees
    return _fallbackTrips.where((t) {
      final tDep = _cleanCityName(t.departure);
      final tDest = _cleanCityName(t.arrival);
      return (tDep.contains(cleanDep) || cleanDep.contains(tDep)) &&
          (tDest.contains(cleanDest) || cleanDest.contains(tDest));
    }).toList();
  }

  static String _cleanCityName(String city) {
    return city
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim()
        .toLowerCase()
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e');
  }
}
