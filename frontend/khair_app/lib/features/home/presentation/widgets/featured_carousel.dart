import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../events/domain/entities/event.dart';

/// Netflix-style featured events carousel using real Event data.
class FeaturedCarousel extends StatefulWidget {
  final List<Event> events;
  const FeaturedCarousel({super.key, required this.events});

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late PageController _ctrl;
  int _current = 0;

  static const _gradients = [
    [Color(0xFF0F3D2E), Color(0xFF1A6B45)],
    [Color(0xFF2D1B4E), Color(0xFF5B3A8C)],
    [Color(0xFF1B3A5C), Color(0xFF2E6B9E)],
    [Color(0xFF3D1B1B), Color(0xFF8C3A3A)],
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.88)
      ..addListener(() {
        final page = _ctrl.page?.round() ?? 0;
        if (page != _current) setState(() => _current = page);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Featured Events',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.95),
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.events.length.clamp(0, 5),
            itemBuilder: (context, i) {
              final colors = _gradients[i % _gradients.length];
              return AnimatedScale(
                scale: _current == i ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                onTap: () => context.push('/events/${widget.events[i].id}'),
                child: _FeaturedCard(
                  event: widget.events[i],
                  color1: colors[0],
                  color2: colors[1],
                ),
              ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.events.length.clamp(0, 5),
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _current == i ? 24 : 8,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: _current == i
                    ? const Color(0xFFC8A951)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Event event;
  final Color color1, color2;
  const _FeaturedCard({
    required this.event,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d • h:mm a').format(event.startDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Event type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event.eventType.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (event.organizerName != null) ...[
              const SizedBox(height: 4),
              Text(
                'by ${event.organizerName}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8A951),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Join Now',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2E1F),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
