import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../../../tokens/tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../widgets/discovery_event_card.dart';

/// Khair's event-first discovery homepage. It intentionally contains no
/// lesson, teacher, student, or generic marketing surfaces.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _search = TextEditingController();
  String? _activeCategory;
  bool _locationRequestInFlight = false;
  late Future<List<_Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
    context.read<EventsBloc>().add(LoadEvents());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.isMobile(context);
    final bottomSpace =
        mobile ? 66 + 10 + MediaQuery.paddingOf(context).bottom + 28 : 48.0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final categorySection = SliverToBoxAdapter(
      child: FutureBuilder<List<_Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) => _CategorySection(
          active: _activeCategory,
          categories: snapshot.data ?? const <_Category>[],
          loading: snapshot.connectionState == ConnectionState.waiting,
          failed: snapshot.hasError,
          onRetry: _reloadCategories,
          onCategory: _selectCategory,
        ),
      ),
    );

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
        backgroundColor: dark ? AppColors.darkBackground : AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _AdaptiveHeader(onLocation: _openLocationPicker),
              ),
              if (mobile)
                SliverToBoxAdapter(
                  child: _MobileDiscoveryLead(
                    search: _search,
                    onSearch: _searchEvents,
                    onQuickFilter: _toggleQuickFilter,
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: _Hero(
                    search: _search,
                    onSearch: _searchEvents,
                    onCreate: _openCreate,
                  ),
                ),
              if (mobile)
                BlocBuilder<EventsBloc, EventsState>(
                  builder: (context, state) => _EventSections(
                    state: state,
                    mobile: true,
                    afterFeaturedSlivers: [categorySection],
                    onExploreAll: () => context.go('/map'),
                    onRetry: () => context.read<EventsBloc>().add(LoadEvents()),
                    onClearSearch: _clearSearch,
                    onClearFilters: () =>
                        context.read<EventsBloc>().add(ClearAllFilters()),
                  ),
                )
              else ...[
                categorySection,
                BlocBuilder<EventsBloc, EventsState>(
                  builder: (context, state) => _EventSections(
                    state: state,
                    onExploreAll: () => context.go('/map'),
                    onRetry: () => context.read<EventsBloc>().add(LoadEvents()),
                    onClearSearch: _clearSearch,
                    onClearFilters: () =>
                        context.read<EventsBloc>().add(ClearAllFilters()),
                  ),
                ),
                const SliverToBoxAdapter(child: _WhyKhair()),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: bottomSpace),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final events = context.read<EventsBloc>().state.events;
    final eventCities = events
        .map((event) => event.city?.trim() ?? '')
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final controller = TextEditingController(
      text: context.read<EventsBloc>().state.filter.city ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('Choose your area',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('Use your location or search a city.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location_rounded,
                  color: AppColors.primary),
              title: const Text('Use current location'),
              subtitle: const Text('Khair only asks when you choose this.'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _requestCurrentLocation();
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                _applyCity(value);
                Navigator.of(sheetContext).pop();
              },
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            if (eventCities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Cities with events',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: eventCities
                      .take(8)
                      .map((city) => OutlinedButton(
                            onPressed: () {
                              _applyCity(city);
                              Navigator.of(sheetContext).pop();
                            },
                            child: Text(city),
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _applyCity(controller.text);
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Show events'),
              ),
            ),
          ]),
        ),
      ),
    );
    controller.dispose();
  }

  void _requestCurrentLocation() {
    setState(() => _locationRequestInFlight = true);
    context.read<LocationBloc>().add(ResolveLocationEvent());
  }

  void _applyCity(String value) {
    final city = value.trim();
    final filter = context.read<EventsBloc>().state.filter;
    context.read<EventsBloc>().add(UpdateFilter(
          filter.copyWith(city: city, clearCity: city.isEmpty),
        ));
  }

  void _toggleQuickFilter(_QuickFilter quickFilter) {
    final bloc = context.read<EventsBloc>();
    final filter = bloc.state.filter;
    switch (quickFilter) {
      case _QuickFilter.today:
        bloc.add(UpdateDateFilter(
            filter.dateFilter == DateFilter.today ? null : DateFilter.today));
      case _QuickFilter.weekend:
        bloc.add(UpdateDateFilter(filter.dateFilter == DateFilter.thisWeekend
            ? null
            : DateFilter.thisWeekend));
      case _QuickFilter.nearby:
        _requestCurrentLocation();
      case _QuickFilter.free:
        bloc.add(UpdateFilter(filter.copyWith(freeOnly: !filter.freeOnly)));
      case _QuickFilter.online:
        bloc.add(UpdateFilter(filter.copyWith(onlineOnly: !filter.onlineOnly)));
    }
  }

  void _searchEvents(String value) {
    context.read<EventsBloc>().add(UpdateSearchQuery(value.trim()));
  }

  void _clearSearch() {
    _search.clear();
    _searchEvents('');
  }

  Future<List<_Category>> _loadCategories() async {
    final response = await getIt<ApiClient>().get('/discover/categories');
    final payload = response.data;
    final entries = payload is Map<String, dynamic>
        ? (payload['data'] as List? ?? const [])
        : const [];

    final categories = entries
        .whereType<Map>()
        .map((entry) => _Category.fromJson(Map<String, dynamic>.from(entry)))
        .where((category) => category.slug.isNotEmpty)
        .toList();

    // Put categories with live events first in the compact rail. The complete
    // picker keeps the canonical database order.
    categories.sort((a, b) {
      final byAvailability = b.count.compareTo(a.count);
      return byAvailability != 0
          ? byAvailability
          : a.sortOrder.compareTo(b.sortOrder);
    });
    return categories;
  }

  Future<void> _reloadCategories() async {
    setState(() => _categoriesFuture = _loadCategories());
    await _categoriesFuture;
  }

  Future<void> _refresh() async {
    context.read<EventsBloc>().add(LoadEvents());
    await _reloadCategories();
  }

  void _selectCategory(_Category category) {
    final next = _activeCategory == category.slug ? null : category.slug;
    setState(() => _activeCategory = next);
    context.read<EventsBloc>().add(UpdateCategoryFilter(next));
  }

  void _openCreate() {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) {
      context.go('/login?next=${Uri.encodeComponent('/create-event')}');
    } else if (auth.isApprovedOrganizer) {
      context.go('/organizer/events/create');
    } else {
      context.go('/organizer/apply');
    }
  }
}

