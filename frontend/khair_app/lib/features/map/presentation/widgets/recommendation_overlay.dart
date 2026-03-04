import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/map_models.dart';

class RecommendationOverlay extends StatelessWidget {
  const RecommendationOverlay({
    super.key,
    required this.events,
    required this.onSelect,
  });

  final List<MapEvent> events;
  final ValueChanged<MapEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return InkWell(
            onTap: () => onSelect(event),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (event.recommended)
                        _Tag(
                          label: l10n.mapRecommended,
                          color: const Color(0xFF1E9E66),
                        ),
                      if (event.isTrending)
                        _Tag(
                          label: l10n.trending,
                          color: const Color(0xFFE88F1D),
                        ),
                      if (event.endingSoon)
                        _Tag(
                          label: l10n.mapEndingSoon,
                          color: const Color(0xFFC84545),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.mapDistanceOrg(
                      event.distanceKm.toStringAsFixed(1),
                      event.organization,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: events.length.clamp(0, 8),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
