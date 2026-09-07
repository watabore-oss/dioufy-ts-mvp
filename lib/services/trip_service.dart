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

  /// Cache en memoire pour eviter toute requete reseau repetee inutile
  static final Map<String, List<Trip>> _memoryCache = {};

  /// Trajets par defaut utilises en mode hors-ligne ou si la base distante est vide.
  static final List<Trip> _fallbackTrips = [
    // Dakar -> Thies
    const Trip(
      id: 't0000000-0000-0000-0000-000000000001',
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
      id: 't0000000-0000-0000-0000-000000000002',
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
      id: 't0000000-0000-0000-0000-000000000005',
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
      id: 't0000000-0000-0000-0000-000000000003',
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
      id: 't0000000-0000-0000-0000-000000000004',
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
      id: 't0000000-0000-0000-0000-000000000006',
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

  /// Recupere instantanement (0ms) les trajets disponibles sans attendre le reseau.
  List<Trip> getInstantTrips({
    required String departure,
    required String destination,
  }) {
    final cleanDep = _cleanCityName(departure);
    final cleanDest = _cleanCityName(destination);
    final cacheKey = '$cleanDep->$cleanDest';

    if (_memoryCache.containsKey(cacheKey) && _memoryCache[cacheKey]!.isNotEmpty) {
      return _memoryCache[cacheKey]!;
    }

    return _fallbackTrips.where((t) {
      final tDep = _cleanCityName(t.departure);
      final tDest = _cleanCityName(t.arrival);
      return (tDep.contains(cleanDep) || cleanDep.contains(tDep)) &&
          (tDest.contains(cleanDest) || cleanDest.contains(tDest));
    }).toList();
  }

  /// Recherche les trajets avec revalidation Supabase rapide et timeout de 1500ms
  Future<List<Trip>> searchTrips({
    required String departure,
    required String destination,
  }) async {
    final cleanDep = _cleanCityName(departure);
    final cleanDest = _cleanCityName(destination);
    final cacheKey = '$cleanDep->$cleanDest';

    if (_client != null) {
      try {
        final response = await _client!
            .from('trips')
            .select('*, agencies(name), seats(id, status, lock_until)')
            .ilike('from_loc', '%$cleanDep%')
            .ilike('to_loc', '%$cleanDest%')
            .order('depart_at', ascending: true)
            .timeout(const Duration(milliseconds: 1500));

        final List list = response as List;
        if (list.isNotEmpty) {
          final remoteTrips =
              list.map((item) => Trip.fromMap(item as Map<String, dynamic>)).toList();
          _memoryCache[cacheKey] = remoteTrips;
          return remoteTrips;
        }
      } catch (e) {
        debugPrint('Recherche Supabase repli rapide: $e');
      }
    }

    final localTrips = getInstantTrips(departure: departure, destination: destination);
    _memoryCache[cacheKey] = localTrips;
    return localTrips;
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