enum _QuickFilter { today, weekend, nearby, free, online }

class _AdaptiveHeader extends StatelessWidget {
  const _AdaptiveHeader({required this.onLocation});
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isDesktop(context)) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 2),
        child: Row(children: [
          const KhairBrand(
            size: 27,
            gap: 7,
            nameStyle: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _LocationButton(onPressed: onLocation)),
          const SizedBox(width: 4),
          if (auth.isAuthenticated)
            IconButton(
              tooltip: 'Profile',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.account_circle_outlined),
            )
          else
            TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Sign in'),
            ),
        ]),
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BlocBuilder<EventsBloc, EventsState>(
        builder: (context, events) {
          final selectedCity = events.filter.city?.trim();
          return BlocBuilder<LocationBloc, LocationState>(
            builder: (context, location) {
              final cachedCity = location is LocationLoaded
                  ? location.location.city.trim()
                  : '';
              final city =
                  selectedCity?.isNotEmpty == true ? selectedCity! : cachedCity;
              return TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.location_on_outlined, size: 17),
                label: Flexible(
                  child: Text(
                    city.isEmpty ? 'Choose area' : city,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsetsDirectional.only(start: 7, end: 5),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            },
          );
        },
      );
}

class _MobileDiscoveryLead extends StatelessWidget {
  const _MobileDiscoveryLead({
    required this.search,
    required this.onSearch,
    required this.onQuickFilter,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final ValueChanged<_QuickFilter> onQuickFilter;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 4),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.isAuthenticated ? _timeGreeting() : 'Find something to do',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                auth.isAuthenticated
                    ? 'What are you up for?'
                    : 'Discover events near you.',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.12,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _EventSearchField(
                controller: search,
                onSearch: onSearch,
                showNearMe: false,
              ),
              const SizedBox(height: 12),
              _QuickFilterRow(onTap: onQuickFilter),
            ],
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

class _QuickFilterRow extends StatelessWidget {
  const _QuickFilterRow({required this.onTap});
  final ValueChanged<_QuickFilter> onTap;

