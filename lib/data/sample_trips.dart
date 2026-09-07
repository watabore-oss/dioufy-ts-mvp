import 'trip.dart';

final now = DateTime.now();

final sampleTrips = <Trip>[
  Trip(
    id: 'DKR-THS-0700',
    operatorName: 'Garage Lat Dior Express',
    departureCity: 'Dakar',
    arrivalCity: 'Thies',
    departureTime: DateTime(now.year, now.month, now.day, 7),
    arrivalTime: DateTime(now.year, now.month, now.day, 8, 35),
    stationName: 'Gare des Baux Maraichers',
    vehicleType: 'Minibus climatisé',
    availableSeats: 12,
    priceXof: 2500,
    isVerified: true,
  ),
  Trip(
    id: 'DKR-THS-0830',
    operatorName: 'Sénégal Dem Dikk',
    departureCity: 'Dakar',
    arrivalCity: 'Thies',
    departureTime: DateTime(now.year, now.month, now.day, 8, 30),
    arrivalTime: DateTime(now.year, now.month, now.day, 10, 5),
    stationName: 'Petersen',
    vehicleType: 'Bus confort',
    availableSeats: 28,
    priceXof: 3000,
    isVerified: true,
  ),
  Trip(
    id: 'DKR-MBR-0915',
    operatorName: 'Touba Transport',
    departureCity: 'Dakar',
    arrivalCity: 'Mbour',
    departureTime: DateTime(now.year, now.month, now.day, 9, 15),
    arrivalTime: DateTime(now.year, now.month, now.day, 10, 50),
    stationName: 'Gare de Colobane',
    vehicleType: '7 places',
    availableSeats: 4,
    priceXof: 3500,
    isVerified: false,
  ),
  Trip(
    id: 'SL-KDL-1100',
    operatorName: 'Ndiaga Ndiaye Pro',
    departureCity: 'Saint-Louis',
    arrivalCity: 'Kaolack',
    departureTime: DateTime(now.year, now.month, now.day, 11),
    arrivalTime: DateTime(now.year, now.month, now.day, 16, 30),
    stationName: 'Gare Routière de Saint-Louis',
    vehicleType: 'Bus interurbain',
    availableSeats: 18,
    priceXof: 7500,
    isVerified: true,
  ),
];

List<Trip> searchTrips(String departure, String arrival) {
  final dep = departure.trim().toLowerCase();
  final arr = arrival.trim().toLowerCase();

  return sampleTrips.where((trip) {
    final matchesDeparture =
        dep.isEmpty || trip.departureCity.toLowerCase().contains(dep);
    final matchesArrival =
        arr.isEmpty || trip.arrivalCity.toLowerCase().contains(arr);
    return matchesDeparture && matchesArrival;
  }).toList()
    ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
}
