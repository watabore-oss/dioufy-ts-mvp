import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/search/trip.dart';

/// Service de gestion et de mise à jour des trajets et prix (Super Admin)
class TripManagementService extends ChangeNotifier {
  static const String _storageKey = 'dioufy_managed_trips_v1';
  static TripManagementService? _instance;

  final List<Trip> _trips = [];

  TripManagementService._();

  static TripManagementService get instance {
    _instance ??= TripManagementService._();
    return _instance!;
  }

  List<Trip> get trips => List.unmodifiable(_trips);

  Future<void> initialize() async {
    _trips.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null) {
        final List<dynamic> list = jsonDecode(rawJson);
        for (final item in list) {
          _trips.add(Trip.fromMap(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture des trajets personnalisés : $e');
    }

    // Si aucun trajet persisté, initialiser les trajets sénégalais de référence
    if (_trips.isEmpty) {
      _trips.addAll([
        const Trip(
          id: 't0000000-0000-0000-0000-000000000001',
          time: '08:30',
          type: 'CONFORT',
          company: 'Dioufy Trans',
          seatsLeft: 18,
          price: 7500, // FCFA
          departure: 'Dakar',
          arrival: 'Thiès',
          seatsCount: 36,
        ),
        const Trip(
          id: 't0000000-0000-0000-0000-000000000002',
          time: '10:15',
          type: 'STANDARD',
          company: 'Galsen Tour',
          seatsLeft: 12,
          price: 4500, // FCFA
          departure: 'Dakar',
          arrival: 'Thiès',
          seatsCount: 36,
        ),
        const Trip(
          id: 't0000000-0000-0000-0000-000000000003',
          time: '07:00',
          type: 'CONFORT',
          company: 'Touba Express',
          seatsLeft: 24,
          price: 5000, // FCFA
          departure: 'Dakar',
          arrival: 'Touba',
          seatsCount: 50,
        ),
        const Trip(
          id: 't0000000-0000-0000-0000-000000000004',
          time: '12:30',
          type: 'VIP CLIMATISÉ',
          company: 'Baol Trans',
          seatsLeft: 15,
          price: 6000, // FCFA
          departure: 'Dakar',
          arrival: 'Touba',
          seatsCount: 40,
        ),
        const Trip(
          id: 't0000000-0000-0000-0000-000000000005',
          time: '06:30',
          type: 'CONFORT',
          company: 'Ndiolofène Voyages',
          seatsLeft: 20,
          price: 9000, // FCFA
          departure: 'Dakar',
          arrival: 'Saint-Louis',
          seatsCount: 45,
        ),
      ]);
    }
    notifyListeners();
  }

  /// Met à jour le prix en FCFA d'un trajet
  Future<void> updateTripPrice(String tripId, int newPriceFcfa) async {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;

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
    await _persist();
  }

  /// Met à jour l'horaire et le type d'un trajet
  Future<void> updateTripDetails({
    required String tripId,
    required String time,
    required String type,
    required int price,
    required int seatsCount,
  }) async {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return;

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
    await _persist();
  }

  /// Ajout d'un nouveau trajet par le Super Admin
  Future<void> addTrip({
    required String departure,
    required String arrival,
    required String company,
    required String time,
    required String type,
    required int price,
    required int seatsCount,
  }) async {
    final newTrip = Trip(
      id: 'trip-custom-${DateTime.now().millisecondsSinceEpoch}',
      departure: departure,
      arrival: arrival,
      company: company,
      time: time,
      type: type,
      price: price,
      seatsCount: seatsCount,
      seatsLeft: seatsCount,
    );
    _trips.insert(0, newTrip);
    notifyListeners();
    await _persist();
  }

  /// Suppression d'un trajet
  Future<void> deleteTrip(String tripId) async {
    _trips.removeWhere((t) => t.id == tripId);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _trips.map((t) => t.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Erreur persistance des trajets : $e');
    }
  }
}