  @override
  Widget build(BuildContext context) => BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) => SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _QuickFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _QuickFilter.values[index];
              return _QuickFilterChip(
                filter: filter,
                selected: switch (filter) {
                  _QuickFilter.today =>
                    state.filter.dateFilter == DateFilter.today,
                  _QuickFilter.weekend =>
                    state.filter.dateFilter == DateFilter.thisWeekend,
                  _QuickFilter.nearby => false,
                  _QuickFilter.free => state.filter.freeOnly,
                  _QuickFilter.online => state.filter.onlineOnly,
                },
                onTap: () => onTap(filter),
              );
            },
          ),
        ),
      );
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip(
      {required this.filter, required this.selected, required this.onTap});
  final _QuickFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (filter) {
      _QuickFilter.today => ('Today', Icons.calendar_today_outlined),
      _QuickFilter.weekend => ('This weekend', Icons.weekend_outlined),
      _QuickFilter.nearby => ('Near me', Icons.near_me_outlined),
      _QuickFilter.free => ('Free', Icons.sell_outlined),
      _QuickFilter.online => ('Online', Icons.videocam_outlined),
    };
    return Material(
      color: selected ? const Color(0xFFFFEAF1) : AppColors.surface,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsetsDirectional.fromSTEB(13, 0, 14, 0),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 17,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                  color:
                      selected ? AppColors.primaryDark : AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(
      {required this.search, required this.onSearch, required this.onCreate});
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.isMobile(context);
    final tablet = AppBreakpoints.isTablet(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary =
        dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Container(
      margin: EdgeInsets.fromLTRB(
          mobile ? 16 : 32, mobile ? 18 : 32, mobile ? 16 : 32, 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: LayoutBuilder(builder: (context, constraints) {
          final stack = constraints.maxWidth < 860;
          return Container(
            padding: EdgeInsets.all(tablet ? 28 : 36),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : const Color(0xFFFFFCFD),
              borderRadius: BorderRadius.circular(mobile ? 24 : 32),
              border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Stack(children: [
              PositionedDirectional(
                  top: -84,
                  end: -60,
                  child: _BlushOrb(size: mobile ? 170 : 280)),
              if (!stack)
                PositionedDirectional(
                    bottom: -104,
                    start: -82,
                    child: _BlushOrb(size: 240, opacity: .45)),
              Flex(
                  direction: stack ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stack)
                      _HeroCopy(
                          search: search,
                          onSearch: onSearch,
                          onCreate: onCreate,
                          primary: primary,
                          secondary: secondary)
                    else
                      Expanded(
                          flex: 52,
                          child: _HeroCopy(
                              search: search,
                              onSearch: onSearch,
                              onCreate: onCreate,
                              primary: primary,
                              secondary: secondary)),
                    if (!stack) const SizedBox(width: 38),
                    if (!stack) const Expanded(flex: 48, child: _HeroCollage()),
                    if (stack && !tablet) ...[
                      const SizedBox(height: 24),
                      const _MobileHeroVisual()
                    ],
                  ]),
            ]),
          );
        }),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy(
      {required this.search,
      required this.onSearch,
      required this.onCreate,
      required this.primary,
      required this.secondary});
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;
  final Color primary;
  final Color secondary;
  @override
  Widget build(BuildContext context) {
    final compact =
        AppBreakpoints.isMobile(context) || AppBreakpoints.isTablet(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _HeroPill(),
      const SizedBox(height: 18),
      Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Discover events that '),
            TextSpan(
                text: 'bring people together.',
                style: TextStyle(color: AppColors.primary)),
          ]),
          style: TextStyle(
              color: primary,
              fontSize: compact ? 42 : 56,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? -1.1 : -1.8)),
      const SizedBox(height: 16),
      ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: Text(
              'Find community gatherings, workshops, charity events, talks, and online experiences happening around you.',
              style: TextStyle(
                  color: secondary,
                  fontSize: compact ? 15 : 17,
                  height: 1.55))),
      const SizedBox(height: 24),
      _EventSearchField(controller: search, onSearch: onSearch),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(
            onPressed: () => onSearch(search.text),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explore events'),
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 19))),
        OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create an event'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 17))),
      ]),
    ]);
  }
}

class _HeroPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(11, 7, 12, 7),
        decoration: BoxDecoration(
            color: const Color(0xFFFFEEF4),
            borderRadius: BorderRadius.circular(99)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 15),
          SizedBox(width: 6),
          Text('Events worth showing up for',
              style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800))
        ]),
      );
}

class _EventSearchField extends StatelessWidget {
  const _EventSearchField({
    required this.controller,
    required this.onSearch,
    this.showNearMe = true,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final bool showNearMe;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x17000000),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(18)),
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            onSubmitted: onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search events, topics, or cities',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: showNearMe
                  ? TextButton.icon(
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.near_me_outlined, size: 17),
                      label: const Text('Near me'))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      );
}

