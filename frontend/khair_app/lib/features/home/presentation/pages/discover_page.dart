import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../events/presentation/bloc/events_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/hero_section.dart';
import '../widgets/category_scroller.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/social_proof_section.dart';
import '../widgets/gamification_card.dart';
import '../widgets/recommended_section.dart';
import '../widgets/glass_fab.dart';
import '../../../owner_posts/presentation/bloc/owner_posts_bloc.dart';
import '../../../owner_posts/presentation/widgets/khair_recommends_section.dart';
import '../../../spiritual_quotes/presentation/widgets/quote_rotator.dart';
import '../../../sheikh/presentation/bloc/sheikh_bloc.dart';
import '../../../sheikh/presentation/widgets/sheikh_directory_section.dart';

/// Discover/Home page — the main entry point.
/// Uses EventsBloc and AuthBloc for real data, no mocks.
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
    return Scaffold(
      body: AppScaffoldBackground(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1) Hero — uses AuthBloc for user name
                SliverToBoxAdapter(
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final email = authState.user?.email ?? '';
                      final name = email.contains('@')
                          ? email.split('@').first
                          : '';
                      return HeroSection(userName: name);
                    },
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.lg)),

                // 1.5) Quote Rotator — inspirational Quran/Hadith
                const SliverToBoxAdapter(
                  child: QuoteRotator(),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl)),

                // 2) Category Scroller
                const SliverToBoxAdapter(child: CategoryScroller()),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl)),

                SliverToBoxAdapter(
                  child: BlocBuilder<EventsBloc, EventsState>(
                    builder: (context, state) {
                      // Loading state
                      if (state.status == EventsStatus.loading &&
                          state.events.isEmpty) {
                        return const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.goldAccent,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      // Error state with retry
                      if (state.status == EventsStatus.failure &&
                          state.events.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 32),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_rounded,
                                  size: 48,
                                  color: AppColors.onSurfaceColor(context, 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'Something went wrong',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceColor(context, 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.errorMessage ??
                                    'Could not load events.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceColor(context, 0.4),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .read<EventsBloc>()
                                    .add(LoadEvents()),
                                icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.goldAccent,
                                  foregroundColor:
                                      const Color(0xFF0A2E1F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Empty state
                      if (state.events.isEmpty &&
                          state.status == EventsStatus.success) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 32),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy_rounded,
                                  size: 48,
                                  color: AppColors.onSurfaceColor(context, 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No events found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceColor(context, 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Explore events happening in other cities.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceColor(context, 0.4),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .read<EventsBloc>()
                                    .add(LoadEvents()),
                                icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18),
                                label:
                                    const Text('Refresh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.goldAccent,
                                  foregroundColor:
                                      const Color(0xFF0A2E1F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Success — render event sections
                      final events = state.events;
                      final totalReserved = events.fold<int>(
                          0, (sum, e) => sum + e.reservedCount);

                      final featured = events.length > 3
                          ? events.sublist(0, 3)
                          : events;
                      final recommended = events.length > 3
                          ? events.sublist(3)
                          : <dynamic>[];

                      return Column(
                        children: [
                          FeaturedCarousel(events: featured),
                          const SizedBox(height: AppSpacing.xl),
                          SocialProofSection(
                              totalReserved: totalReserved),
                          const SizedBox(height: AppSpacing.xl),
                          GamificationCard(
                            level: events.length >= 10
                                ? 'Gold'
                                : 'Silver',
                            progress: (events.length / 10)
                                .clamp(0.0, 1.0),
                            eventsToNext:
                                (10 - events.length).clamp(0, 10),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          if (recommended.isNotEmpty)
                            RecommendedSection(
                              events: recommended.cast(),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // 7) Find a Sheikh (sheikh directory)
                SliverToBoxAdapter(
                  child: BlocBuilder<SheikhBloc, SheikhState>(
                    builder: (context, sheikhState) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.xl),
                        child: SheikhDirectorySection(
                          sheikhs: sheikhState.sheikhs,
                        ),
                      );
                    },
                  ),
                ),

                // 8) Khair Recommends (owner posts)
                SliverToBoxAdapter(
                  child:
                      BlocBuilder<OwnerPostsBloc, OwnerPostsState>(
                    builder: (context, ownerState) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.xl),
                        child: KhairRecommendsSection(
                          posts: ownerState.activePosts,
                        ),
                      );
                    },
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                    child: SizedBox(height: 120)),
              ],
            ),

            // FAB
            Positioned(
              bottom: 24,
              right: 24,
              child: GlassFab(
                onPressed: () =>
                    context.push('/organizer/events/create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
