import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../tokens/tokens.dart';
import '../../domain/entities/event.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;
  final VoidCallback? onJoinTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onJoinTap,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _hovered = false;
  bool _joinHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = _categoryMeta(widget.event.eventType);
    final location = _locationText(widget.event);
    final attendeeText = _attendeeText(widget.event);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _joinHovered = false;
      }),
      child: AnimatedSlide(
        offset: Offset(0, _hovered ? -0.014 : 0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _hovered
                ? const [
                    BoxShadow(
                      color: Color(0x2A0E6E5D),
                      blurRadius: 26,
                      offset: Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Color(0x1A111827),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ]
                : AppShadows.md,
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.34)
                  : AppColors.border,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: widget.event.imageUrl == null
                              ? _fallbackImage()
                              : Image.network(
                                  widget.event.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _fallbackImage(),
                                ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.02),
                                  Colors.black.withValues(alpha: 0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: AppSpacing.x2,
                          left: AppSpacing.x2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x2,
                              vertical: AppSpacing.x1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              '${category.$1} ${category.$2}',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x2,
                        AppSpacing.x2,
                        AppSpacing.x2,
                        AppSpacing.x2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          _MetaRow(
                            leading: const Text('🗓️'),
                            text: DateFormat('EEE, MMM d • h:mm a')
                                .format(widget.event.startDate),
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          _MetaRow(
                            leading: const Text('📍'),
                            text: location,
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          _MetaRow(
                            leading: const Text('👥'),
                            text: attendeeText,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              if (widget.event.organizerName != null) ...[
                                Expanded(
                                  child: Text(
                                    widget.event.organizerName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.x2),
                              ],
                              _buildJoinButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _joinHovered = true),
      onExit: (_) => setState(() => _joinHovered = false),
      child: AnimatedScale(
        scale: _joinHovered ? 1.04 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: const LinearGradient(
              colors: [Color(0xFF0E6E5D), Color(0xFF20856F)],
            ),
            boxShadow: _joinHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: widget.onJoinTap ?? widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
              child: Text(
                'Join',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D5B4D),
            Color(0xFF2C8D73),
            Color(0xFF74BBA3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.groups_rounded,
          color: Colors.white.withValues(alpha: 0.94),
          size: 54,
        ),
      ),
    );
  }

  String _locationText(Event event) {
    final pieces = <String>[
      if (event.city != null && event.city!.isNotEmpty) event.city!,
      if (event.country != null && event.country!.isNotEmpty) event.country!,
    ];
    if (pieces.isEmpty) {
      return 'Location announced soon';
    }
    return pieces.join(', ');
  }

  String _attendeeText(Event event) {
    final reserved = event.reservedCount;
    if (event.capacity == null || event.capacity == 0) {
      return '$reserved attending';
    }
    return '$reserved / ${event.capacity} seats';
  }

  (String, String) _categoryMeta(String rawType) {
    final type = rawType.toLowerCase();
    const map = <String, (String, String)>{
      'knowledge': ('📚', 'Knowledge'),
      'quran': ('🕌', 'Quran'),
      'lectures': ('🎤', 'Lectures'),
      'community': ('👥', 'Community'),
      'youth': ('🌱', 'Youth'),
      'charity': ('🤲', 'Charity'),
      'family': ('👨‍👩‍👧', 'Family'),
      'conference': ('📚', 'Knowledge'),
      'workshop': ('📚', 'Knowledge'),
      'seminar': ('🎤', 'Lectures'),
      'festival': ('👥', 'Community'),
      'meetup': ('👥', 'Community'),
    };
    return map[type] ?? ('🔥', 'Trending');
  }
}

class _MetaRow extends StatelessWidget {
  final Widget leading;
  final String text;

  const _MetaRow({
    required this.leading,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 18, child: Center(child: leading)),
        const SizedBox(width: AppSpacing.x1),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
