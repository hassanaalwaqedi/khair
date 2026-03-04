import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

import '../../../../core/theme/theme_bloc.dart';
import '../../../../core/widgets/islamic_pattern_painter.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../tokens/tokens.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../spiritual_quotes/domain/entities/spiritual_quote.dart';
import '../../../spiritual_quotes/presentation/widgets/spiritual_quote_section.dart';
import '../bloc/events_bloc.dart';
import '../widgets/event_card.dart';
import '../widgets/islamic_empty_state.dart';
import '../widgets/smart_filter_chips.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final AnimationController _heroController;
  late final AnimationController _backgroundController;

  Timer? _motivationTimer;
  int _motivationIndex = 0;

  List<String> _getMotivationalLines(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      l10n?.motivationalLine1 ?? 'Indeed, with hardship comes ease 🌿',
      l10n?.motivationalLine2 ??
          'And We made you peoples and tribes so that you may know one another 🤍',
      l10n?.motivationalLine3 ?? 'Allah is Gentle with His servants 🌙',
    ];
  }

  @override
  void initState() {
    super.initState();
    context.read<EventsBloc>().add(LoadEvents());

    _heroController = AnimationController(
      duration: AppDurations.long,
      vsync: this,
    )..forward();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat(reverse: true);

    _motivationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _motivationIndex = (_motivationIndex + 1) % 3;
      });
    });

    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _motivationTimer?.cancel();
    _heroController.dispose();
    _backgroundController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  Future<void> _onRefresh() async {
    context.read<EventsBloc>().add(LoadEvents());
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
      child: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: _AnimatedBackdrop(animation: _backgroundController),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: IslamicPatternPainter(
                        color: Colors.white,
                        opacity: 0.04,
                        cellSize: 58,
                      ),
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.x1)),
                      SliverToBoxAdapter(
                        child: _constrained(
                          child: _buildHeroSection(context, state),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _constrained(
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.x2,
                              AppSpacing.x2,
                              AppSpacing.x2,
                              0,
                            ),
                            child: SpiritualQuoteSection(
                              location: QuoteLocation.home,
                              compact: true,
                            ),
                          ),
                        ),
                      ),
                      ..._buildEventSlivers(context, state),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildEventSlivers(BuildContext context, EventsState state) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    if (state.status == EventsStatus.loading ||
        state.status == EventsStatus.initial) {
      return [
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x3)),
        SliverToBoxAdapter(
          child: _constrained(
            child: const EventsListSkeleton(itemCount: 4),
          ),
        ),
      ];
    }

    if (state.status == EventsStatus.failure) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: IslamicEmptyState(
              title: l10n?.error ?? 'Something went wrong',
              subtitle: state.errorMessage ?? 'Please try again in a moment.',
              buttonLabel: l10n?.retry ?? 'Retry',
              onRefresh: () => context.read<EventsBloc>().add(LoadEvents()),
              icon: Icons.wifi_off_rounded,
            ),
          ),
        ),
      ];
    }

    if (state.events.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: IslamicEmptyState(
              title: l10n?.emptyGatheringsTitle ?? 'No gatherings yet',
              subtitle: l10n?.emptyGatheringsSubtitle ??
                  'Try another category or adjust your search.',
              buttonLabel: l10n?.refreshEvents ?? 'Refresh',
              onRefresh: () => context.read<EventsBloc>().add(LoadEvents()),
            ),
          ),
        ),
      ];
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final constrainedWidth = math.min(screenWidth, 1200);
    final sidePadding =
        screenWidth > 1200 ? ((screenWidth - 1200) / 2) + 16 : 16.0;
    final crossAxisCount = constrainedWidth >= 1024
        ? 3
        : constrainedWidth >= 720
            ? 2
            : 1;

    final childAspectRatio = switch (crossAxisCount) {
      1 => 0.90,
      2 => 0.82,
      _ => 0.78,
    };

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              sidePadding, AppSpacing.x3, sidePadding, AppSpacing.x2),
          child: Text(
            l10n?.happeningInCommunity ?? 'Happening in Your Community',
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding:
            EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, AppSpacing.x2),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final event = state.events[index];
              return _StaggeredSlideIn(
                index: index,
                child: EventCard(
                  event: event,
                  onTap: () => context.go('/events/${event.id}'),
                  onJoinTap: () => context.go('/events/${event.id}'),
                ),
              );
            },
            childCount: state.events.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.x2,
            crossAxisSpacing: AppSpacing.x2,
            childAspectRatio: childAspectRatio,
          ),
        ),
      ),
      if (state.status == EventsStatus.loadingMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
            child: Center(
              child: SizedBox(
                width: AppSpacing.x4,
                height: AppSpacing.x4,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(
        child: SizedBox(height: AppSpacing.x10),
      ),
    ];
  }

  Widget _buildHeroSection(BuildContext context, EventsState state) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final subheadline = l10n?.discoverSubtitle ??
        'Connect with knowledge, support, and meaningful local moments.';

    return FadeTransition(
      opacity: CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.x2, AppSpacing.x1, AppSpacing.x2, 0),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x3, AppSpacing.x3, AppSpacing.x3, AppSpacing.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B5F50),
                Color(0xFF1C7A66),
                Color(0xFF2D8E75),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220E6E5D),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopActions(context),
              const SizedBox(height: AppSpacing.x3),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 14 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Text(
                  '${l10n?.discoverTitle ?? 'Discover Meaningful Gatherings'} 🤝✨',
                  style: textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1.06,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _heroController,
                  curve: const Interval(0.25, 1, curve: Curves.easeOut),
                ),
                child: Text(
                  subheadline,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              _buildMotivationTicker(context),
              const SizedBox(height: AppSpacing.x3),
              _buildAnimatedSearchBar(context),
              const SizedBox(height: AppSpacing.x2),
              const SmartFilterChips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopActions(BuildContext context) {
    return Row(
      children: [
        Text(
          AppLocalizations.of(context)?.khairCommunity ?? 'Khair Community',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            final icon = switch (themeState.themeMode) {
              ThemeMode.system => Icons.brightness_auto_rounded,
              ThemeMode.light => Icons.light_mode_rounded,
              ThemeMode.dark => Icons.dark_mode_rounded,
            };
            return _HeroActionButton(
              icon: icon,
              onTap: () => context.read<ThemeBloc>().add(const ToggleTheme()),
            );
          },
        ),
        const SizedBox(width: AppSpacing.x1),
        _HeroActionButton(
          icon: Icons.map_outlined,
          onTap: () => context.go('/map'),
        ),
        const SizedBox(width: AppSpacing.x1),
        _HeroActionButton(
          icon: Icons.person_outline_rounded,
          onTap: () => context.go('/profile'),
        ),
        const SizedBox(width: AppSpacing.x1),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: Colors.white.withValues(alpha: 0.16),
          ),
          child: const LanguageSwitcher(showLabel: false),
        ),
      ],
    );
  }

  Widget _buildMotivationTicker(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Text(
        _getMotivationalLines(context)[_motivationIndex],
        key: ValueKey(_motivationIndex),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildAnimatedSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedScale(
      scale: _searchFocusNode.hasFocus ? 1.015 : 1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: _searchFocusNode.hasFocus ? 0.20 : 0.10),
              blurRadius: _searchFocusNode.hasFocus ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                l10n?.searchEventsHint ?? 'Search events, topics, cities...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      context
                          .read<EventsBloc>()
                          .add(const UpdateSearchQuery(''));
                      setState(() {});
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: AppSpacing.x2,
            ),
          ),
          onChanged: (value) {
            setState(() {});
            context.read<EventsBloc>().add(UpdateSearchQuery(value));
          },
        ),
      ),
    );
  }

  Widget _constrained({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 1200) {
          return child;
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: child,
          ),
        );
      },
    );
  }
}

