import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/trip.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onReserve});

  final Trip trip;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.operatorName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (trip.isVerified)
                  const Chip(
                    label: Text('Vérifié'),
                    avatar: Icon(Icons.verified, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _TimeCity(
                  time: timeFormat.format(trip.departureTime),
                  city: trip.departureCity,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Divider(thickness: 1.4),
                      Text(
                        trip.durationLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                _TimeCity(
                  time: timeFormat.format(trip.arrivalTime),
                  city: trip.arrivalCity,
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.location_on_outlined,
                  label: trip.stationName,
                ),
                _InfoPill(
                  icon: Icons.directions_bus_outlined,
                  label: trip.vehicleType,
                ),
                _InfoPill(
                  icon: Icons.event_seat_outlined,
                  label: '${trip.availableSeats} places',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.priceLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: DioufyTheme.emerald,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onReserve,
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Réserver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCity extends StatelessWidget {
  const _TimeCity({
    required this.time,
    required this.city,
    this.alignEnd = false,
  });

  final String time;
  final String city;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(city, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: DioufyTheme.trustBlue),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
