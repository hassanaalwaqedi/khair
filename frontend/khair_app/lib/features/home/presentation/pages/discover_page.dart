import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/hero_section.dart';
import '../widgets/category_scroller.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/recommended_section.dart';
import '../../../owner_posts/presentation/bloc/owner_posts_bloc.dart';
import '../../../owner_posts/presentation/widgets/khair_recommends_section.dart';
import '../../../spiritual_quotes/presentation/widgets/quote_rotator.dart';
import '../../../sheikh/presentation/bloc/sheikh_bloc.dart';
import '../../../sheikh/presentation/widgets/sheikh_directory_section.dart';

/// Discover/Home page — professional Meetup-style event discovery.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<EventsBloc>();
    if (bloc.state.status == EventsStatus.initial) {
      bloc.add(LoadEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KhairColors.darkBackground : KhairColors.background;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final tt = isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;

    return Scaffold(
      backgroundColor: bg,
      // FAB for event creation
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/organizer/events/create'),
        backgroundColor: KhairColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══ 1. HEADER ═══
          SliverToBoxAdapter(
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final email = authState.user?.email ?? '';
                final name = email.contains('@') ? email.split('@').first : '';
                return HeroSection(userName: name);
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ═══ 2. DAILY INSPIRATION (Quran/Hadith) ═══
          const SliverToBoxAdapter(child: QuoteRotator()),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ═══ 3. CATEGORY FILTERS ═══
          const SliverToBoxAdapter(child: CategoryScroller()),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ═══ EVENTS CONTENT (Loading / Error / Empty / Data) ═══
          SliverToBoxAdapter(
            child: BlocBuilder<EventsBloc, EventsState>(
              builder: (context, state) {
                // Loading — skeleton
                if (state.status == EventsStatus.loading && state.events.isEmpty) {
                  return _buildSkeletonLoader(isDark, cardBg, bdr);
                }

                // Error
                if (state.status == EventsStatus.failure && state.events.isEmpty) {
                  return _buildErrorState(context, state.errorMessage, isDark, tp, ts, tt);
                }

                // Empty
                if (state.events.isEmpty && state.status == EventsStatus.success) {
                  return _buildEmptyState(context, isDark, tp, ts, tt);
                }

                // ═══ Success — all event sections ═══
                final events = state.events;
                final featured = events.length > 3 ? events.sublist(0, 3) : events;
                final recommended = events.length > 3 ? events.sublist(3) : <Event>[];

                return Column(children: [
                  // 4. Featured Events (Hero Carousel)
                  FeaturedCarousel(events: featured),

                  const SizedBox(height: 24),

                  // 5. Recommended for You
                  if (recommended.isNotEmpty) ...[
                    RecommendedSection(events: recommended),
                    const SizedBox(height: 24),
                  ],

                  // 6. Sheikh / Scholars
                  BlocBuilder<SheikhBloc, SheikhState>(
                    builder: (context, sheikhState) {
                      if (sheikhState.sheikhs.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: SheikhDirectorySection(sheikhs: sheikhState.sheikhs),
                      );
                    },
                  ),

                  // 7. Khair Recommends (owner posts)
                  BlocBuilder<OwnerPostsBloc, OwnerPostsState>(
                    builder: (context, ownerState) {
                      if (ownerState.activePosts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: KhairRecommendsSection(posts: ownerState.activePosts),
                      );
                    },
                  ),

                  // ═══ 8. ALL EVENTS FEED ═══
                  _buildAllEventsFeed(events, isDark, tp, ts, tt, cardBg, bdr),
                ]);
              },
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  ALL EVENTS FEED (vertical infinite)
  // ═══════════════════════════════════════
  Widget _buildAllEventsFeed(List<Event> events, bool isDark,
      Color tp, Color ts, Color tt, Color cardBg, Color bdr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Icon(Icons.explore_rounded, color: KhairColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(context.l10n.allEvents, style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: tp, letterSpacing: -0.3)),
            const Spacer(),
            Text(context.l10n.discoverEventsCount(events.length), style: TextStyle(
                fontSize: 13, color: ts, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 14),
        ...events.map((event) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _AllEventCard(
            event: event, cardBg: cardBg, bdr: bdr, tp: tp, ts: ts, tt: tt, isDark: isDark,
          ),
        )),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  SKELETON LOADER
  // ═══════════════════════════════════════
  Widget _buildSkeletonLoader(bool isDark, Color cardBg, Color bdr) {
    final shimBase = isDark ? KhairColors.darkSurfaceVariant : KhairColors.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // Featured skeleton
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: shimBase, borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 20),
        // Cards skeleton
        ...List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: shimBase, borderRadius: BorderRadius.circular(14),
            ),
          ),
        )),
      ]),
    );
  }

  // ═══════════════════════════════════════
  //  ERROR STATE
  // ═══════════════════════════════════════
  Widget _buildErrorState(BuildContext ctx, String? msg, bool isDark,
      Color tp, Color ts, Color tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: tt),
          const SizedBox(height: 16),
          Text(context.l10n.discoverSomethingWentWrong, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: tp)),
          const SizedBox(height: 8),
          Text(msg ?? context.l10n.discoverCouldNotLoad, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ts)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ctx.read<EventsBloc>().add(LoadEvents()),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════
  Widget _buildEmptyState(BuildContext ctx, bool isDark,
      Color tp, Color ts, Color tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: KhairColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 40, color: KhairColors.primary),
          ),
          const SizedBox(height: 20),
          Text(context.l10n.discoverNoEventsNearYou, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: tp)),
          const SizedBox(height: 8),
          Text(context.l10n.discoverExploreOtherCities,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ts)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ctx.read<EventsBloc>().add(LoadEvents()),
            icon: const Icon(Icons.explore_rounded, size: 18),
            label: Text(context.l10n.discoverExploreAllEvents),
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
//  ALL EVENT CARD (vertical feed)
// ═══════════════════════════════════════
class _AllEventCard extends StatelessWidget {
  final Event event;
  final Color cardBg, bdr, tp, ts, tt;
  final bool isDark;

  const _AllEventCard({
    required this.event, required this.cardBg, required this.bdr,
    required this.tp, required this.ts, required this.tt, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(event.startDate);
    final timeStr = DateFormat('h:mm a').format(event.startDate);
    final imageUrl = resolveMediaUrl(event.imageUrl);
    final location = [event.city, event.country]
        .where((s) => s != null && s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bdr),
        ),
        child: Row(children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(15)),
            child: SizedBox(
              width: 100, height: 100,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                  : _imgPlaceholder(),
            ),
          ),
          // Info
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: KhairColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(event.eventType, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: KhairColors.primary,
                  )),
                ),
                const SizedBox(height: 6),
                // Title
                Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp, height: 1.3)),
                const SizedBox(height: 6),
                // Date + Location
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: ts),
                  const SizedBox(width: 4),
                  Text('$dateStr · $timeStr', style: TextStyle(fontSize: 11, color: ts)),
                ]),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: ts),
                    const SizedBox(width: 4),
                    Expanded(child: Text(location, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: ts))),
                  ]),
                ],
              ],
            ),
          )),
          // Attendees
          if (event.reservedCount > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_rounded, size: 16, color: KhairColors.primary),
                const SizedBox(height: 2),
                Text('${event.reservedCount}', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: KhairColors.primary)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: isDark ? KhairColors.darkSurfaceVariant : KhairColors.surfaceVariant,
      child: Center(child: Icon(Icons.event_rounded, color: tt, size: 28)),
    );
  }
}
