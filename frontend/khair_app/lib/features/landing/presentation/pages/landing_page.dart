import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/di/injection.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';
import 'package:khair_app/core/widgets/language_switcher.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';
import 'package:khair_app/features/events/presentation/bloc/events_bloc.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';
import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:video_player/video_player.dart';

/// Landing Page - First impression & trust building
/// Fetches real stats and featured events from API
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late EventsBloc _eventsBloc;
  late VideoPlayerController _videoController;
  bool _videoReady = false;
  
  // Stats loaded from API (with fallback defaults)
  int _eventCount = 0;
  int _organizationCount = 0;
  int _cityCount = 0;
  bool _statsLoaded = false;
  
  // Featured events for hero section
  List<Event> _featuredEvents = [];

  @override
  void initState() {
    super.initState();
    _eventsBloc = getIt<EventsBloc>();
    _loadStats();
    _initVideo();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('video_khair.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoReady = true);
          _videoController.play();
        }
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _eventsBloc.close();
    super.dispose();
  }

  Future<void> _loadStats() async {
    // Load a few events to show in hero section and get stats
    _eventsBloc.add(LoadEvents());
    
    // Listen for state changes
    _eventsBloc.stream.listen((state) {
      if (state.status == EventsStatus.success && mounted) {
        setState(() {
          _featuredEvents = state.events.take(2).toList();
          // Calculate approximate stats from loaded data
          // In a real app, you'd have a dedicated stats endpoint
          _eventCount = state.events.length;
          _statsLoaded = true;
          
          // Get unique organizers and cities from events
          final organizers = <String>{};
          final cities = <String>{};
          for (final event in state.events) {
            organizers.add(event.organizerId);
            if (event.city != null) {
              cities.add(event.city!);
            }
          }
          _organizationCount = organizers.length;
          _cityCount = cities.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: KhairColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KhairColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'خ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Khair',
                  style: KhairTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(context.l10n.events),
              ),
              TextButton(
                onPressed: () => context.go('/map'),
                child: Text(context.l10n.mapTab),
              ),
              const SizedBox(width: 8),
              const LanguageSwitcher(showLabel: false),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: Text(context.l10n.signIn),
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildVideoBanner(context),
                _buildHeroSection(context),
                _buildFeaturesSection(context),
                _buildHowItWorksSection(context),
                _buildCTASection(context),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBanner(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video background
          if (_videoReady)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A2E1C), Color(0xFF14553A)],
                ),
              ),
            ),

          // Dark gradient overlay for readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),

          // Text overlay
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khair',
                  style: KhairTypography.displayLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 44,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.discoverSubtitle,
                  style: KhairTypography.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Play/pause toggle
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _videoController.value.isPlaying
                      ? _videoController.pause()
                      : _videoController.play();
                });
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _videoReady && _videoController.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: isWide ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            KhairColors.primarySurface,
            KhairColors.background,
          ],
        ),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: _buildHeroContent(context)),
                const SizedBox(width: 64),
                Expanded(child: _buildHeroImage()),
              ],
            )
          : Column(
              children: [
                _buildHeroContent(context),
                const SizedBox(height: 48),
                _buildHeroImage(),
              ],
            ),
    );
  }

  Widget _buildHeroContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: KhairColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            context.l10n.heroTagline,
            style: KhairTypography.labelMedium.copyWith(
              color: KhairColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.heroTitle,
          style: KhairTypography.displayLarge.copyWith(
            color: KhairColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.heroSubtitle,
          style: KhairTypography.bodyLarge.copyWith(
            color: KhairColors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            KhairButton(
              label: context.l10n.browseEvents,
              onPressed: () => context.go('/'),
              icon: Icons.explore,
            ),
            KhairButton(
              label: context.l10n.registerOrganization,
              onPressed: () => context.go('/organizer/apply'),
              isOutlined: true,
              icon: Icons.business,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Real stats from API
        Row(
          children: [
            _buildStatItem(
              _statsLoaded ? '$_eventCount' : '...',
              context.l10n.events,
            ),
            const SizedBox(width: 32),
            _buildStatItem(
              _statsLoaded ? '$_organizationCount' : '...',
              context.l10n.organizations,
            ),
            const SizedBox(width: 32),
            _buildStatItem(
              _statsLoaded ? '$_cityCount' : '...',
              context.l10n.cities,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: KhairTypography.headlineLarge.copyWith(
            color: KhairColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: KhairTypography.bodyMedium),
      ],
    );
  }

  Widget _buildHeroImage() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: KhairColors.surfaceVariant,
        borderRadius: KhairRadius.large,
        border: Border.all(color: KhairColors.border),
      ),
      child: Stack(
        children: [
          // Map preview placeholder
          ClipRRect(
            borderRadius: KhairRadius.large,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    KhairColors.primarySurface,
                    KhairColors.surfaceVariant,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.map_outlined,
                  size: 120,
                  color: KhairColors.primary.withAlpha(51),
                ),
              ),
            ),
          ),
          // Real event cards or fallback placeholders
          if (_featuredEvents.isNotEmpty) ...[
            Positioned(
              top: 24,
              left: 24,
              child: _buildFloatingEventCard(
                _featuredEvents[0].title,
                _featuredEvents[0].organizerName ?? _featuredEvents[0].city ?? 'Event',
              ),
            ),
            if (_featuredEvents.length > 1)
              Positioned(
                bottom: 60,
                right: 24,
                child: _buildFloatingEventCard(
                  _featuredEvents[1].title,
                  _featuredEvents[1].organizerName ?? _featuredEvents[1].city ?? 'Event',
                ),
              ),
          ] else ...[
            // Show loading shimmer or empty state
            Positioned(
              top: 24,
              left: 24,
              child: _buildFloatingEventCardPlaceholder(),
            ),
            Positioned(
              bottom: 60,
              right: 24,
              child: _buildFloatingEventCardPlaceholder(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingEventCard(String title, String location) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        boxShadow: KhairShadows.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KhairColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.event, color: KhairColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.length > 20 ? '${title.substring(0, 20)}...' : title,
                style: KhairTypography.labelLarge,
              ),
              Text(
                location.length > 25 ? '${location.substring(0, 25)}...' : location,
                style: KhairTypography.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingEventCardPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        boxShadow: KhairShadows.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KhairColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: KhairColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: KhairColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      child: Column(
        children: [
          Text(
            context.l10n.whyChooseKhair,
            style: KhairTypography.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.whyChooseSubtitle,
            style: KhairTypography.bodyLarge.copyWith(
              color: KhairColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureCard(
                Icons.verified,
                context.l10n.featureVerifiedTitle,
                context.l10n.featureVerifiedDesc,
              ),
              _buildFeatureCard(
                Icons.map,
                context.l10n.featureMapTitle,
                context.l10n.featureMapDesc,
              ),
              _buildFeatureCard(
                Icons.language,
                context.l10n.featureLanguageTitle,
                context.l10n.featureLanguageDesc,
              ),
              _buildFeatureCard(
                Icons.calendar_today,
                context.l10n.featureDiscoveryTitle,
                context.l10n.featureDiscoveryDesc,
              ),
              _buildFeatureCard(
                Icons.security,
                context.l10n.featureSafeTitle,
                context.l10n.featureSafeDesc,
              ),
              _buildFeatureCard(
                Icons.groups,
                context.l10n.featureCommunityTitle,
                context.l10n.featureCommunityDesc,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KhairColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: KhairColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: KhairTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(
            description,
            style: KhairTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      color: KhairColors.surfaceVariant,
      child: Column(
        children: [
          Text(
            context.l10n.howItWorks,
            style: KhairTypography.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          isWide
              ? Row(
                  children: [
                    Expanded(child: _buildStep('1', context.l10n.step1Title, context.l10n.step1Desc)),
                    _buildStepConnector(),
                    Expanded(child: _buildStep('2', context.l10n.step2Title, context.l10n.step2Desc)),
                    _buildStepConnector(),
                    Expanded(child: _buildStep('3', context.l10n.step3Title, context.l10n.step3Desc)),
                  ],
                )
              : Column(
                  children: [
                    _buildStep('1', context.l10n.step1Title, context.l10n.step1Desc),
                    const SizedBox(height: 24),
                    _buildStep('2', context.l10n.step2Title, context.l10n.step2Desc),
                    const SizedBox(height: 24),
                    _buildStep('3', context.l10n.step3Title, context.l10n.step3Desc),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: KhairColors.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: Text(
              number,
              style: KhairTypography.headlineMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(title, style: KhairTypography.headlineSmall),
        const SizedBox(height: 8),
        Text(
          description,
          style: KhairTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: 60,
      height: 2,
      margin: const EdgeInsets.only(bottom: 60),
      color: KhairColors.border,
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [KhairColors.primary, KhairColors.primaryDark],
          ),
          borderRadius: KhairRadius.extraLarge,
        ),
        child: Column(
          children: [
            Text(
              context.l10n.ctaTitle,
              style: KhairTypography.displaySmall.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.ctaSubtitle,
              style: KhairTypography.bodyLarge.copyWith(
                color: Colors.white.withAlpha(204),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/organizer/apply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: KhairColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(context.l10n.registerOrganization),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      color: KhairColors.textPrimary,
      child: Column(
        children: [
          Wrap(
            spacing: 32,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.go('/about'),
                child: Text(context.l10n.footerAbout, style: TextStyle(color: Colors.white.withAlpha(179))),
              ),
              TextButton(
                onPressed: () => context.go('/privacy'),
                child: Text(context.l10n.footerPrivacy, style: TextStyle(color: Colors.white.withAlpha(179))),
              ),
              TextButton(
                onPressed: () => context.go('/terms'),
                child: Text(context.l10n.footerTerms, style: TextStyle(color: Colors.white.withAlpha(179))),
              ),
              TextButton(
                onPressed: () => context.go('/content-policy'),
                child: Text(context.l10n.footerContent, style: TextStyle(color: Colors.white.withAlpha(179))),
              ),
              TextButton(
                onPressed: () => context.go('/verification-policy'),
                child: Text(context.l10n.footerVerification, style: TextStyle(color: Colors.white.withAlpha(179))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.footerCopyright,
            style: KhairTypography.bodySmall.copyWith(
              color: Colors.white.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }
}
