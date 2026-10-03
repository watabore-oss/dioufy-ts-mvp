import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/search/trip.dart';

/// Service de gestion et de mise à jour des trajets et prix (Super Admin & GIE)
/// SOURCE DE VÉRITÉ UNIQUE : Supabase table `trips`.
/// Aucun identifiant factice 'trip-custom-...' ni mocks locaux en SharedPreferences.
class TripManagementService extends ChangeNotifier {
  static TripManagementService? _instance;

  final List<Trip> _trips = [];
  bool _isLoading = false;

  TripManagementService._();

  static TripManagementService get instance {
    _instance ??= TripManagementService._();
    return _instance!;
  }

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;

  /// Chargement initial des trajets réels depuis Supabase
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('trips')
          .select('*, agencies(name)')
          .order('depart_at', ascending: true);

      final List list = res as List;
      _trips.clear();
      for (final item in list) {
        _trips.add(Trip.fromMap(item as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('[TripManagementService] Erreur lecture des trajets Supabase : $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Met à jour le prix en FCFA d'un trajet directement dans Supabase
  Future<void> updateTripPrice(String tripId, int newPriceFcfa) async {
    try {
      final client = Supabase.instance.client;
      await client
          .from('trips')
          .update({'price': newPriceFcfa})
          .eq('id', tripId);

      final index = _trips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        final old = _trips[index];
        _trips[index] = Trip(
          id: old.id,
          time: old.time,
          type: old.type,
          company: old.company,
          seatsLeft: old.seatsLeft,
          price: newPriceFcfa,
          departure: old.departure,
          arrival: old.arrival,
          seatsCount: old.seatsCount,
          departureStation: old.departureStation,
          arrivalStation: old.arrivalStation,
          amenities: old.amenities,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TripManagementService] Erreur updateTripPrice Supabase : $e');
      rethrow;
    }
  }

  /// Met à jour les détails d'un trajet dans Supabase
  Future<void> updateTripDetails({
    required String tripId,
    required String time,
    required String type,
    required int price,
    required int seatsCount,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('trips').update({
        'price': price,
        'seats_count': seatsCount,
      }).eq('id', tripId);

      final index = _trips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        final old = _trips[index];
        _trips[index] = Trip(
          id: old.id,
          time: time,
          type: type,
          company: old.company,
          seatsLeft: seatsCount < old.seatsLeft ? seatsCount : old.seatsLeft,
          price: price,
          departure: old.departure,
          arrival: old.arrival,
          seatsCount: seatsCount,
          departureStation: old.departureStation,
          arrivalStation: old.arrivalStation,
          amenities: old.amenities,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TripManagementService] Erreur updateTripDetails Supabase : $e');
      rethrow;
    }
  }

  /// Ajout d'un nouveau trajet réel dans Supabase
  Future<void> addTrip({
    required String departure,
    required String arrival,
    required String company,
    required String time,
    required String type,
    required int price,
    required int seatsCount,
    String? organizationId,
    String? driverId,
    String? vehicleId,
  }) async {
    try {
      final client = Supabase.instance.client;
      // Construction de la date de départ prévue
      final now = DateTime.now();
      final timeParts = time.split(':');
      final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 8 : 8;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final departAt = DateTime(now.year, now.month, now.day, hour, minute);

      final insertData = {
        'from_loc': departure,
        'to_loc': arrival,
        'depart_at': departAt.toIso8601String(),
        'price': price,
        'seats_count': seatsCount,
        'status': 'scheduled',
        if (organizationId != null) 'organization_id': organizationId,
        if (driverId != null) 'driver_id': driverId,
        if (vehicleId != null) 'vehicle_id': vehicleId,
      };

      final res = await client.from('trips').insert(insertData).select().single();
      final createdTrip = Trip.fromMap(res);
      _trips.insert(0, createdTrip);
      notifyListeners();
    } catch (e) {
      debugPrint('[TripManagementService] Erreur addTrip Supabase : $e');
      rethrow;
    }
  }

  /// Suppression d'un trajet dans Supabase
  Future<void> deleteTrip(String tripId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('trips').delete().eq('id', tripId);
      _trips.removeWhere((t) => t.id == tripId);
      notifyListeners();
    } catch (e) {
      debugPrint('[TripManagementService] Erreur deleteTrip Supabase : $e');
      rethrow;
    }
  }
}
