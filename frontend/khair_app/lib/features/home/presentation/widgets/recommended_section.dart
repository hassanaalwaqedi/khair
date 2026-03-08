import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../events/domain/entities/event.dart';

/// Recommended-for-you section using real Event data.
class RecommendedSection extends StatelessWidget {
  final List<Event> events;
  const RecommendedSection({super.key, required this.events});

  static const _tagColors = {
    'lecture': Color(0xFF2E7D5A),
    'charity': Color(0xFFC8A951),
    'social': Color(0xFF5B3A8C),
    'workshop': Color(0xFF2E6B9E),
    'quran': Color(0xFF22C55E),
    'sports': Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Recommended For You',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC8A951).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(events.length.clamp(0, 5), (i) {
          final event = events[i];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 500 + i * 150),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: GestureDetector(
                onTap: () => context.push('/events/${event.id}'),
                child: _RecommendedCard(
                  event: event,
                  tagColor: _tagColors[event.eventType.toLowerCase()] ??
                      const Color(0xFF2E7D5A),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final Event event;
  final Color tagColor;
  const _RecommendedCard({required this.event, required this.tagColor});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('EEE, MMM d • h:mm a').format(event.startDate);
    final location = [event.city, event.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.event_rounded, color: tagColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              event.eventType,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tagColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
