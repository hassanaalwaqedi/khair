import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/theme_bloc.dart';
import '../../../../core/utils/emoji_mapper.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../ai/presentation/bloc/ai_bloc.dart';
import '../../../ai/presentation/widgets/recommended_section.dart';
import '../../domain/entities/event.dart';
import '../bloc/events_bloc.dart';
import '../widgets/event_card.dart';
import '../widgets/smart_filter_chips.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<EventsBloc>().add(LoadEvents());
    context.read<AiBloc>().add(const LoadRecommendations());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<EventsBloc>().add(LoadMoreEvents());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, locationState) {
        if (locationState is LocationLoaded) {
          context.read<EventsBloc>().add(
                UpdateLocation(locationState.location),
              );
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildHeader(context),
            _buildSearchBar(context),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SmartFilterChips(),
              ),
            ),
            const SliverToBoxAdapter(
              child: RecommendedSection(),
            ),
            _buildEventsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Discover Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KhairColors.primary,
                KhairColors.primaryLight,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(20),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Theme toggle button
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            final icon = switch (themeState.themeMode) {
              ThemeMode.system => Icons.brightness_auto,
              ThemeMode.light => Icons.light_mode,
              ThemeMode.dark => Icons.dark_mode,
            };
            return IconButton(
              icon: Icon(icon),
              tooltip: 'Toggle theme',
              onPressed: () => context.read<ThemeBloc>().add(const ToggleTheme()),
            );
          },
        ),
        const LanguageSwitcher(showLabel: false),
        IconButton(
          icon: const Icon(Icons.map),
          onPressed: () => context.go('/map'),
        ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search events...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: BlocBuilder<EventsBloc, EventsState>(
              buildWhen: (p, c) => p.filter.searchQuery != c.filter.searchQuery,
              builder: (context, state) {
                if (state.filter.searchQuery != null &&
                    state.filter.searchQuery!.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      context.read<EventsBloc>().add(
                            const UpdateSearchQuery(''),
                          );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KhairRadius.md),
              borderSide: BorderSide.none,
            ),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            context.read<EventsBloc>().add(UpdateSearchQuery(value));
          },
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<EventsBloc, EventsState>(
      builder: (context, state) {
        // Skeleton loading instead of spinner
        if (state.status == EventsStatus.loading) {
          return SliverToBoxAdapter(
            child: EventsListSkeleton(itemCount: 3),
          );
        }

        if (state.status == EventsStatus.failure) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: KhairColors.errorLight,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 36,
                      color: KhairColors.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'Failed to load events',
                    style: KhairTypography.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.read<EventsBloc>().add(LoadEvents()),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.events.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('$emptyEmoji', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'No events found here yet.',
                    style: KhairTypography.headlineSmall.copyWith(
                      color: isDark
                          ? KhairColors.darkTextSecondary
                          : KhairColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$rocketEmoji Try adjusting your filters.',
                    style: KhairTypography.bodyMedium.copyWith(
                      color: isDark
                          ? KhairColors.darkTextTertiary
                          : KhairColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: KhairSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= state.events.length) {
                  return state.status == EventsStatus.loadingMore
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: KhairColors.primary,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                }

                final event = state.events[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EventCard(
                    event: event,
                    onTap: () {
                      // Track view interaction for AI
                      context.read<AiBloc>().add(TrackInteraction(
                            eventId: event.id,
                            interactionType: 'view',
                          ));
                      context.go('/events/${event.id}');
                    },
                  ),
                );
              },
              childCount: state.events.length + 1,
            ),
          ),
        );
      },
    );
  }
}
