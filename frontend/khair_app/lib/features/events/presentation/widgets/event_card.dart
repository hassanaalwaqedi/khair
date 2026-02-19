import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/emoji_mapper.dart';
import '../../domain/entities/event.dart';

/// Premium event card with hover elevation micro-interaction
class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KhairAnimations.normal,
          curve: KhairAnimations.defaultCurve,
          decoration: BoxDecoration(
            color: isDark ? KhairColors.darkCard : KhairColors.surface,
            borderRadius: BorderRadius.circular(KhairRadius.lg),
            border: Border.all(
              color: _isHovered
                  ? KhairColors.primary.withAlpha(60)
                  : (isDark ? KhairColors.darkBorder : KhairColors.border),
            ),
            boxShadow: _isHovered ? KhairShadows.hover : KhairShadows.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with badges
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(KhairRadius.lg),
                ),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: widget.event.imageUrl != null
                          ? Image.network(
                              widget.event.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                            )
                          : _buildPlaceholder(isDark),
                    ),
                    // Category badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [KhairColors.primary, KhairColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(KhairRadius.lg),
                        ),
                        child: Text(
                          '${getCategoryEmoji(widget.event.eventType)} ${widget.event.eventType.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    // Date badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? KhairColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(KhairRadius.sm),
                          boxShadow: KhairShadows.sm,
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('dd').format(widget.event.startDate),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: KhairColors.primary,
                              ),
                            ),
                            Text(
                              DateFormat('MMM').format(widget.event.startDate).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: KhairColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(KhairSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: KhairTypography.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (widget.event.organizerName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 16,
                              color: isDark
                                  ? KhairColors.darkTextTertiary
                                  : KhairColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.event.organizerName!,
                                style: KhairTypography.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Location row
                    Row(
                      children: [
                        const Text(locationEmoji, style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _buildLocationText(),
                            style: KhairTypography.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: KhairSpacing.smd),
                    // Date row
                    Row(
                      children: [
                        const Text(dateEmoji, style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('E, MMM dd • hh:mm a').format(widget.event.startDate),
                          style: KhairTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? KhairColors.darkSurfaceVariant : KhairColors.neutral200,
      child: Center(
        child: Icon(
          Icons.event,
          size: 48,
          color: isDark ? KhairColors.darkTextTertiary : KhairColors.neutral400,
        ),
      ),
    );
  }

  String _buildLocationText() {
    final parts = <String>[];
    if (widget.event.city != null) parts.add(widget.event.city!);
    if (widget.event.country != null) parts.add(widget.event.country!);
    return parts.isNotEmpty ? parts.join(', ') : 'Location TBA';
  }
}