class _HeroCollage extends StatelessWidget {
  const _HeroCollage();
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 386,
      child: Stack(children: [
        PositionedDirectional(
            top: 2,
            start: 22,
            end: 0,
            child: _CollagePhoto(
                url:
                    'https://images.unsplash.com/photo-1511632765486-a01980e01a18?auto=format&fit=crop&w=1000&q=80',
                height: 228)),
        PositionedDirectional(
            bottom: 0,
            start: 0,
            child: _CollagePhoto(
                url:
                    'https://images.unsplash.com/photo-1545389336-cf090694435e?auto=format&fit=crop&w=600&q=80',
                width: 202,
                height: 138)),
        PositionedDirectional(
            bottom: 0,
            end: 0,
            child: _CollagePhoto(
                url:
                    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=600&q=80',
                width: 224,
                height: 138)),
        const PositionedDirectional(
            top: 183,
            end: 20,
            child: _MicroCard(
                icon: Icons.local_fire_department_outlined,
                text: 'Trending near you')),
        const PositionedDirectional(
            bottom: 24,
            start: 150,
            child: _MicroCard(icon: Icons.groups_2_outlined, text: '48 going')),
      ]));
}

class _MobileHeroVisual extends StatelessWidget {
  const _MobileHeroVisual();
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 176,
      child: _CollagePhoto(
          url:
              'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=900&q=80',
          height: 176));
}

class _CollagePhoto extends StatelessWidget {
  const _CollagePhoto({required this.url, required this.height, this.width});
  final String url;
  final double height;
  final double? width;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              width: width, height: height, color: const Color(0xFFFFDDE8))));
}

class _MicroCard extends StatelessWidget {
  const _MicroCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      elevation: 5,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(11, 9, 13, 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(text,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))
          ])));
}

class _BlushOrb extends StatelessWidget {
  const _BlushOrb({required this.size, this.opacity = 1});
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: opacity,
      child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
              color: Color(0xFFFFE6EF), shape: BoxShape.circle)));
}

class _CategorySection extends StatelessWidget {
  const _CategorySection(
      {required this.categories,
      required this.active,
      required this.loading,
      required this.failed,
      required this.onRetry,
      required this.onCategory});
  final List<_Category> categories;
  final String? active;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  final ValueChanged<_Category> onCategory;
  @override
  Widget build(BuildContext context) => _ConstrainedSection(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
              AppBreakpoints.isMobile(context)
                  ? 'Explore by category'
                  : 'Explore categories',
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton(
              onPressed: categories.isEmpty ? null : () => _showAll(context),
              child: Text(AppBreakpoints.isMobile(context)
                  ? 'See all'
                  : 'View all categories'))
        ]),
        const SizedBox(height: 10),
        if (loading)
          const SizedBox(
              height: 48,
              child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))))
        else if (failed)
          Row(children: [
            const Text('Categories could not be loaded.',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ])
        else if (categories.isEmpty)
          const Text('No event categories are available yet.',
              style: TextStyle(color: AppColors.textSecondary))
        else
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: (AppBreakpoints.isMobile(context)
                          ? categories.take(10)
                          : categories)
                      .map((category) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: _CategoryChip(
                              category: category,
                              selected: category.slug == active,
                              onTap: () => onCategory(category))))
                      .toList())),
      ]));

  void _showAll(BuildContext context) {
    final catalog = [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('All categories',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Choose a category from the Khair catalog.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: catalog
                        .map((category) => _CategoryChip(
                              category: category,
                              selected: category.slug == active,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                onCategory(category);
                              },
                            ))
                        .toList(),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.category, required this.selected, required this.onTap});
  final _Category category;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: selected
          ? const Color(0xFFFFEDF3)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border),
                  borderRadius: BorderRadius.circular(15)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(category.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(category.displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary))
              ]))));
}

