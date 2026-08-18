import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart' hide MapEvent;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/api_config.dart';
import '../../../../tokens/tokens.dart';
import '../../domain/models/map_models.dart';
import '../managers/map_state_manager.dart';

/// A discovery-first map. Fetches only on explicit search/filter actions;
/// dragging the map merely offers a new viewport search.
class SmartMapScreen extends StatefulWidget {
  const SmartMapScreen({super.key});

  @override
  State<SmartMapScreen> createState() => _SmartMapScreenState();
}

class _SmartMapScreenState extends State<SmartMapScreen> {
  final _mapController = MapController();
  final _search = TextEditingController();
  final _cards = PageController(viewportFraction: .82);
  bool _mapReady = false;
  LatLng? _lastCameraCenter;

  @override
  void initState() {
    super.initState();
    context.read<MapStateManager>().initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    _cards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return BlocConsumer<MapStateManager, MapState>(
      listenWhen: (old, next) =>
          old.selectedEvent?.id != next.selectedEvent?.id ||
          (old.isLocating && !next.isLocating && old.center != next.center),
      listener: (_, state) {
        if (_mapReady && state.center != _lastCameraCenter) {
          _lastCameraCenter = state.center;
          _mapController.move(state.center, state.zoom);
        }
        final selected = state.selectedEvent;
        if (selected == null || !_cards.hasClients) return;
        final index =
            state.events.indexWhere((event) => event.id == selected.id);
        if (index >= 0) {
          _cards.animateToPage(index,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut);
        }
      },
      builder: (context, state) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: state.center,
              initialZoom: state.zoom,
              onMapReady: () {
                _mapReady = true;
                _lastCameraCenter = state.center;
                _mapController.move(state.center, state.zoom);
              },
              onPositionChanged: (camera, hasGesture) {
                if (!hasGesture) return;
                _lastCameraCenter = camera.center;
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.khair.khair_app',
              ),
              MarkerLayer(
                  markers: state.clusters
                      .map((cluster) => Marker(
                            point: cluster.center,
                            width: cluster.isCluster ? 62 : 54,
                            height: cluster.isCluster ? 62 : 54,
                            child: Semantics(
                              button: true,
                              label: cluster.isCluster
                                  ? '${cluster.count} events'
                                  : cluster.singleEvent!.title,
                              child: GestureDetector(
                                onTap: () => _onClusterTap(cluster, state),
                                child: cluster.isCluster
                                    ? _KhairClusterMarker(count: cluster.count)
                                    : _KhairEventMarker(
                                        event: cluster.singleEvent!,
                                        selected: state.selectedEvent?.id ==
                                            cluster.singleEvent!.id),
                              ),
                            ),
                          ))
                      .toList()),
            ],
          ),
          _MapSearchControls(
            controller: _search,
            filters: state.filters,
            locating: state.isLocating,
            onSearch: (query) => context
                .read<MapStateManager>()
                .updateFilters(state.filters.copyWith(search: query.trim())),
            onFilters: () => _showFilters(state),
            onLocation: () =>
                context.read<MapStateManager>().refreshUserLocation(),
            onQuickFilter: (filters) =>
                context.read<MapStateManager>().updateFilters(filters),
          ),
          if (state.showSearchAreaButton)
            PositionedDirectional(
              top: 136,
              start: 0,
              end: 0,
              child: Center(
                  child: FilledButton.icon(
                onPressed: () =>
                    context.read<MapStateManager>().searchThisArea(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Search this area'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: const StadiumBorder()),
              )),
            ),
          if (state.status == MapLoadStatus.loading)
            const PositionedDirectional(
                top: 136,
                start: 0,
                end: 0,
                child: Center(
                    child: _StatusPill(
                        icon: Icons.hourglass_top_rounded,
                        text: 'Finding events…'))),
          if (state.locationPermissionDenied)
            const PositionedDirectional(
                top: 188,
                start: 16,
                end: 16,
                child: _NoticePill(
                    text: 'Enable location to discover events near you.')),
          if (state.status == MapLoadStatus.failure)
            PositionedDirectional(
                top: 188,
                start: 16,
                end: 16,
                child: _NoticePill(
                    text: state.errorMessage ??
                        'We couldn’t load events right now.',
                    retry: () =>
                        context.read<MapStateManager>().searchThisArea())),
          if (state.selectedEvent != null)
            PositionedDirectional(
              top: desktop ? 210 : 245,
              start: 20,
              end: 20,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: _MarkerPreview(
                    event: state.selectedEvent!,
                    onOpen: () =>
                        context.push('/events/${state.selectedEvent!.id}')),
              )),
            ),
          PositionedDirectional(
            end: 18,
            bottom: desktop ? 320 : 152,
            child: FloatingActionButton.small(
              heroTag: 'center-map',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: () =>
                  context.read<MapStateManager>().refreshUserLocation(),
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          desktop
              ? _DesktopResults(
                  state: state,
                  cards: _cards,
                  onSelected: _select,
                  onOpen: _open,
                  onBrowseAll: () => context.go('/'),
                  onExploreOnline: () => context
                      .read<MapStateManager>()
                      .updateFilters(
                          state.filters.copyWith(eventType: 'online')))
              : _MobileResults(
                  state: state,
                  cards: _cards,
                  onSelected: _select,
                  onOpen: _open,
                  onBrowseAll: () => context.go('/'),
                  onExploreOnline: () => context
                      .read<MapStateManager>()
                      .updateFilters(
                          state.filters.copyWith(eventType: 'online'))),
        ]),
      ),
    );
  }

  void _onClusterTap(MapClusterNode cluster, MapState state) {
    if (cluster.isCluster) {
      _mapController.move(cluster.center, (state.zoom + 1.5).clamp(3, 18));
      return;
    }
    _select(cluster.singleEvent!);
  }

  void _select(MapEvent event) =>
      context.read<MapStateManager>().onMarkerTapped(event);
  void _open(MapEvent event) => context.push('/events/${event.id}');

  void _showFilters(MapState state) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MapFilterSheet(
            initial: state.filters,
            categories: state.categories,
            onApply: (next) {
              Navigator.pop(context);
              context.read<MapStateManager>().updateFilters(next);
            }),
      );
}

