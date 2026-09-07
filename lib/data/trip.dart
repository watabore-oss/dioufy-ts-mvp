class Trip {
  const Trip({
    required this.id,
    required this.operatorName,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.stationName,
    required this.vehicleType,
    required this.availableSeats,
    required this.priceXof,
    required this.isVerified,
  });

  final String id;
  final String operatorName;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String stationName;
  final String vehicleType;
  final int availableSeats;
  final int priceXof;
  final bool isVerified;

  String get durationLabel {
    final duration = arrivalTime.difference(departureTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}';
  }

  String get priceLabel {
    final digits = priceXof.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index += 1) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
    }

    return '$buffer FCFA';
  }
}