class _EventSections extends StatelessWidget {
  const _EventSections(
      {required this.state,
      required this.onExploreAll,
      required this.onRetry,
      required this.onClearSearch,
      required this.onClearFilters,
      this.mobile = false,
      this.afterFeaturedSlivers = const []});
  final EventsState state;
  final VoidCallback onExploreAll;
  final VoidCallback onRetry;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;
  final bool mobile;
  final List<Widget> afterFeaturedSlivers;
  @override
  Widget build(BuildContext context) {
    if (state.status == EventsStatus.loading && state.events.isEmpty) {
      return const SliverToBoxAdapter(child: _EventSkeletons());
    }
    if (state.status == EventsStatus.failure) {
      return SliverToBoxAdapter(child: _LoadError(onRetry: onRetry));
    }
    if (state.events.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: _EmptyDiscovery(
              onMap: onExploreAll,
              onClearSearch: onClearSearch,
              onClearFilters: onClearFilters,
              searchQuery: state.filter.searchQuery,
              onlineOnly: state.filter.onlineOnly,
              freeOnly: state.filter.freeOnly,
              hasActiveFilters: state.filter.hasActiveFilters,
            ),
          ),
          ...afterFeaturedSlivers,
        ],
      );
    }
    final searchQuery = state.filter.searchQuery?.trim();
    final isSearching = searchQuery?.isNotEmpty ?? false;
    final featured = state.events.take(5).toList();
    final weekend = state.events.where(_isThisWeekend).take(6).toList();
    final online =
        state.events.where((event) => event.isOnline).take(6).toList();
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
          child: _SectionHeader(
              title: isSearching
                  ? 'Results for “$searchQuery”'
                  : 'Featured near you',
              subtitle: isSearching
                  ? 'Matching titles, topics, categories, and cities'
                  : (mobile ? '' : 'Events worth making time for'),
              action: mobile
                  ? 'See all'
                  : (isSearching ? 'Explore map' : 'View all'),
              onAction: onExploreAll)),
      _ResponsiveGrid(events: featured),
      if (!isSearching) ...afterFeaturedSlivers,
      if (!isSearching && weekend.isNotEmpty) ...[
        SliverToBoxAdapter(
            child: _SectionHeader(
                title: 'Happening this weekend',
                subtitle: 'Plan something meaningful',
                action: 'Explore map',
                onAction: onExploreAll)),
        SliverToBoxAdapter(child: _HorizontalEvents(events: weekend)),
      ],
      if (!isSearching && online.isNotEmpty) ...[
        SliverToBoxAdapter(
            child: _SectionHeader(
                title: 'Online events',
                subtitle: 'Join from wherever you are',
                action: 'View all',
                onAction: onExploreAll)),
        SliverToBoxAdapter(child: _HorizontalEvents(events: online)),
      ],
    ]);
  }
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

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.events});
  final List<Event> events;
  @override
  Widget build(BuildContext context) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      sliver: SliverLayoutBuilder(builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width >= AppBreakpoints.desktop
            ? 5
            : width >= AppBreakpoints.tablet
                ? 4
                : width >= AppBreakpoints.mobile
                    ? 2
                    : 1;
        return SliverGrid(
            delegate: SliverChildBuilderDelegate(
                (context, index) => DiscoveryEventCard(event: events[index]),
                childCount: events.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: width < AppBreakpoints.mobile
                    ? .92
                    : width < AppBreakpoints.tablet
                        ? .86
                        : .82,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16));
      }));
}

class _HorizontalEvents extends StatelessWidget {
  const _HorizontalEvents({required this.events});
  final List<Event> events;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 332,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, index) => SizedBox(
              width: 286,
              child: DiscoveryEventCard(event: events[index], compact: true))));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title,
      required this.subtitle,
      required this.action,
      required this.onAction});
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => _ConstrainedSection(
      child: Padding(
          padding: EdgeInsets.only(
              top: AppBreakpoints.isMobile(context) ? 22 : 28, bottom: 15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: AppBreakpoints.isMobile(context) ? 22 : 27,
                          fontWeight: FontWeight.w800)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ]
                ])),
            TextButton(onPressed: onAction, child: Text(action))
          ])));
}

class _ConstrainedSection extends StatelessWidget {
  const _ConstrainedSection({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: child)));
}