class _MapSearchControls extends StatelessWidget {
  const _MapSearchControls(
      {required this.controller,
      required this.filters,
      required this.locating,
      required this.onSearch,
      required this.onFilters,
      required this.onLocation,
      required this.onQuickFilter});
  final TextEditingController controller;
  final MapFilters filters;
  final bool locating;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilters;
  final VoidCallback onLocation;
  final ValueChanged<MapFilters> onQuickFilter;
  @override
  Widget build(BuildContext context) => PositionedDirectional(
        top: MediaQuery.paddingOf(context).top + 12,
        start: 16,
        end: 16,
        child: Column(children: [
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Material(
                color: Colors.white,
                elevation: 7,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(24),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search events or places',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: TextButton.icon(
                        onPressed: onFilters,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Filters')),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: InputBorder.none,
                  ),
                ),
              )),
          const SizedBox(height: 10),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _QuickChip(
                    label: 'Today',
                    icon: Icons.today_outlined,
                    active: filters.when == 'today',
                    onTap: () => onQuickFilter(filters.copyWith(
                        when: filters.when == 'today' ? 'any' : 'today'))),
                _QuickChip(
                    label: 'This weekend',
                    icon: Icons.weekend_outlined,
                    active: filters.when == 'weekend',
                    onTap: () => onQuickFilter(filters.copyWith(
                        when: filters.when == 'weekend' ? 'any' : 'weekend'))),
                _QuickChip(
                    label: 'Near me',
                    icon: Icons.near_me_outlined,
                    active: false,
                    onTap: onLocation),
                _QuickChip(
                    label: 'Free',
                    icon: Icons.sell_outlined,
                    active: filters.freeOnly,
                    onTap: () => onQuickFilter(
                        filters.copyWith(freeOnly: !filters.freeOnly))),
                _QuickChip(
                    label: 'Online',
                    icon: Icons.videocam_outlined,
                    active: filters.eventType == 'online',
                    onTap: () => onQuickFilter(filters.copyWith(
                        eventType:
                            filters.eventType == 'online' ? 'all' : 'online'))),
              ])),
        ]),
      );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(99),
        elevation: 3,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon,
                      size: 17,
                      color: active ? Colors.white : AppColors.primary),
                  const SizedBox(width: 7),
                  Text(label,
                      style: TextStyle(
                          color: active ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13))
                ]))),
      ));
}

