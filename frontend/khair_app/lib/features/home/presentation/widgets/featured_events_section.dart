import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../events/domain/entities/event.dart';

/// "Featured Events" horizontal carousel section — premium design
class FeaturedEventsSection extends StatelessWidget {
  final List<Event> events;
  final bool isLoading;

  const FeaturedEventsSection({
    super.key,
    required this.events,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: Text(
            'Featured Events',
            style: KhairTypography.h2.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Carousel ──
        SizedBox(
          height: 240,
          child: isLoading
              ? _buildSkeleton()
              : events.isEmpty
                  ? _buildEmpty()
                  : PageView.builder(
                      controller: PageController(viewportFraction: 0.88),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _FeaturedCard(
                            event: events[index],
                            onTap: () =>
                                context.go('/events/${events[index].id}'),
                          ),
                        );
                      },
                    ),
        ),
        // Page indicator dots
        if (!isLoading && events.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                events.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == 0 ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == 0
                        ? KhairColors.secondary
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_outlined,
                size: 40, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Text(
              'No featured events right now.',
              style: KhairTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual featured event card — premium design with category imagery
class _FeaturedCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const _FeaturedCard({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(event.imageUrl);
    final categoryData = _getCategoryData(event.eventType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Full background image or category gradient
            Positioned.fill(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildCategoryBackground(categoryData),
                    )
                  : _buildCategoryBackground(categoryData),
            ),

            // Gradient overlay for text readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Top badges
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  // Event type badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      _formatType(event.eventType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Attendee badge
                  if (event.reservedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.9)),
                          const SizedBox(width: 4),
                          Text(
                            '${event.reservedCount}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Category icon in center (only if no image)
            if (imageUrl.isEmpty)
              Center(
                child: Icon(
                  categoryData.icon,
                  size: 50,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),

            // Bottom content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      event.title,
                      style: KhairTypography.h2.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Organizer
                    if (event.organizerName != null)
                      Text(
                        'by ${event.organizerName}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 10),

                    // Bottom row: date + join button
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(event.startDate),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: KhairColors.secondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Join Now',
                            style: TextStyle(
                              color: Color(0xFF0A2E1C),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBackground(_CategoryData cat) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cat.colors,
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type.replaceAll('_', ' ').toUpperCase();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'Today • ${DateFormat('h:mm a').format(date)}';
    if (diff == 1) return 'Tomorrow • ${DateFormat('h:mm a').format(date)}';
    return DateFormat('EEE, MMM d • h:mm a').format(date);
  }

  static _CategoryData _getCategoryData(String eventType) {
    final type = eventType.toLowerCase();
    if (type.contains('quran') || type.contains('recit')) {
      return _CategoryData(
        icon: Icons.menu_book_rounded,
        colors: [const Color(0xFF1A5B4B), const Color(0xFF2D8E75), const Color(0xFF4DB89A)],
      );
    }
    if (type.contains('lecture') || type.contains('know')) {
      return _CategoryData(
        icon: Icons.school_rounded,
        colors: [const Color(0xFF1B4332), const Color(0xFF2D6A4F), const Color(0xFF40916C)],
      );
    }
    if (type.contains('charity') || type.contains('donat')) {
      return _CategoryData(
        icon: Icons.volunteer_activism_rounded,
        colors: [const Color(0xFF4A2040), const Color(0xFF7B3F6B), const Color(0xFFA0588D)],
      );
    }
    if (type.contains('masjid') || type.contains('mosque') || type.contains('prayer')) {
      return _CategoryData(
        icon: Icons.mosque_rounded,
        colors: [const Color(0xFF1A3A5C), const Color(0xFF2C6B97), const Color(0xFF4A90C2)],
      );
    }
    if (type.contains('youth') || type.contains('commun')) {
      return _CategoryData(
        icon: Icons.groups_rounded,
        colors: [const Color(0xFF2D4A22), const Color(0xFF4A7C3F), const Color(0xFF6BA55C)],
      );
    }
    if (type.contains('confer') || type.contains('seminar')) {
      return _CategoryData(
        icon: Icons.mic_rounded,
        colors: [const Color(0xFF3D2E1E), const Color(0xFF6B5240), const Color(0xFF9A7A5F)],
      );
    }
    if (type.contains('workshop') || type.contains('class')) {
      return _CategoryData(
        icon: Icons.auto_stories_rounded,
        colors: [const Color(0xFF1E3A3A), const Color(0xFF2C5E5E), const Color(0xFF4A8B8B)],
      );
    }
    // Default — Islamic green
    return _CategoryData(
      icon: Icons.event_rounded,
      colors: [const Color(0xFF0D3522), const Color(0xFF14553A), const Color(0xFF1E7A52)],
    );
  }
}

class _CategoryData {
  final IconData icon;
  final List<Color> colors;
  _CategoryData({required this.icon, required this.colors});
}
