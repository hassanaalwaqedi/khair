import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/utils/media_url_helper.dart';
import '../../../../../tokens/tokens.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../events/data/datasources/saved_events_datasource.dart';
import '../../../../events/domain/entities/event.dart';

class CompactEventCard extends StatefulWidget {
  const CompactEventCard({super.key, required this.event});
  final Event event;

  @override
  State<CompactEventCard> createState() => _CompactEventCardState();
}

class _CompactEventCardState extends State<CompactEventCard> {
  bool _hovered = false;
  bool _saved = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final location = event.isOnline
        ? context.l10n.onlineEvent
        : [event.city, event.country]
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .join(', ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: Offset(0, _hovered ? -.012 : 0),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          width: 250,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? AppColors.primary.withValues(alpha: .5) : AppColors.border,
              width: _hovered ? 1.4 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: Color(0x220F0918),
                        blurRadius: 24,
                        offset: Offset(0, 12))
                  ]
                : AppShadows.sm,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/events/${event.id}'),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.5,
                          child: _EventImage(event: event),
                        ),
                        // Top-left Pills
                        PositionedDirectional(
                          top: 10,
                          start: 10,
                          child: Row(
                            children: [
                              _Pill(
                                label: event.isOnline
                                    ? context.l10n.online
                                    : context.l10n.createEventInPerson,
                                icon: event.isOnline ? Icons.videocam_rounded : Icons.location_on_rounded,
                              ),
                            ],
                          ),
                        ),
                        // Top-right Save Button
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: Material(
                            color: Colors.white.withValues(alpha: .94),
                            shape: CircleBorder(),
                            child: IconButton(
                              tooltip: _saved
                                  ? context.l10n.removeFromSaved
                                  : context.l10n.saveEvent,
                              onPressed: _saving ? null : _toggleSave,
                              icon: Icon(
                                _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _saved ? AppColors.primary : AppColors.textPrimary,
                                size: 18,
                              ),
                              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date
                        Text(
                          DateFormat('EEE, MMM d · h:mm a').format(event.startDate),
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        // Title
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Metadata
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location.isEmpty ? 'Location to be announced' : location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
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
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) {
      context.go('/login?next=${Uri.encodeComponent('/events/${widget.event.id}')}');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await SavedEventsDataSource(getIt<ApiClient>()).toggle(widget.event.id, saved: _saved);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.savedEventsUpdateError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.event});
  final Event event;
  @override
  Widget build(BuildContext context) {
    final image = resolveMediaUrl(event.imageUrl);
    if (image.isNotEmpty) {
      return Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFDCE7), Color(0xFFF7A0BC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(Icons.groups_2_rounded, color: AppColors.primaryDark, size: 36),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.icon,
    this.color = AppColors.textPrimary,
    this.backgroundColor = Colors.white,
  });
  final String label;
  final IconData? icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: color),
              SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
}
