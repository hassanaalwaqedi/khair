import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../events/domain/entities/event.dart';
import '../bloc/organizer_bloc.dart';

/// Organizer-only view for events that are not publicly discoverable yet.
/// Pending, draft, rejected, and revision events must not use the public
/// event-details endpoint because that endpoint intentionally hides them.
class OrganizerEventStatusPage extends StatelessWidget {
  final String eventId;

  const OrganizerEventStatusPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.eventStatus),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => context.popOrGo('/organizer/events'),
        ),
      ),
      body: BlocBuilder<OrganizerBloc, OrganizerState>(
        builder: (context, state) {
          if (state.isEventsLoading && state.events.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }

          final event = _findEvent(state.events);
          if (event == null) {
            return _UnavailableState(
              message: state.errorMessage ??
                  'This event is no longer available in your organizer account.',
            );
          }

          return _EventStatusContent(event: event);
        },
      ),
    );
  }

  Event? _findEvent(List<Event> events) {
    for (final event in events) {
      if (event.id == eventId) return event;
    }
    return null;
  }
}

class _EventStatusContent extends StatelessWidget {
  final Event event;

  const _EventStatusContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusCopy(event.status);
    final imageUrl = ApiConfig.resolveUrl(event.imageUrl);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 7,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _EventImagePlaceholder(),
                      ),
                    ),
                  )
                else
                  const _EventImagePlaceholder(),
                SizedBox(height: 20),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SizedBox(height: 16),
                _StatusPanel(
                  dark: dark,
                  icon: status.$1,
                  title: status.$2,
                  message: status.$3,
                  color: status.$4,
                ),
                SizedBox(height: 16),
                _DetailsPanel(event: event, dark: dark),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/organizer/events'),
                    icon: Icon(Icons.arrow_back_rounded),
                    label: Text(context.l10n.backToMyEvents),
                    style: FilledButton.styleFrom(
                      backgroundColor: KhairColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  (IconData, String, String, Color) _statusCopy(String value) {
    switch (value) {
      case 'approved':
      case 'published':
        return (
          Icons.check_circle_outline_rounded,
          'Approved and discoverable',
          'This event is visible to the Khair community.',
          Colors.green,
        );
      case 'rejected':
        return (
          Icons.error_outline_rounded,
          'Changes requested',
          event.rejectionReason ??
              'Please review the organizer feedback before submitting again.',
          Colors.orange,
        );
      case 'needs_revision':
        return (
          Icons.edit_note_rounded,
          'Revision needed',
          'Please update the event details and submit it again for review.',
          Colors.orange,
        );
      case 'draft':
        return (
          Icons.edit_note_rounded,
          'Draft saved',
          'This event is private until you finish it and submit it for review.',
          KhairColors.primary,
        );
      default:
        return (
          Icons.hourglass_top_rounded,
          'Pending review',
          'Khair moderation is reviewing this event. It will become public after approval.',
          KhairColors.primary,
        );
    }
  }
}

class _StatusPanel extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _StatusPanel({
    required this.dark,
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? KhairColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text(message,
                    style: TextStyle(
                        color:
                            dark ? Colors.white60 : KhairColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  final Event event;
  final bool dark;

  const _DetailsPanel({required this.event, required this.dark});

  @override
  Widget build(BuildContext context) {
    final location = event.isOnline
        ? context.l10n.onlineEvent
        : [event.city, event.country]
            .where((part) => part != null && part.isNotEmpty)
            .map((part) => part)
            .join(', ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? KhairColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            text: DateFormat('EEE, MMM d, yyyy · h:mm a')
                .format(event.startDate.toLocal()),
            dark: dark,
          ),
          SizedBox(height: 12),
          _DetailRow(
            icon:
                event.isOnline ? Icons.videocam_outlined : Icons.place_outlined,
            text: location.isEmpty ? 'Location pending' : location,
            dark: dark,
          ),
          SizedBox(height: 12),
          _DetailRow(
            icon: Icons.info_outline_rounded,
            text: event.status.replaceAll('_', ' '),
            dark: dark,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dark;

  const _DetailRow(
      {required this.icon, required this.text, required this.dark});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon,
              size: 18,
              color: dark ? Colors.white54 : KhairColors.textSecondary),
          SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      );
}

class _EventImagePlaceholder extends StatelessWidget {
  const _EventImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        height: 190,
        decoration: BoxDecoration(
          color: KhairColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child:
              Icon(Icons.event_outlined, color: KhairColors.primary, size: 48),
        ),
      );
}

class _UnavailableState extends StatelessWidget {
  final String message;

  const _UnavailableState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined, size: 48),
              SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.go('/organizer/events'),
                icon: Icon(Icons.arrow_back_rounded),
                label: Text(context.l10n.backToMyEvents),
              ),
            ],
          ),
        ),
      );
}