class _DesktopResults extends StatelessWidget {
  const _DesktopResults(
      {required this.state,
      required this.cards,
      required this.onSelected,
      required this.onOpen,
      required this.onBrowseAll,
      required this.onExploreOnline});
  final MapState state;
  final PageController cards;
  final ValueChanged<MapEvent> onSelected;
  final ValueChanged<MapEvent> onOpen;
  final VoidCallback onBrowseAll;
  final VoidCallback onExploreOnline;
  @override
  Widget build(BuildContext context) => Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: _ResultsPanel(
          state: state,
          cards: cards,
          onSelected: onSelected,
          onOpen: onOpen,
          onBrowseAll: onBrowseAll,
          onExploreOnline: onExploreOnline,
          desktop: true));
}

class _MobileResults extends StatelessWidget {
  const _MobileResults(
      {required this.state,
      required this.cards,
      required this.onSelected,
      required this.onOpen,
      required this.onBrowseAll,
      required this.onExploreOnline});
  final MapState state;
  final PageController cards;
  final ValueChanged<MapEvent> onSelected;
  final ValueChanged<MapEvent> onOpen;
  final VoidCallback onBrowseAll;
  final VoidCallback onExploreOnline;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: .20,
        minChildSize: .14,
        maxChildSize: .78,
        snap: true,
        snapSizes: const [.20, .48, .78],
        builder: (_, scroll) => _ResultsPanel(
            state: state,
            cards: cards,
            onSelected: onSelected,
            onOpen: onOpen,
            onBrowseAll: onBrowseAll,
            onExploreOnline: onExploreOnline,
            scrollController: scroll),
      );
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel(
      {required this.state,
      required this.cards,
      required this.onSelected,
      required this.onOpen,
      required this.onBrowseAll,
      required this.onExploreOnline,
      this.desktop = false,
      this.scrollController});
  final MapState state;
  final PageController cards;
  final ValueChanged<MapEvent> onSelected;
  final ValueChanged<MapEvent> onOpen;
  final VoidCallback onBrowseAll;
  final VoidCallback onExploreOnline;
  final bool desktop;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      height: desktop ? 270 : null,
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: const Radius.circular(26))
              .copyWith(
                  bottomLeft: desktop ? const Radius.circular(26) : Radius.zero,
                  bottomRight:
                      desktop ? const Radius.circular(26) : Radius.zero),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 28, offset: Offset(0, -4))
          ]),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
            child: Column(children: [
              Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${state.events.length} events in this area',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: onSurface)),
                      const SizedBox(height: 2),
                      const Text('Explore what’s happening nearby',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12))
                    ])),
                TextButton(
                    onPressed: onBrowseAll,
                    child: const Text('View all events'))
              ]),
            ])),
        Expanded(
            child: state.status == MapLoadStatus.success && state.events.isEmpty
                ? _EmptyMapState(onExploreOnline: onExploreOnline)
                : PageView.builder(
                    controller: cards,
                    padEnds: false,
                    itemCount: state.events.length,
                    onPageChanged: (i) => onSelected(state.events[i]),
                    itemBuilder: (_, i) => Padding(
                        padding: EdgeInsetsDirectional.only(
                            start: i == 0 ? 16 : 7,
                            end: i == state.events.length - 1 ? 16 : 7,
                            bottom: 16),
                        child: _MapEventCard(
                            event: state.events[i],
                            selected:
                                state.selectedEvent?.id == state.events[i].id,
                            onTap: () => onOpen(state.events[i]),
                            onSave: () => _savePrompt(context))),
                  )),
      ]),
    );
  }
}

