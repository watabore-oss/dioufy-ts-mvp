import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/dioufy_tokens.dart';
import '../../core/widgets/desktop_split_scaffold.dart';
import '../../services/trip_service.dart';
import '../seat_selection/seat_selection_screen.dart';
import 'trip.dart';

class SearchResultsScreen extends StatefulWidget {
  final String departure;
  final String destination;
  final String? travelDate;
  final int passengerCount;

  const SearchResultsScreen({
    super.key,
    required this.departure,
    required this.destination,
    this.travelDate,
    this.passengerCount = 1,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TripService _tripService = TripService();
  List<Trip> _allTrips = [];
  String _selectedCompanyFilter = "Toutes";
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 1. Affichage instantané (0ms) depuis le cache ou le catalogue local
    _allTrips = _tripService.getInstantTrips(
      departure: widget.departure,
      destination: widget.destination,
    );
    // 2. Revalidation asynchrone non-bloquante avec Supabase
    _revalidateTrips();
  }

  Future<void> _revalidateTrips() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final remoteTrips = await _tripService.searchTrips(
        departure: widget.departure,
        destination: widget.destination,
      );
      if (mounted) {
        setState(() {
          _allTrips = remoteTrips;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<Trip> get _filteredTrips {
    if (_selectedCompanyFilter == "Toutes") return _allTrips;
    return _allTrips
        .where((t) => t.company.toLowerCase().contains(_selectedCompanyFilter.toLowerCase()))
        .toList();
  }

  void _navigateToSeatSelection(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeatSelectionScreen(
          trip: trip,
          requestedPassengers: widget.passengerCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedDate = widget.travelDate ?? "Aujourd'hui";
    final displayedTrips = _filteredTrips;

    return DesktopSplitScaffold(
      title: "${widget.departure} → ${widget.destination}",
      subtitle: "$displayedDate • ${widget.passengerCount} passager${widget.passengerCount > 1 ? 's' : ''}",
      showBackButton: true,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: DioufyColors.primary, size: 22),
          tooltip: "Actualiser les départs",
          onPressed: _revalidateTrips,
        ),
      ],
      child: Column(
        children: [
          if (_isRefreshing)
            const LinearProgressIndicator(
              color: DioufyColors.primary,
              backgroundColor: DioufyColors.surfaceSoft,
              minHeight: 3,
            ),

          // Barre de filtres par compagnie (lumineuse et dynamique)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("Toutes"),
                  ...{
                    ..._allTrips.map((t) => t.company).where((c) => c.trim().isNotEmpty)
                  }.map((company) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildFilterChip(company),
                      )),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: DioufyColors.border),

          Expanded(
            child: displayedTrips.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_bus_outlined, size: 68, color: DioufyColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun départ disponible',
                            style: TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              fontWeight: DioufyTypography.bold,
                              fontSize: 20,
                              color: DioufyColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucun car trouvé pour ${widget.departure} → ${widget.destination} à la date du $displayedDate.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: DioufyTypography.fontFamily,
                              color: DioufyColors.textSecondary,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              "Modifier la recherche",
                              style: TextStyle(fontFamily: DioufyTypography.fontFamily, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DioufyColors.primary,
                              shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                 : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayedTrips.length,
                    itemBuilder: (context, index) {
                      final trip = displayedTrips[index];
                      final int totalForPassengers = trip.price * widget.passengerCount;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: Colors.white,
                          borderRadius: DioufyRadius.lgAll,
                          clipBehavior: Clip.antiAlias,
                          elevation: 1.5,
                          shadowColor: const Color(0x1A0F172A),
                          child: InkWell(
                            onTap: () => _navigateToSeatSelection(trip),
                            borderRadius: DioufyRadius.lgAll,
                            mouseCursor: SystemMouseCursors.click,
                            splashColor: DioufyColors.primary.withValues(alpha: 0.1),
                            highlightColor: DioufyColors.primary.withValues(alpha: 0.04),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: DioufyRadius.lgAll,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  // En-tête carte : Compagnie et Type de car
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: DioufyColors.primarySoft,
                                                borderRadius: DioufyRadius.smAll,
                                              ),
                                              child: const Icon(
                                                Icons.directions_bus_rounded,
                                                color: DioufyColors.primary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                trip.company,
                                                style: const TextStyle(
                                                  fontFamily: DioufyTypography.fontFamily,
                                                  fontWeight: DioufyTypography.bold,
                                                  fontSize: 16.5,
                                                  color: DioufyColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: DioufyColors.emeraldSoft,
                                          borderRadius: DioufyRadius.smAll,
                                          border: Border.all(color: DioufyColors.emeraldLight.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          trip.type,
                                          style: const TextStyle(
                                            fontFamily: DioufyTypography.fontFamily,
                                            color: DioufyColors.emerald,
                                            fontWeight: DioufyTypography.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Heure, durée et trajet (Typographie rehaussée)
                                  Row(
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 120),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trip.time,
                                              style: const TextStyle(
                                                fontFamily: DioufyTypography.fontFamily,
                                                fontSize: 24,
                                                fontWeight: DioufyTypography.black,
                                                color: DioufyColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              trip.departureStation,
                                              style: const TextStyle(
                                                fontFamily: DioufyTypography.fontFamily,
                                                fontSize: 13,
                                                color: DioufyColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              trip.duration,
                                              style: const TextStyle(
                                                fontFamily: DioufyTypography.fontFamily,
                                                fontSize: 12.5,
                                                fontWeight: DioufyTypography.bold,
                                                color: DioufyColors.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Row(
                                                children: [
                                                  const CircleAvatar(radius: 3, backgroundColor: DioufyColors.primary),
                                                  Expanded(child: Container(height: 1.5, color: DioufyColors.border)),
                                                  const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: DioufyColors.primary),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 120),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              "Arrivée",
                                              style: TextStyle(
                                                fontFamily: DioufyTypography.fontFamily,
                                                fontSize: 12,
                                                color: DioufyColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              trip.arrivalStation,
                                              style: const TextStyle(
                                                fontFamily: DioufyTypography.fontFamily,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: DioufyColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.end,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),
                                  const Divider(height: 1, color: DioufyColors.surfaceSoft),
                                  const SizedBox(height: 12),

                                  // Bas de la carte : Places restantes, prix FCFA et bouton d'action
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 4,
                                              children: [
                                                const Icon(Icons.event_seat_rounded, size: 15, color: DioufyColors.textSecondary),
                                                Text(
                                                  "${trip.seatsLeft} places restantes",
                                                  style: TextStyle(
                                                    fontFamily: DioufyTypography.fontFamily,
                                                    fontSize: 13,
                                                    color: trip.seatsLeft < 5 ? DioufyColors.coral : DioufyColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 5,
                                              children: [
                                                Text(
                                                  "${trip.price} FCFA",
                                                  style: const TextStyle(
                                                    fontFamily: DioufyTypography.fontFamily,
                                                    fontSize: 20,
                                                    fontWeight: DioufyTypography.black,
                                                    color: DioufyColors.emerald,
                                                  ),
                                                ),
                                                const XofCurrencyBadge(size: 17),
                                                if (widget.passengerCount > 1)
                                                  const Text(
                                                    "/ place",
                                                    style: TextStyle(
                                                      fontFamily: DioufyTypography.fontFamily,
                                                      fontSize: 12,
                                                      color: DioufyColors.textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (widget.passengerCount > 1) ...[
                                              Text(
                                                "Total: $totalForPassengers FCFA",
                                                style: const TextStyle(
                                                  fontFamily: DioufyTypography.fontFamily,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: DioufyColors.primary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _navigateToSeatSelection(trip),
                                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                        label: const Text(
                                          "Choisir ce car",
                                          style: TextStyle(
                                            fontFamily: DioufyTypography.fontFamily,
                                            fontWeight: DioufyTypography.bold,
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: DioufyColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: DioufyRadius.mdAll,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCompanyFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: DioufyColors.primary,
      backgroundColor: DioufyColors.surfaceSoft,
      labelStyle: TextStyle(
        fontFamily: DioufyTypography.fontFamily,
        color: isSelected ? Colors.white : DioufyColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: DioufyRadius.smAll,
        side: BorderSide(
          color: isSelected ? DioufyColors.primary : DioufyColors.border,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedCompanyFilter = label);
        }
      },
    );
  }
}
