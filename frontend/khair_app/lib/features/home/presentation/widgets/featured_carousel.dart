import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../events/domain/entities/event.dart';

/// Featured events carousel with event images, organizer, date, and CTA buttons.
class FeaturedCarousel extends StatefulWidget {
  final List<Event> events;
  const FeaturedCarousel({super.key, required this.events});

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late PageController _ctrl;
  int _current = 0;

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
    if (widget.events.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(context.l10n.featuredEvents, style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: tp, letterSpacing: -0.3)),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(context.l10n.seeAll, style: TextStyle(
                  color: KhairColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Carousel
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.events.length.clamp(0, 5),
            itemBuilder: (context, i) {
              return AnimatedScale(
                scale: _current == i ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: () => context.push('/events/${widget.events[i].id}'),
                  child: _FeaturedCard(event: widget.events[i]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.events.length.clamp(0, 5),
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 20 : 6, height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: _current == i
                    ? KhairColors.primary
                    : (isDark ? Colors.white.withValues(alpha: 0.12) : KhairColors.neutral300),
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
  const _FeaturedCard({required this.event});

  // Gradient fallback colors by event type
  static const _fallbackGradients = {
    'lecture': [Color(0xFF1E3A5F), Color(0xFF2563EB)],
    'charity': [Color(0xFF4A2040), Color(0xFF7B3F6B)],
    'quran': [Color(0xFF1B4332), Color(0xFF2D6A4F)],
    'social': [Color(0xFF3730A3), Color(0xFF6366F1)],
    'workshop': [Color(0xFF1E3A5F), Color(0xFF2563EB)],
    'sports': [Color(0xFF7F1D1D), Color(0xFFDC2626)],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(event.startDate);
    final imageUrl = resolveMediaUrl(event.imageUrl);
    final gradColors = _fallbackGradients[event.eventType.toLowerCase()] ??
        [const Color(0xFF1E3A5F), KhairColors.primary];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: gradColors,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              image: imageUrl.isNotEmpty ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.45), BlendMode.darken,
                ),
              ) : null,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(event.eventType.toUpperCase(), style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.8,
                    )),
                  ),
                  const Spacer(),
                  if (event.reservedCount > 0) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text('${event.reservedCount}', style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ]),
                  ),
                ]),
                const Spacer(),
                // Title
                Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
                      letterSpacing: -0.3, height: 1.2,
                    )),
                if (event.organizerName != null) ...[
                  const SizedBox(height: 4),
                  Text(context.l10n.byOrganizer(event.organizerName!), style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.7),
                  )),
                ],
                const SizedBox(height: 12),
                // Bottom row: date + CTA
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 13,
                      color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(dateStr, overflow: TextOverflow.ellipsis, style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500,
                  ))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(context.l10n.joinNow, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: KhairColors.primary,
                    )),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
