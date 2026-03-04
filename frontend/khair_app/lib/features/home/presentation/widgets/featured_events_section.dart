import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../events/domain/entities/event.dart';

/// "Featured Events" horizontal carousel section
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
          height: 230,
          child: isLoading
              ? _buildSkeleton()
              : events.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _FeaturedCard(
                          event: events[index],
                          onTap: () =>
                              context.go('/events/${events[index].id}'),
                        );
                      },
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
      itemBuilder: (_, __) => Container(
        width: 165,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No featured events right now.',
          style: KhairTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Individual featured event card — compact with image, badge, details
class _FeaturedCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const _FeaturedCard({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 165,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with badge ──
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 105,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or gradient placeholder
                    event.imageUrl != null
                        ? Image.network(
                            event.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),

                    // Gradient overlay for readability
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Event type badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatType(event.eventType),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Details ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event.title,
                    style: KhairTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Location
                  if (event.city != null)
                    _infoRow(
                      Icons.location_on_outlined,
                      '${event.city}${event.country != null ? ', ${event.country}' : ''}',
                    ),

                  // Time
                  _infoRow(
                    Icons.access_time_rounded,
                    _formatTime(event.startDate),
                  ),

                  // Attendees
                  _infoRow(
                    Icons.people_outline_rounded,
                    '${event.reservedCount} attendees',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D3522), Color(0xFF14553A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.mosque_rounded,
          color: Colors.white.withValues(alpha: 0.15),
          size: 36,
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type.replaceAll('_', ' ').toUpperCase();
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'Today, ${DateFormat('HH:mm').format(date)}';
    if (diff == 1) return 'Tomorrow, ${DateFormat('HH:mm').format(date)}';
    return DateFormat('MMM d, HH:mm').format(date);
  }
}