class _AnimatedBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedBackdrop({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final xShift = math.sin(t * math.pi * 2) * 0.28;
        final yShift = math.cos(t * math.pi * 2) * 0.24;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + xShift, -1 + yShift),
                  end: Alignment(1 - xShift, 1 - yShift),
                  colors: const [
                    Color(0xFF0D5B4D),
                    Color(0xFF6FB39A),
                    Color(0xFFF8F4EC),
                  ],
                ),
              ),
            ),
            _FloatingOrb(
              animation: animation,
              size: 240,
              alignment: const Alignment(-0.9, -0.7),
              color: Colors.white.withValues(alpha: 0.08),
              phase: 0,
            ),
            _FloatingOrb(
              animation: animation,
              size: 180,
              alignment: const Alignment(1.0, -0.2),
              color: Colors.white.withValues(alpha: 0.07),
              phase: 1.6,
            ),
            _FloatingOrb(
              animation: animation,
              size: 300,
              alignment: const Alignment(0.2, 1.2),
              color: Colors.white.withValues(alpha: 0.05),
              phase: 2.4,
            ),
          ],
        );
      },
    );
  }
}

class _FloatingOrb extends StatelessWidget {
  final Animation<double> animation;
  final double size;
  final Alignment alignment;
  final Color color;
  final double phase;

  const _FloatingOrb({
    required this.animation,
    required this.size,
    required this.alignment,
    required this.color,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final shiftX = math.sin((animation.value * math.pi * 2) + phase) * 24;
    final shiftY = math.cos((animation.value * math.pi * 2) + phase) * 18;

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(shiftX, shiftY),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: _hovered ? 0.26 : 0.18),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredSlideIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredSlideIn({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index % 12) * 28;
    final duration = Duration(milliseconds: 240 + delay);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: builtChild,
          ),
        );
      },
    );
  }
}
