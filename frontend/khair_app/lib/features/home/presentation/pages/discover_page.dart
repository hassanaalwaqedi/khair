import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../tokens/tokens.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../events/domain/entities/event.dart';
import '../../../../events/presentation/bloc/events_bloc.dart';
import '../../../../location/presentation/bloc/location_bloc.dart';
import '../widgets/discover/compact_event_card.dart';
import '../widgets/discover/discover_header.dart';
import '../widgets/discover/discover_search_bar.dart';
import '../widgets/discover/discover_section_header.dart';
import '../widgets/discover/featured_event_card.dart';
import '../widgets/discover/free_events_promo.dart';
import '../widgets/discover/quick_filters_row.dart';
import '../widgets/discover/skeleton_loaders.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _search = TextEditingController();
  bool _locationRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate search if already in bloc state
    _search.text = context.read<EventsBloc>().state.filter.searchQuery ?? '';
    context.read<EventsBloc>().add(LoadEvents());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listenWhen: (_, current) =>
          _locationRequestInFlight &&
          (current is LocationLoaded || current is LocationError),
      listener: (context, location) {
        setState(() => _locationRequestInFlight = false);
        if (location is LocationLoaded) {
          final filter = context.read<EventsBloc>().state.filter;
          context.read<EventsBloc>().add(
                UpdateFilter(filter.copyWith(city: location.location.city)),
              );
        } else if (location is LocationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('We could not update your location.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: DiscoverHeader(onLocation: _openLocationPicker),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, auth) {
                            final name = auth.user?.firstName ?? '';
                            final greeting = name.isNotEmpty
                                ? '${_timeGreeting()}, $name \uD83D\uDC4B'
                                : '${_timeGreeting()} \uD83D\uDC4B';
                            return Text(
                              greeting,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'Poppins',
                              height: 1.15,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(text: 'Find events that\n'),
                              TextSpan(
                                text: 'inspire',
                                style: TextStyle(color: AppColors.primary),
                              ),
                              TextSpan(text: ' you'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        DiscoverSearchBar(
                          controller: _search,
                          onSearch: _searchEvents,
                          onOpenFilters: _openFilters,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: QuickFiltersRow(onTap: _toggleQuickFilter),
                  ),
                ),
                BlocBuilder<EventsBloc, EventsState>(
                  builder: (context, state) {
                    if (state.status == EventsStatus.loading && state.events.isEmpty) {
                      return const SliverToBoxAdapter(child: SkeletonLoaders());
                    }
                    if (state.status == EventsStatus.failure) {
                      return SliverToBoxAdapter(child: _LoadError(onRetry: _refresh));
                    }
                    if (state.events.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptyDiscovery(
                          onClearFilters: () => context.read<EventsBloc>().add(ClearAllFilters()),
                          hasActiveFilters: state.filter.hasActiveFilters,
                        ),
                      );
                    }

                    final searchQuery = state.filter.searchQuery?.trim();
                    final isSearching = searchQuery?.isNotEmpty ?? false;
                    final featured = state.events.take(5).toList();
                    final weekend = state.events.where(_isThisWeekend).take(6).toList();
                    
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DiscoverSectionHeader(
                              title: isSearching ? 'Results for “$searchQuery”' : 'Featured near you',
                              subtitle: isSearching ? 'Matching events' : 'Events worth making time for',
                              action: isSearching ? 'Explore map' : 'See all',
                              onAction: () => context.go('/map'),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 320,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: featured.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, index) => FeaturedEventCard(event: featured[index]),
                            ),
                          ),
                        ),
                        if (!isSearching)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: FreeEventsPromo(),
                            ),
                          ),
                        if (!isSearching && weekend.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: DiscoverSectionHeader(
                                title: 'Happening this weekend',
                                subtitle: 'Plan something meaningful',
                                action: 'See all',
                                onAction: () => context.go('/map'),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 250,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: weekend.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (context, index) => CompactEventCard(event: weekend[index]),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 80 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  bool _isThisWeekend(Event event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = now.weekday == DateTime.sunday
        ? today.subtract(const Duration(days: 1))
        : today.add(Duration(days: (DateTime.saturday - now.weekday + 7) % 7));
    final end = start.add(const Duration(days: 2));
    return !event.startDate.isBefore(start) && event.startDate.isBefore(end);
  }

  Future<void> _refresh() async {
    context.read<EventsBloc>().add(LoadEvents());
  }

  void _searchEvents(String value) {
    context.read<EventsBloc>().add(UpdateSearchQuery(value.trim()));
  }

  void _openFilters() {
    // Ideally this opens the same modal as before, we can leave a snackbar for now or replicate the existing logic
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filters coming soon in Style 2')));
  }

  void _toggleQuickFilter(QuickFilter quickFilter) {
    final bloc = context.read<EventsBloc>();
    final filter = bloc.state.filter;
    switch (quickFilter) {
      case QuickFilter.today:
        bloc.add(UpdateDateFilter(filter.dateFilter == DateFilter.today ? null : DateFilter.today));
      case QuickFilter.weekend:
        bloc.add(UpdateDateFilter(filter.dateFilter == DateFilter.thisWeekend ? null : DateFilter.thisWeekend));
      case QuickFilter.nearby:
        setState(() => _locationRequestInFlight = true);
        context.read<LocationBloc>().add(ResolveLocationEvent());
      case QuickFilter.free:
        bloc.add(UpdateFilter(filter.copyWith(freeOnly: !filter.freeOnly)));
      case QuickFilter.online:
        bloc.add(UpdateFilter(filter.copyWith(onlineOnly: !filter.onlineOnly)));
    }
  }

  Future<void> _openLocationPicker() async {
    final controller = TextEditingController(text: context.read<EventsBloc>().state.filter.city ?? '');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Choose your area', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                title: const Text('Use current location'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _locationRequestInFlight = true);
                  context.read<LocationBloc>().add(ResolveLocationEvent());
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  context.read<EventsBloc>().add(UpdateBaseCity(value.trim()));
                  Navigator.of(sheetContext).pop();
                },
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.read<EventsBloc>().add(UpdateBaseCity(controller.text.trim()));
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Show events'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }
}

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery({required this.onClearFilters, this.hasActiveFilters = false});
  final VoidCallback onClearFilters;
  final bool hasActiveFilters;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.explore_off_outlined, color: AppColors.primary, size: 44),
            const SizedBox(height: 14),
            const Text('No events found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Try adjusting your filters or area.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            if (hasActiveFilters)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Clear filters'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('We couldn’t load events right now.'),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
