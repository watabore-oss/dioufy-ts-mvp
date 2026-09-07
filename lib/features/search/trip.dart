class Trip {
  final String id;
  final String company;
  final String departure;
  final String arrival;
  final String time;
  final int price;
  final String type; // "CONFORT" ou "STANDARD"
  final int seatsLeft;

  const Trip({
    required this.id,
    required this.company,
    required this.departure,
    required this.arrival,
    required this.time,
    required this.price,
    required this.type,
    required this.seatsLeft,
  });
}
