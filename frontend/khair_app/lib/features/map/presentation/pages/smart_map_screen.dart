import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart' hide MapEvent;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../domain/models/map_models.dart';
import '../managers/map_state_manager.dart';

class SmartMapScreen extends StatefulWidget {
  const SmartMapScreen({super.key});

  @override
  State<SmartMapScreen> createState() => _SmartMapScreenState();
}

class _SmartMapScreenState extends State<SmartMapScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  final _sheetController = DraggableScrollableController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<MapStateManager>().initialize();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F14),
          body: Stack(
            children: [
              // ─── Map ──────────────────────────
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
                    markers: state.clusters
                        .map(
                          (cluster) => Marker(
                            point: cluster.center,
                            width: cluster.isCluster ? 64 : 56,
                            height: cluster.isCluster ? 64 : 56,
                            child: GestureDetector(
                              onTap: () =>
                                  _handleClusterTap(context, cluster),
                              child: cluster.isCluster
                                  ? _ClusterMarker(
                                      count: cluster.count,
                                      zoom: state.zoom)
                                  : _EventMarker(
                                      event: cluster.singleEvent!),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),

              // ─── Search Bar + Subtitle ────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F2E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: context.l10n.mapSearchHint,
                                hintStyle: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.35),
                                    fontSize: 14),
                                prefixIcon: Icon(Icons.search_rounded,
                                    size: 20,
                                    color: Colors.white
                                        .withValues(alpha: 0.4)),
                                suffixIcon: _searchController
                                        .text.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          _searchFocus.unfocus();
                                          context
                                              .read<MapStateManager>()
                                              .updateFilters(
                                                state.filters.copyWith(
                                                    search: ''),
                                              );
                                        },
                                        child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: Colors.white
                                                .withValues(
                                                    alpha: 0.4)),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 13),
                              ),
                              textInputAction:
                                  TextInputAction.search,
                              onSubmitted: (query) {
                                _searchFocus.unfocus();
                                final trimmed = query.trim();
                                context
                                    .read<MapStateManager>()
                                    .updateFilters(
                                      state.filters
                                          .copyWith(search: trimmed),
                                    );
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Filter button
                        _FloatingButton(
                          icon: Icons.tune_rounded,
                          onTap: () => _showFilterChips(context, state),
                        ),
                        const SizedBox(width: 8),
                        // My location
                        _FloatingButton(
                          icon: state.isLocating
                              ? Icons.hourglass_top_rounded
                              : Icons.my_location_rounded,
                          onTap: () => context
                              .read<MapStateManager>()
                              .refreshUserLocation(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.mapFindKhairNearYou,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── "Search this area" button ────
              if (state.showSearchAreaButton)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 90,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () =>
                          context.read<MapStateManager>().searchThisArea(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.mapSearchThisArea,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── Loading pill ─────────────────
              if (state.status == MapLoadStatus.loading)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 90,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.mapLoadingEvents,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ─── Error pill ───────────────────
              if (state.errorMessage != null &&
                  state.status == MapLoadStatus.failure)
                Positioned(
                  bottom: 200,
                  left: 14,
                  right: 14,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1515),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

              // ─── Collapsible Bottom Sheet ─────
              DraggableScrollableSheet(
                initialChildSize: 0.12,
                minChildSize: 0.08,
                maxChildSize: 0.55,
                snap: true,
                snapSizes: const [0.12, 0.35, 0.55],
                controller: _sheetController,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF111827),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              18, 0, 18, 8),
                          child: Row(
                            children: [
                              Text(
                                '${state.events.length} events nearby',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if (state.filters.categories.isNotEmpty ||
                                  state.filters.eventType != 'all')
                                GestureDetector(
                                  onTap: () => context
                                      .read<MapStateManager>()
                                      .updateFilters(const MapFilters()),
                                  child: Text(
                                    'Clear filters',
                                    style: TextStyle(
                                      color: AppColors.primaryLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Event list or empty state
                        Expanded(
                          child: state.events.isEmpty &&
                                  state.status == MapLoadStatus.success
                              ? _buildEmptyState(context)
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 0, 14, 24),
                                  itemCount: state.events.length,
                                  itemBuilder: (context, index) {
                                    return _EventListCard(
                                      event: state.events[index],
                                      onTap: () {
                                        context.go(
                                            '/events/${state.events[index].id}');
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Event interaction ──────────────────────

  void _handleClusterTap(BuildContext context, MapClusterNode cluster) {
    if (cluster.isCluster) {
      final currentZoom = context.read<MapStateManager>().state.zoom;
      _mapController.move(
          cluster.center, (currentZoom + 1.4).clamp(3, 18));
      return;
    }
    final event = cluster.singleEvent!;
    context.read<MapStateManager>().onMarkerTapped(event);
    context.go('/events/${event.id}');
  }

  // ─── Empty state ────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              context.l10n.mapNoEventsFoundHere,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to create one!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/create-event'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.mapCreateEvent,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter chips bottom sheet ──────────────

  void _showFilterChips(BuildContext context, MapState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _FilterChipSheet(
          initialFilters: state.filters,
          onApply: (filters) {
            Navigator.pop(ctx);
            context.read<MapStateManager>().updateFilters(filters);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════
//  FILTER CHIP BOTTOM SHEET
// ═══════════════════════════════════════

class _FilterChipSheet extends StatefulWidget {
  final MapFilters initialFilters;
  final ValueChanged<MapFilters> onApply;

  const _FilterChipSheet({
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<_FilterChipSheet> createState() => _FilterChipSheetState();
}

class _FilterChipSheetState extends State<_FilterChipSheet> {
  late double _radius;
  late String _eventType;
  late Set<String> _categories;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialFilters.radiusKm;
    _eventType = widget.initialFilters.eventType;
    _categories = Set.from(widget.initialFilters.categories);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF141A26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.mapFilters,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Distance
          _SectionLabel(context.l10n.mapFilterDistance),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [5.0, 10.0, 25.0].map((km) {
              final selected = _radius == km;
              return ChoiceChip(
                label: Text('${km.toInt()} km'),
                selected: selected,
                onSelected: (_) => setState(() => _radius = km),
                selectedColor: AppColors.primary,
                backgroundColor:
                    Colors.white.withValues(alpha: 0.06),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Type
          _SectionLabel(context.l10n.mapFilterType),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ('all', context.l10n.mapFilterAll),
              ('in_person', context.l10n.mapFilterInPerson),
              ('online', context.l10n.mapFilterOnline),
            ].map((entry) {
              final selected = _eventType == entry.$1;
              return ChoiceChip(
                label: Text(entry.$2),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _eventType = entry.$1),
                selectedColor: AppColors.primary,
                backgroundColor:
                    Colors.white.withValues(alpha: 0.06),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Category
          _SectionLabel(context.l10n.mapFilterCategory),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ('quran', context.l10n.mapFilterQuran, Icons.menu_book_outlined),
              ('lecture', context.l10n.mapFilterLecture, Icons.record_voice_over_outlined),
              ('charity', context.l10n.mapFilterCharity, Icons.volunteer_activism_outlined),
              ('halaqa', context.l10n.mapFilterHalaqa, Icons.groups_outlined),
              ('family', context.l10n.mapFilterFamily, Icons.family_restroom_outlined),
            ].map((entry) {
              final selected = _categories.contains(entry.$1);
              return FilterChip(
                avatar: Icon(entry.$3,
                    size: 16,
                    color:
                        selected ? Colors.white : Colors.white54),
                label: Text(entry.$2),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _categories.add(entry.$1);
                    } else {
                      _categories.remove(entry.$1);
                    }
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor:
                    Colors.white.withValues(alpha: 0.06),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Apply
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(MapFilters(
                  radiusKm: _radius,
                  eventType: _eventType,
                  categories: _categories,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(context.l10n.mapApplyFilters,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ═══════════════════════════════════════
//  UI COMPONENTS
// ═══════════════════════════════════════

class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon,
            color: Colors.white.withValues(alpha: 0.7), size: 20),
      ),
    );
  }
}

class _EventListCard extends StatelessWidget {
  final MapEvent event;
  final VoidCallback onTap;

  const _EventListCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('EEE, MMM d • h:mm a').format(event.startsAt);
    final distanceText = event.isOnline
        ? 'Online'
        : '${event.distanceKm.toStringAsFixed(1)} km';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _categoryColor(event.category)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _categoryIcon(event.category),
                color: _categoryColor(event.category),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dateText  •  $distanceText',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.organization,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Join CTA
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Join',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
                child: const Icon(Icons.check,
                    color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.count, required this.zoom});

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
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.7),
            ],
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

// ═══════════════════════════════════════
//  CATEGORY HELPERS
// ═══════════════════════════════════════

Color _categoryColor(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('quran')) return const Color(0xFF19795A);
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
  if (lower.contains('quran')) return Icons.menu_book_outlined;
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