class _MapEventCard extends StatelessWidget {
  const _MapEventCard(
      {required this.event,
      required this.selected,
      required this.onTap,
      required this.onSave});
  final MapEvent event;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2 : 1)),
            child: Row(children: [
              ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(17)),
                  child: SizedBox(
                      width: 116,
                      height: double.infinity,
                      child: _EventImage(event: event))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 13, 8, 11),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: _Pill(
                                      label: _categoryLabel(event.category))),
                              IconButton(
                                  tooltip: 'Save event',
                                  onPressed: onSave,
                                  icon: const Icon(
                                      Icons.bookmark_border_rounded,
                                      size: 20))
                            ]),
                            Text(event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                            const Spacer(),
                            _Meta(
                                icon: Icons.calendar_today_outlined,
                                text: DateFormat('EEE · h:mm a')
                                    .format(event.startsAt)),
                            const SizedBox(height: 4),
                            _Meta(
                                icon: event.isOnline
                                    ? Icons.videocam_outlined
                                    : Icons.location_on_outlined,
                                text: event.locationLabel.isEmpty
                                    ? event.organization
                                    : event.locationLabel),
                            const SizedBox(height: 5),
                            Text(
                                '${event.reservedCount} going${event.priceCents == 0 ? ' · Free' : ''}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ]))),
            ]),
          )));
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.event});
  final MapEvent event;
  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcon(event.category);
    final image = event.imageUrl;
    return image == null || image.isEmpty
        ? DecoratedBox(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFFD7E4), Color(0xFFF99ABC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child: Icon(icon, size: 40, color: AppColors.primaryDark))
        : Image.network(ApiConfig.resolveUrl(image),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFFFE4ED)),
                child: Icon(icon, color: AppColors.primary)));
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)))
      ]);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFFFEEF4),
          borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800)));
}

class _KhairEventMarker extends StatelessWidget {
  const _KhairEventMarker({required this.event, required this.selected});
  final MapEvent event;
  final bool selected;
  @override
  Widget build(BuildContext context) => AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: selected ? 1.18 : 1,
      child: DecoratedBox(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white, width: selected ? 4 : 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: .36),
                    blurRadius: selected ? 16 : 9)
              ]),
          child: Center(
              child: Icon(_categoryIcon(event.category),
                  color: Colors.white, size: 23))));
}

class _KhairClusterMarker extends StatelessWidget {
  const _KhairClusterMarker({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: .22),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: .35), width: 6)),
      child: Center(
          child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)))));
}

class _MarkerPreview extends StatelessWidget {
  const _MarkerPreview({required this.event, required this.onOpen});
  final MapEvent event;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_categoryIcon(event.category), color: AppColors.primary),
                const SizedBox(width: 9),
                Flexible(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(DateFormat('EEE · h:mm a').format(event.startsAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))
                    ])),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded)
              ]))));
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      elevation: 5,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(text,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))
          ])));
}

class _NoticePill extends StatelessWidget {
  const _NoticePill({required this.text, this.retry});
  final String text;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFFFFF8FA),
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 9),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textPrimary))),
            if (retry != null)
              TextButton(onPressed: retry, child: const Text('Retry'))
          ])));
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.onExploreOnline});

  final VoidCallback onExploreOnline;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.explore_off_outlined,
            color: AppColors.primary, size: 36),
        const SizedBox(height: 6),
        Text('Nothing happening here yet',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text('Move the map or explore a wider area.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .68))),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: onExploreOnline,
            child: const Text('Explore online events'))
      ])));
}

