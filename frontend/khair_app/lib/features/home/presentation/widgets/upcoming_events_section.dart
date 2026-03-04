import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../events/domain/entities/event.dart';

/// "Upcoming for You" vertical list section
class UpcomingEventsSection extends StatelessWidget {
  final List<Event> events;
  final bool isLoading;

  const UpcomingEventsSection({
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
          child: Text(
            'Upcoming for You',
            style: KhairTypography.h2.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Event list ──
        if (isLoading)
          ...List.generate(3, (_) => _skeletonRow())
        else if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No upcoming events found.',
              style: KhairTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          )
        else
          ...events.map((e) => _UpcomingEventRow(
                event: e,
                onTap: () => context.go('/events/${e.id}'),
              )),
      ],
    );
  }

  Widget _skeletonRow() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Single upcoming event row: thumbnail · title/subtitle · attendees
class _UpcomingEventRow extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const _UpcomingEventRow({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: event.imageUrl != null
                    ? Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbnail(),
                      )
                    : _thumbnail(),
              ),
            ),
            const SizedBox(width: 12),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: KhairTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Attendee count
            Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.reservedCount}+',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'attendees',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D3522), Color(0xFF14553A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event_rounded,
          color: Colors.white.withValues(alpha: 0.2),
          size: 24,
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (event.organizerName != null) parts.add(event.organizerName!);
    if (event.city != null) parts.add(event.city!);
    if (parts.isEmpty) {
      parts.add(DateFormat('MMM d, HH:mm').format(event.startDate));
    }
    return parts.join(' · ');
  }
}
