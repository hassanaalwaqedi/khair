import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../../tokens/tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../events/data/datasources/saved_events_datasource.dart';
import '../../../events/domain/entities/event.dart';

/// Shared event-discovery card for event-focused surfaces. It contains only
/// compact discovery information; full details remain on the event route.
class DiscoveryEventCard extends StatefulWidget {
  const DiscoveryEventCard(
      {super.key, required this.event, this.compact = false});

  final Event event;
  final bool compact;

  @override
  State<DiscoveryEventCard> createState() => _DiscoveryEventCardState();
}

class _DiscoveryEventCardState extends State<DiscoveryEventCard> {
  bool _hovered = false;
  bool _saved = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.surface;
    final border = dark ? AppColors.darkBorder : AppColors.border;
    final primary = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary =
        dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final location = event.isOnline
        ? 'Online event'
        : [event.city, event.country]
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .join(', ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: Offset(0, _hovered ? -.012 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  _hovered ? AppColors.primary.withValues(alpha: .5) : border,
              width: _hovered ? 1.4 : 1,
            ),
            boxShadow: _hovered
                ? [
                    const BoxShadow(
                        color: Color(0x220F0918),
                        blurRadius: 24,
                        offset: Offset(0, 12))
                  ]
                : AppShadows.sm,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/events/${event.id}'),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(19)),
                      child: Stack(children: [
                        AspectRatio(
                            aspectRatio: widget.compact ? 1.58 : 1.6,
                            child: _EventImage(event: event)),
                        PositionedDirectional(
                          top: 12,
                          start: 12,
                          child: _CategoryTag(
                              label: _categoryLabel(event.eventType)),
                        ),
                        PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: Material(
                            color: Colors.white.withValues(alpha: .94),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip:
                                  _saved ? 'Remove from saved' : 'Save event',
                              onPressed: _saving ? null : _toggleSave,
                              icon: Icon(
                                  _saved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _saved
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  size: 20),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                DateFormat('EEE, MMM d · h:mm a')
                                    .format(event.startDate),
                                style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: widget.compact ? 16 : 18,
                                    height: 1.22)),
                            const SizedBox(height: 9),
                            _Meta(
                                icon: event.isOnline
                                    ? Icons.videocam_outlined
                                    : Icons.location_on_outlined,
                                text: location.isEmpty
                                    ? 'Location to be announced'
                                    : location,
                                color: secondary),
                            const SizedBox(height: 6),
                            _Meta(
                                icon: Icons.groups_2_outlined,
                                text:
                                    '${event.reservedCount} going${event.organizerName == null ? '' : ' · ${event.organizerName}'}',
                                color: secondary),
                          ]),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) {
      context.go(
          '/login?next=${Uri.encodeComponent('/events/${widget.event.id}')}');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await SavedEventsDataSource(getIt<ApiClient>())
          .toggle(widget.event.id, saved: _saved);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('We couldn’t update your saved events.')));
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
    // The API stores event images as relative paths. Resolve those paths
    // against the API origin so Flutter web does not request them from its
    // own development-server port.
    final image = resolveMediaUrl(event.imageUrl);
    if (image.isNotEmpty) {
      return Image.network(image,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFFFDCE7), Color(0xFFF7A0BC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: const Center(
            child: Icon(Icons.groups_2_rounded,
                color: AppColors.primaryDark, size: 46)),
      );
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w500))),
      ]);
}

String _categoryLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return 'Event';
  return normalized
      .split(RegExp(r'[_\s-]+'))
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