class _MapFilterSheet extends StatefulWidget {
  const _MapFilterSheet(
      {required this.initial, required this.categories, required this.onApply});
  final MapFilters initial;
  final List<MapCategory> categories;
  final ValueChanged<MapFilters> onApply;
  @override
  State<_MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<_MapFilterSheet> {
  late MapFilters filters;
  @override
  void initState() {
    super.initState();
    filters = widget.initial;
  }

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
            child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 18),
        const Text('Filters',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        _FilterSection(
            title: 'Distance',
            child: _ChoiceRow(
                options: const ['5 km', '10 km', '25 km', '50 km'],
                selected: '${filters.radiusKm.toInt()} km',
                onSelected: (v) => setState(() => filters = filters.copyWith(
                    radiusKm: double.parse(v.split(' ').first))))),
        _FilterSection(
            title: 'When',
            child: _ChoiceRow(
                options: const [
                  'Any date',
                  'Today',
                  'Tomorrow',
                  'This weekend'
                ],
                selected: {
                  'any': 'Any date',
                  'today': 'Today',
                  'tomorrow': 'Tomorrow',
                  'weekend': 'This weekend'
                }[filters.when]!,
                onSelected: (v) => setState(() => filters = filters.copyWith(
                        when: {
                      'Any date': 'any',
                      'Today': 'today',
                      'Tomorrow': 'tomorrow',
                      'This weekend': 'weekend'
                    }[v]!)))),
        _FilterSection(
            title: 'Type',
            child: _ChoiceRow(
                options: const ['All', 'In-person', 'Online'],
                selected: {
                  'all': 'All',
                  'in_person': 'In-person',
                  'online': 'Online'
                }[filters.eventType]!,
                onSelected: (v) => setState(() => filters = filters.copyWith(
                        eventType: {
                      'All': 'all',
                      'In-person': 'in_person',
                      'Online': 'online'
                    }[v]!)))),
        _FilterSection(
            title: 'Categories',
            child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((category) {
                  final selected = filters.categories.contains(category.slug);
                  return FilterChip(
                      label: Text(category.displayName),
                      selected: selected,
                      selectedColor: const Color(0xFFFFD7E4),
                      checkmarkColor: AppColors.primary,
                      onSelected: (value) {
                        final next = Set<String>.from(filters.categories);
                        value
                            ? next.add(category.slug)
                            : next.remove(category.slug);
                        setState(
                            () => filters = filters.copyWith(categories: next));
                      });
                }).toList())),
        SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Free only',
                style: TextStyle(fontWeight: FontWeight.w700)),
            value: filters.freeOnly,
            activeTrackColor: AppColors.primary,
            onChanged: (v) =>
                setState(() => filters = filters.copyWith(freeOnly: v))),
        const SizedBox(height: 12),
        Row(children: [
          TextButton(
              onPressed: () => setState(() => filters = const MapFilters()),
              child: const Text('Clear all')),
          const Spacer(),
          Expanded(
              child: FilledButton(
                  onPressed: () => widget.onApply(filters),
                  child: const Text('Show events')))
        ])
      ])));
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        child
      ]));
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow(
      {required this.options,
      required this.selected,
      required this.onSelected});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((option) => ChoiceChip(
              label: Text(option),
              selected: option == selected,
              selectedColor: const Color(0xFFFFD7E4),
              labelStyle: TextStyle(
                  color: option == selected
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700),
              onSelected: (_) => onSelected(option)))
          .toList());
}

void _savePrompt(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in to save events and keep them in sync.')));
IconData _categoryIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('technology') || value.contains('hackathon')) {
    return Icons.memory_rounded;
  }
  if (value.contains('charity')) return Icons.volunteer_activism_outlined;
  if (value.contains('family')) return Icons.family_restroom_outlined;
  if (value.contains('knowledge') || value.contains('workshop')) {
    return Icons.lightbulb_outline_rounded;
  }
  if (value.contains('online')) return Icons.videocam_outlined;
  return Icons.groups_2_outlined;
}

String _categoryLabel(String value) => value
    .trim()
    .split(RegExp(r'[_\s-]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
