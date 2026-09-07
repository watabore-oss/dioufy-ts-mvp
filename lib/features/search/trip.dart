class Trip {
  final String id;
  final String company;
  final String departure;
  final String arrival;
  final String time;
  final int price;
  final String type; // "CONFORT" ou "STANDARD"
  final int seatsLeft;
  final int seatsCount;

  const Trip({
    required this.id,
    required this.company,
    required this.departure,
    required this.arrival,
    required this.time,
    required this.price,
    required this.type,
    required this.seatsLeft,
    this.seatsCount = 36,
  });

  /// Construit un objet [Trip] depuis un enregistrement Supabase ou local
  factory Trip.fromMap(Map<String, dynamic> map) {
    // Extraction de l'agence (jointure agencies(name))
    String company = 'Dioufy Trans';
    if (map['agencies'] != null && map['agencies'] is Map) {
      company = map['agencies']['name']?.toString() ?? company;
    } else if (map['company'] != null) {
      company = map['company'].toString();
    }

    // Formatage de l'heure de depart
    String time = "08:00";
    if (map['depart_at'] != null) {
      try {
        final dt = DateTime.parse(map['depart_at'].toString()).toLocal();
        time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        time = map['depart_at'].toString();
      }
    } else if (map['time'] != null) {
      time = map['time'].toString();
    }

    // Calcul dynamique des places disponibles depuis la relation seats
    final int seatsCount = (map['seats_count'] as num?)?.toInt() ?? 36;
    int calculatedSeatsLeft = seatsCount;

    if (map['seats'] != null && map['seats'] is List) {
      final List seatsList = map['seats'] as List;
      final now = DateTime.now();
      int occupiedCount = 0;
      for (var s in seatsList) {
        if (s is Map) {
          final status = s['status']?.toString();
          if (status == 'occupied' || status == 'booked' || status == 'sold') {
            occupiedCount++;
          } else if (status == 'locked') {
            final lockUntilStr = s['lock_until']?.toString();
            if (lockUntilStr != null) {
              final lockUntil = DateTime.tryParse(lockUntilStr);
              if (lockUntil != null && lockUntil.isAfter(now)) {
                occupiedCount++;
              }
            } else {
              occupiedCount++;
            }
          }
        }
      }
      calculatedSeatsLeft = (seatsCount - occupiedCount).clamp(0, seatsCount);
    } else if (map['seats_left'] != null) {
      calculatedSeatsLeft = (map['seats_left'] as num).toInt();
    } else if (map['seatsLeft'] != null) {
      calculatedSeatsLeft = (map['seatsLeft'] as num).toInt();
    }

    // Type de trajet (metadata jsonb)
    String type = "CONFORT";
    if (map['metadata'] != null && map['metadata'] is Map) {
      type = map['metadata']['type']?.toString() ?? type;
    } else if (map['type'] != null) {
      type = map['type'].toString();
    }

    return Trip(
      id: map['id']?.toString() ?? '',
      company: company,
      departure: (map['from_loc'] ?? map['departure'] ?? '').toString(),
      arrival: (map['to_loc'] ?? map['arrival'] ?? '').toString(),
      time: time,
      price: (map['price'] as num?)?.toInt() ?? 0,
      type: type,
      seatsLeft: calculatedSeatsLeft,
      seatsCount: seatsCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'departure': departure,
      'arrival': arrival,
      'time': time,
      'price': price,
      'type': type,
      'seatsLeft': seatsLeft,
      'seatsCount': seatsCount,
    };
  }
}
