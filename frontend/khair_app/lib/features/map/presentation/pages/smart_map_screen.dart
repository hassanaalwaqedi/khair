import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' hide MapEvent;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/map_models.dart';
import '../managers/map_state_manager.dart';
import '../widgets/filter_panel.dart';
import '../widgets/recommendation_overlay.dart';

class SmartMapScreen extends StatefulWidget {
  const SmartMapScreen({super.key});

  @override
  State<SmartMapScreen> createState() => _SmartMapScreenState();
}

class _SmartMapScreenState extends State<SmartMapScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    context.read<MapStateManager>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MapStateManager, MapState>(
      listenWhen: (previous, current) =>
          previous.center != current.center &&
          previous.isLocating &&
          !current.isLocating,
      listener: (context, state) {
        if (!_mapReady) return;
        _mapController.move(state.center, state.zoom);
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: state.center,
                  initialZoom: state.zoom,
                  onMapReady: () {
                    _mapReady = true;
                    _mapController.move(state.center, state.zoom);
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (!hasGesture) return;
                    final bounds = camera.visibleBounds;
                    context.read<MapStateManager>().onViewportChanged(
                          center: camera.center,
                          northEast: bounds.northEast,
                          southWest: bounds.southWest,
                          zoom: camera.zoom,
                        );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.khair.khair_app',
                  ),
                  MarkerLayer(
                    markers: state.contextPlaces
                        .map(
                          (place) => Marker(
                            point: place.point,
                            width: 40,
                            height: 40,
                            child: _ContextPlacePin(place: place),
                          ),
                        )
                        .toList(),
                  ),
                  MarkerLayer(
                    markers: state.clusters
                        .map(
                          (cluster) => Marker(
                            point: cluster.center,
                            width: cluster.isCluster ? 64 : 56,
                            height: cluster.isCluster ? 64 : 56,
                            child: GestureDetector(
                              onTap: () => _handleClusterTap(context, cluster),
                              child: cluster.isCluster
                                  ? _ClusterMarker(
                                      count: cluster.count, zoom: state.zoom)
                                  : _EventMarker(event: cluster.singleEvent!),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    _TopBar(
                      onFilterTap: () => _openFilterSheet(context, state),
                      onLocateTap: () =>
                          context.read<MapStateManager>().refreshUserLocation(),
                      isLocating: state.isLocating,
                      label: l10n.mapDiscoverNearbyEvents,
                    ),
                    const SizedBox(height: 10),
                    RecommendationOverlay(
                      events: state.recommendations,
                      onSelect: (event) {
                        _mapController.move(event.point, 15);
                        _showEventBottomSheet(context, event);
                      },
                    ),
                  ],
                ),
              ),
              if (state.status == MapLoadStatus.loading)
                Positioned(
                  bottom: 110,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _StatusPill(
                      label: state.isOffline
                          ? l10n.mapLoadingCachedResults
                          : l10n.mapLoadingEvents,
                      showLoader: true,
                    ),
                  ),
                ),
              if (state.errorMessage != null &&
                  state.status == MapLoadStatus.failure)
                Positioned(
                  bottom: 110,
                  left: 14,
                  right: 14,
                  child: _StatusPill(label: state.errorMessage!),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleClusterTap(BuildContext context, MapClusterNode cluster) {
    if (cluster.isCluster) {
      final currentZoom = context.read<MapStateManager>().state.zoom;
      _mapController.move(cluster.center, (currentZoom + 1.4).clamp(3, 18));
      return;
    }
    _showEventBottomSheet(context, cluster.singleEvent!);
  }

  Future<void> _openFilterSheet(BuildContext context, MapState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return FilterPanel(
          initialFilters: state.filters,
          options: state.filterOptions,
          onApply: (filters) {
            Navigator.pop(context);
            context.read<MapStateManager>().updateFilters(filters);
          },
        );
      },
    );
  }

  Future<void> _showEventBottomSheet(
      BuildContext context, MapEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    final localeCode = Localizations.localeOf(context).languageCode;
    context.read<MapStateManager>().onMarkerTapped(event);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final dateText =
            DateFormat.yMMMd(localeCode).add_jm().format(event.startsAt);
        final remaining = event.remainingSeats;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (event.trustLevel == 'verified' ||
                        event.trustLevel == 'trusted')
                      _Badge(label: l10n.mapVerifiedBadge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(event.organization,
                    style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 6),
                Text(dateText),
                const SizedBox(height: 6),
                Text(l10n.mapKmAway(event.distanceKm.toStringAsFixed(1))),
                if (remaining != null) ...[
                  const SizedBox(height: 6),
                  Text(l10n.mapRemainingSeats(remaining)),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context
                              .read<MapStateManager>()
                              .onReservationFromMap(event);
                          Navigator.pop(context);
                          context.go('/events/${event.id}');
                        },
                        icon: const Icon(Icons.event_seat),
                        label: Text(l10n.mapReserveSeat),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openDirections(event),
                        icon: const Icon(Icons.navigation_outlined),
                        label: Text(l10n.mapGetDirections),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDirections(MapEvent event) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${event.latitude},${event.longitude}',
    ).toString();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mapDirectionsCopied)),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onFilterTap,
    required this.onLocateTap,
    required this.isLocating,
    required this.label,
  });

  final VoidCallback onFilterTap;
  final VoidCallback onLocateTap;
  final bool isLocating;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.travel_explore_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ActionCircle(
          icon: Icons.tune,
          onTap: onFilterTap,
        ),
        const SizedBox(width: 8),
        _ActionCircle(
          icon: isLocating ? Icons.hourglass_top : Icons.my_location_outlined,
          onTap: onLocateTap,
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _EventMarker extends StatelessWidget {
  const _EventMarker({required this.event});

  final MapEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(event.category);
    final icon = _categoryIcon(event.category);
    final verified =
        event.trustLevel == 'verified' || event.trustLevel == 'trusted';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (verified)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E9E66),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.count,
    required this.zoom,
  });

  final int count;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final scale = (zoom / 12).clamp(0.85, 1.2);
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0A8F74), Color(0xFF0C6E8A)],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ContextPlacePin extends StatelessWidget {
  const _ContextPlacePin({required this.place});

  final MapContextPlace place;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (place.placeType) {
      case 'mosque':
        color = const Color(0xFF147D56);
        icon = Icons.mosque_outlined;
        break;
      case 'islamic_center':
        color = const Color(0xFF0A6B9A);
        icon = Icons.account_balance_outlined;
        break;
      default:
        color = const Color(0xFFB46D13);
        icon = Icons.restaurant_outlined;
    }

    return Tooltip(
      message: place.name,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.showLoader = false,
  });

  final String label;
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLoader) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF1E9E66).withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1E9E66),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

Color _categoryColor(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('quran')) {
    return const Color(0xFF19795A);
  }
  if (lower.contains('lecture') || lower.contains('halaqa')) {
    return const Color(0xFF1E6A9D);
  }
  if (lower.contains('charity') || lower.contains('zakat')) {
    return const Color(0xFFA46711);
  }
  if (lower.contains('family') || lower.contains('kids')) {
    return const Color(0xFF8E4C9E);
  }
  final hash = lower.hashCode.abs() % 4;
  switch (hash) {
    case 0:
      return const Color(0xFF1D7D6B);
    case 1:
      return const Color(0xFF2D6FA8);
    case 2:
      return const Color(0xFF9B5D2A);
    default:
      return const Color(0xFF6467A8);
  }
}

IconData _categoryIcon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('quran')) {
    return Icons.menu_book_outlined;
  }
  if (lower.contains('lecture') || lower.contains('halaqa')) {
    return Icons.record_voice_over_outlined;
  }
  if (lower.contains('charity') || lower.contains('zakat')) {
    return Icons.volunteer_activism_outlined;
  }
  if (lower.contains('family') || lower.contains('kids')) {
    return Icons.family_restroom_outlined;
  }
  return Icons.event_available_outlined;
}