class _EventSkeletons extends StatelessWidget {
  const _EventSkeletons();
  @override
  Widget build(BuildContext context) => _ConstrainedSection(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Featured near you',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, __) => Container(
                    width: 280,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF4EFF2),
                        borderRadius: BorderRadius.circular(20))),
              ),
            ),
          ]),
        ),
      );
}

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery(
      {required this.onMap,
      required this.onClearSearch,
      required this.onClearFilters,
      this.searchQuery,
      this.onlineOnly = false,
      this.freeOnly = false,
      this.hasActiveFilters = false});
  final VoidCallback onMap;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;
  final String? searchQuery;
  final bool onlineOnly;
  final bool freeOnly;
  final bool hasActiveFilters;
  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery?.trim().isNotEmpty ?? false;
    return _ConstrainedSection(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 52),
        child: Center(
            child: Column(children: [
          const Icon(Icons.explore_off_outlined,
              color: AppColors.primary, size: 44),
          const SizedBox(height: 14),
          Text(
              hasSearch
                  ? 'No results for “${searchQuery!.trim()}”'
                  : onlineOnly
                      ? 'No online events yet'
                      : freeOnly
                          ? 'No free events here yet'
                          : 'No events near you yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
              hasSearch
                  ? 'Try a title, topic, category, or city.'
                  : onlineOnly || freeOnly
                      ? 'Try another date or browse all events.'
                      : 'Try another area or discover online events.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, children: [
            if (hasSearch)
              OutlinedButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear search'))
            else if (hasActiveFilters)
              OutlinedButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear filters')),
            FilledButton(
                onPressed: onMap, child: const Text('Explore another city')),
            OutlinedButton(
                onPressed: onMap,
                child: Text(onlineOnly
                    ? 'Explore all events'
                    : 'Browse online events')),
          ]),
        ])),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _ConstrainedSection(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
              child: Column(children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('We couldn’t load events right now.'),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ])),
        ),
      );
}

class _WhyKhair extends StatelessWidget {
  const _WhyKhair();
  @override
  Widget build(BuildContext context) => _ConstrainedSection(
      child: Container(
          margin: const EdgeInsets.only(top: 50),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF1F5),
              borderRadius: BorderRadius.circular(24)),
          child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 20,
              children: const [
                _Benefit(
                    icon: Icons.near_me_outlined,
                    title: 'Find nearby events',
                    body: 'Discover gatherings around you.'),
                _Benefit(
                    icon: Icons.groups_2_outlined,
                    title: 'Join meaningful moments',
                    body: 'Meet people who share your interests.'),
                _Benefit(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Create your own',
                    body: 'Bring your community together.'),
                _Benefit(
                    icon: Icons.notifications_none_rounded,
                    title: 'Stay updated',
                    body: 'Keep track of what matters.')
              ])));
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 245,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 20)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(body,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5, height: 1.35))
        ]))
      ]));
}

class _Category {
  const _Category({
    required this.slug,
    required this.displayName,
    required this.count,
    required this.sortOrder,
  });

  factory _Category.fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] ?? json['name'] ?? '').toString().trim();
    final label = (json['display_name'] ?? '').toString().trim();
    return _Category(
      slug: slug,
      displayName: label.isEmpty ? _titleCase(slug) : label,
      count: (json['count'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 9999,
    );
  }

  final String slug;
  final String displayName;
  final int count;
  final int sortOrder;

  IconData get icon => _categoryIcon(slug);
}

String _titleCase(String value) => value
    .split(RegExp(r'[_\s-]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

IconData _categoryIcon(String slug) {
  switch (slug) {
    case 'community':
    case 'networking':
      return Icons.groups_2_outlined;
    case 'charity':
    case 'volunteering':
      return Icons.volunteer_activism_outlined;
    case 'workshop':
      return Icons.handyman_outlined;
    case 'conference':
    case 'seminar':
    case 'lectures':
    case 'knowledge':
    case 'education':
      return Icons.lightbulb_outline_rounded;
    case 'webinar':
      return Icons.videocam_outlined;
    case 'family':
    case 'parenting':
      return Icons.family_restroom_outlined;
    case 'youth':
      return Icons.auto_awesome_outlined;
    case 'technology':
    case 'hackathon':
      return Icons.memory_outlined;
    case 'quran':
      return Icons.menu_book_outlined;
    case 'sports':
      return Icons.sports_soccer_outlined;
    case 'health':
    case 'wellness':
      return Icons.favorite_outline_rounded;
    case 'arts':
    case 'culture':
    case 'entertainment':
      return Icons.palette_outlined;
    case 'environment':
      return Icons.park_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'travel':
    case 'retreat':
      return Icons.flight_takeoff_outlined;
    case 'business':
    case 'entrepreneurship':
    case 'career':
      return Icons.business_center_outlined;
    case 'festival':
      return Icons.celebration_outlined;
    default:
      return Icons.category_outlined;
  }
}
