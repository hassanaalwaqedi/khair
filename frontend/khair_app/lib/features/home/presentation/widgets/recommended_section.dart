import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../events/domain/entities/event.dart';

/// "Recommended for You" — horizontal scroll of smaller event cards.
class RecommendedSection extends StatelessWidget {
  final List<Event> events;
  const RecommendedSection({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(context.l10n.recommendedForYou, style: TextStyle(
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
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: events.length.clamp(0, 8),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              return _RecommendedCard(
                event: events[i],
                cardBg: cardBg, bdr: bdr, tp: tp, ts: ts, isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final Event event;
  final Color cardBg, bdr, tp, ts;
  final bool isDark;

  const _RecommendedCard({
    required this.event, required this.cardBg, required this.bdr,
    required this.tp, required this.ts, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(event.startDate);
    final timeStr = DateFormat('h:mm a').format(event.startDate);
    final imageUrl = resolveMediaUrl(event.imageUrl);

    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 90, width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder())
                    : _imgPlaceholder(),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp, height: 1.3)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 11, color: ts),
                    const SizedBox(width: 4),
                    Expanded(child: Text('$dateStr · $timeStr',
                        style: TextStyle(fontSize: 11, color: ts), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: isDark ? KhairColors.darkSurfaceVariant : KhairColors.surfaceVariant,
      child: Center(child: Icon(Icons.event_rounded,
          color: isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary, size: 28)),
    );
  }
}
