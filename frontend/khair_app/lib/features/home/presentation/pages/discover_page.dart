import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

import '../../../../tokens/tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../widgets/discover/active_filter_chips.dart';
import '../widgets/discover/compact_event_card.dart';
import '../widgets/discover/discover_filters_sheet.dart';
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
  bool _nearbyRequestInFlight = false;

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

  /// Count filters that are NOT the search query (for the badge).
  int _countActiveFilters(EventFilter filter) {
    int count = 0;
    if (filter.dateFilter != null) count++;
    if (filter.onlineOnly) count++;
    if (filter.freeOnly) count++;
    if (filter.pricingType != null && !filter.freeOnly) count++;
    if (filter.category?.isNotEmpty ?? false) count++;
    if (filter.city?.isNotEmpty ?? false) count++;
    if (filter.country?.isNotEmpty ?? false) count++;
    if (filter.eventType?.isNotEmpty ?? false) count++;
    return count;
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
          final bloc = context.read<EventsBloc>();
          if (_nearbyRequestInFlight &&
              location.location.latitude != null &&
              location.location.longitude != null) {
            bloc.add(UpdateFilter(bloc.state.filter.copyWith(
              latitude: location.location.latitude,
              longitude: location.location.longitude,
              radiusKm: 10,
              timezone: location.location.timezone,
              clearCity: true,
              clearCountry: true,
            )));
          } else {
            bloc.add(UpdateLocation(location.location));
          }
          _nearbyRequestInFlight = false;
        } else if (location is LocationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.locationUpdateError)),
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
                            final name = '';
                            final l10n = AppLocalizations.of(context)!;
                            final greeting = name.isNotEmpty
                                ? '${_timeGreeting(l10n)}, $name \uD83D\uDC4B'
                                : '${_timeGreeting(l10n)} \uD83D\uDC4B';
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
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Poppins',
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                ),
                                children: [
                                  TextSpan(text: '${l10n.discoverHeadlinePre}\n'),
                                  TextSpan(
                                    text: l10n.discoverHeadlineHighlight,
                                    style: const TextStyle(color: AppColors.primary),
                                  ),
                                  TextSpan(text: l10n.discoverHeadlinePost),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Search bar with active-filter badge
                        BlocBuilder<EventsBloc, EventsState>(
                          buildWhen: (prev, curr) => prev.filter != curr.filter,
                          builder: (context, state) => DiscoverSearchBar(
                            controller: _search,
                            onSearch: _searchEvents,
                            onOpenFilters: _openFilters,
                            activeFilterCount: _countActiveFilters(state.filter),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Active filter chips row (only shown when filters are set)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: ActiveFilterChips(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
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
                    final featured = state.events;
                    // Weekend results are already constrained by the server.
                    final weekend = state.filter.dateFilter == DateFilter.thisWeekend
                        ? state.events.take(6).toList()
                        : const <Event>[];

                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DiscoverSectionHeader(
                              title: isSearching
                                  ? AppLocalizations.of(context)!.resultsForQuery(searchQuery!)
                                  : AppLocalizations.of(context)!.featuredNearYou,
                              subtitle: isSearching
                                  ? AppLocalizations.of(context)!.matchingEvents
                                  : AppLocalizations.of(context)!.eventsWorthTimeFor,
                              action: isSearching
                                  ? AppLocalizations.of(context)!.exploreMap
                                  : AppLocalizations.of(context)!.seeAll,
                              onAction: () => context.go('/map'),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 420,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: featured.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, index) =>
                                  FeaturedEventCard(event: featured[index]),
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
                                title: AppLocalizations.of(context)!.happeningThisWeekend,
                                subtitle: AppLocalizations.of(context)!.planSomethingMeaningful,
                                action: AppLocalizations.of(context)!.seeAll,
                                onAction: () => context.go('/map'),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 280,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: weekend.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (context, index) =>
                                    CompactEventCard(event: weekend[index]),
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

  String _timeGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.greetingGoodMorning;
    if (hour < 18) return l10n.greetingGoodAfternoon;
    return l10n.greetingGoodEvening;
  }

  Future<void> _refresh() async {
    context.read<EventsBloc>().add(LoadEvents());
  }

  void _searchEvents(String value) {
    context.read<EventsBloc>().add(UpdateSearchQuery(value));
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<EventsBloc>(),
        child: const DiscoverFiltersSheet(),
      ),
    );
  }

  void _toggleQuickFilter(QuickFilter quickFilter) {
    final bloc = context.read<EventsBloc>();
    final filter = bloc.state.filter;
    switch (quickFilter) {
      case QuickFilter.today:
        bloc.add(UpdateDateFilter(
            filter.dateFilter == DateFilter.today ? null : DateFilter.today));
      case QuickFilter.weekend:
        bloc.add(UpdateDateFilter(filter.dateFilter == DateFilter.thisWeekend
            ? null
            : DateFilter.thisWeekend));
      case QuickFilter.nearby:
        setState(() {
          _locationRequestInFlight = true;
          _nearbyRequestInFlight = true;
        });
        context.read<LocationBloc>().add(ResolveLocationEvent());
      case QuickFilter.free:
        final selected = filter.freeOnly || filter.pricingType == 'free';
        bloc.add(UpdateFilter(filter.copyWith(
          freeOnly: !selected,
          pricingType: selected ? null : 'free',
          clearPricingType: selected,
        )));
      case QuickFilter.online:
        bloc.add(UpdateFilter(filter.copyWith(onlineOnly: !filter.onlineOnly)));
    }
  }

  Future<void> _openLocationPicker() async {
    final controller =
        TextEditingController(text: context.read<EventsBloc>().state.filter.city ?? '');
    final sheetL10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          // Shift content up when keyboard is visible
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(sheetL10n.chooseYourArea,
                        style:
                            const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 16),
                  // Use InkWell + Row instead of ListTile to avoid invisible ink warning
                  InkWell(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      setState(() => _locationRequestInFlight = true);
                      context.read<LocationBloc>().add(ResolveLocationEvent());
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(sheetL10n.useCurrentLocationShort,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      context.read<EventsBloc>().add(UpdateBaseCity(value.trim()));
                      Navigator.of(sheetContext).pop();
                    },
                    decoration: InputDecoration(
                      labelText: sheetL10n.city,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        context
                            .read<EventsBloc>()
                            .add(UpdateBaseCity(controller.text.trim()));
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(sheetL10n.showEvents),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
    },
    );
    controller.dispose();
  }
}


class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery(
      {required this.onClearFilters, this.hasActiveFilters = false});
  final VoidCallback onClearFilters;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.explore_off_outlined,
                color: AppColors.primary, size: 44),
            const SizedBox(height: 14),
            Text(l10n.noEventsFound,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l10n.adjustFiltersHint,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            if (hasActiveFilters)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.close_rounded),
                label: Text(l10n.clearFilters),
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(l10n.loadEventsError),
            TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
          ],
        ),
      ),
    );
  }
}
