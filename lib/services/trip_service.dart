import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/search/trip.dart';

/// Service responsable de la recherche et de la récupération des trajets.
///
/// SOURCE DE VÉRITÉ UNIQUE : Supabase table `trips`.
/// RÈGLE P0 DE L'AUDIT :
/// - Aucun trajet de démonstration en dur ni identifiants factices.
/// - Supabase est l'unique source de vérité.
/// - En cas d'erreur réseau, afficher une erreur explicite ou liste vide,
///   jamais de faux résultats trompeurs pour l'utilisateur.
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

  /// Cache en mémoire pour éviter toute requête réseau répétée inutile
  static final Map<String, List<Trip>> _memoryCache = {};

  /// Récupère les trajets déjà chargés en mémoire pour cette ligne (si disponibles)
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

    return const [];
  }

  /// Recherche les trajets en interrogeant exclusivement la base Supabase distante
  Future<List<Trip>> searchTrips({
    required String departure,
    required String destination,
  }) async {
    final cleanDep = _cleanCityName(departure);
    final cleanDest = _cleanCityName(destination);
    final cacheKey = '$cleanDep->$cleanDest';

    final client = _client;
    if (client == null) {
      throw Exception('Connexion au serveur Supabase indisponible.');
    }

    try {
      final response = await client
          .from('trips')
          .select('*, agencies(name), seats(id, status, lock_until)')
          .ilike('from_loc', '%$cleanDep%')
          .ilike('to_loc', '%$cleanDest%')
          .order('depart_at', ascending: true)
          .timeout(const Duration(seconds: 5));

      final List list = response as List;
      final remoteTrips =
          list.map((item) => Trip.fromMap(item as Map<String, dynamic>)).toList();

      _memoryCache[cacheKey] = remoteTrips;
      return remoteTrips;
    } catch (e) {
      debugPrint('[TripService] Erreur recherche Supabase : $e');
      rethrow;
    }
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
