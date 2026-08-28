import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_components.dart';
import '../../../events/domain/entities/event.dart';

import '../bloc/organizer_bloc.dart';

/// Full-page organizer events list with status filter chips, pull-to-refresh,
/// and proper loading/empty/error states.
class OrganizerEventsPage extends StatefulWidget {
  const OrganizerEventsPage({super.key});

  @override
  State<OrganizerEventsPage> createState() => _OrganizerEventsPageState();
}

class _OrganizerEventsPageState extends State<OrganizerEventsPage> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    context.read<OrganizerBloc>().add(LoadOrganizerEvents());
  }

  List<Event> _filterEvents(List<Event> events) {
    if (_selectedFilter == 'all') return events;
    return events.where((e) => e.status == _selectedFilter).toList();
  }

  Future<void> _refreshEvents() async {
    final bloc = context.read<OrganizerBloc>();
    final completed = bloc.stream.firstWhere(
      (state) => state.eventsStatus != OrganizerStatus.loading,
    );
    bloc.add(LoadOrganizerEvents());
    await completed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.orgMyEvents),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => context.push('/organizer/events/create'),
            tooltip: context.l10n.mapCreateEvent,
          ),
        ],
      ),
      body: BlocBuilder<OrganizerBloc, OrganizerState>(
        builder: (context, state) {
          // Loading
          if (state.isEventsLoading && state.events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(context.l10n.mapLoadingEvents),
                ],
              ),
            );
          }

          // Error
          if (state.eventsStatus == OrganizerStatus.failure &&
              state.events.isEmpty) {
            return KhairErrorState(
              message:
                  state.errorMessage ?? 'Failed to load events. Please retry.',
              onRetry: () {
                context.read<OrganizerBloc>().add(LoadOrganizerEvents());
              },
            );
          }

          final filteredEvents = _filterEvents(state.events);

          return RefreshIndicator(
            color: KhairColors.primary,
            onRefresh: _refreshEvents,
            child: CustomScrollView(
              slivers: [
                // Filter chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All', state.events.length),
                          SizedBox(width: 8),
                          _buildFilterChip(
                            'approved',
                            'Approved',
                            state.events
                                .where((e) => e.status == 'approved')
                                .length,
                          ),
                          SizedBox(width: 8),
                          _buildFilterChip(
                            'pending',
                            'Pending',
                            state.events
                                .where((e) => e.status == 'pending')
                                .length,
                          ),
                          SizedBox(width: 8),
                          _buildFilterChip(
                            'rejected',
                            'Rejected',
                            state.events
                                .where((e) => e.status == 'rejected')
                                .length,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Empty state
                if (filteredEvents.isEmpty)
                  SliverFillRemaining(
                    child: KhairEmptyState(
                      icon: Icons.event_note_outlined,
                      title: _selectedFilter == 'all'
                          ? 'No events yet'
                          : 'No $_selectedFilter events',
                      message: _selectedFilter == 'all'
                          ? 'Create your first event to get started'
                          : 'You have no events with this status',
                      actionLabel:
                          _selectedFilter == 'all' ? 'Create Event' : null,
                      onAction: _selectedFilter == 'all'
                          ? () => context.push('/organizer/events/create')
                          : null,
                    ),
                  )
                else
                  // Events list
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = filteredEvents[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildEventCard(context, event, isDark),
                          );
                        },
                        childCount: filteredEvents.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _selectedFilter == value;
    return KhairFilterChip(
      label: context.l10n.filterLabelCount(label, count),
      isSelected: isSelected,
      onTap: () => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event, bool isDark) {
    return KhairCard(
      onTap: () => _openEvent(context, event),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            // Date box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: KhairColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.startDate.day.toString(),
                    style: KhairTypography.headlineSmall.copyWith(
                      color: KhairColors.primary,
                    ),
                  ),
                  Text(
                    _monthAbbr(event.startDate.month),
                    style: KhairTypography.labelSmall.copyWith(
                      color: KhairColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: KhairTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      StatusBadge(status: _mapStatus(event.status)),
                      if (event.city != null) ...[
                        SizedBox(width: 8),
                        Icon(Icons.location_on_outlined,
                            size: 14, color: KhairColors.textTertiary),
                        SizedBox(width: 2),
                        Text(
                          event.city!,
                          style: KhairTypography.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: KhairColors.textTertiary),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'view', child: Text(context.l10n.view)),
                PopupMenuItem(
                    value: 'edit', child: Text(context.l10n.ownerEdit)),
                if (event.status == 'approved')
                  PopupMenuItem(
                    value: 'notify',
                    child: Row(
                      children: [
                        Icon(Icons.campaign_rounded,
                            size: 18, color: KhairColors.primary),
                        SizedBox(width: 8),
                        Text(context.l10n.notifyAttendees),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                      event.status == 'approved' || event.status == 'published'
                          ? 'Cancel event'
                          : context.l10n.ownerDelete,
                      style: TextStyle(color: KhairColors.error)),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _openEvent(context, event);
                    break;
                  case 'edit':
                    context.push('/organizer/events/${event.id}/edit',
                        extra: event);
                    break;
                  case 'notify':
                    _showNotifyAttendeesDialog(context, event);
                    break;
                  case 'delete':
                    _confirmDelete(context, event);
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEvent(BuildContext context, Event event) {
    if (event.status == 'draft') {
      context.push('/organizer/events/${event.id}/edit', extra: event);
      return;
    }
    final publicEvent =
        event.status == 'approved' || event.status == 'published';
    context.push(
        publicEvent ? '/events/${event.id}' : '/organizer/events/${event.id}');
  }

  Future<void> _confirmDelete(BuildContext context, Event event) async {
    final isPublic = event.status == 'approved' || event.status == 'published';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPublic ? 'Cancel event?' : 'Delete event?'),
        content: Text(isPublic
            ? 'This will hide the event from discovery and notify confirmed attendees. Organizer cancellation is unavailable within 24 hours of the start time.'
            : 'This event will be permanently deleted if it has no active registrations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KhairColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isPublic ? 'Cancel event' : context.l10n.ownerDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await getIt<ApiClient>().delete('/events/${event.id}');
      if (!context.mounted) return;
      context.read<OrganizerBloc>().add(LoadOrganizerEvents());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isPublic ? 'Event cancelled' : 'Event deleted')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: KhairColors.error,
        ),
      );
    }
  }

  void _showNotifyAttendeesDialog(BuildContext ctx, Event event) {
    final messageController = TextEditingController();
    bool includeLink = false;
    bool isSending = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? KhairColors.darkSurface : Colors.white;
            final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;
            final tp =
                isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
            final ts = isDark
                ? KhairColors.darkTextSecondary
                : KhairColors.textSecondary;

            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: bdr,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Title
                    Row(children: [
                      Icon(Icons.campaign_rounded,
                          color: KhairColors.primary, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        'Send Message to Attendees',
                        style: TextStyle(
                            color: tp,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      )),
                    ]),
                    SizedBox(height: 6),
                    Text(
                      'Message will be sent as push notification and in-app notification to all confirmed attendees of "${event.title}".',
                      style: TextStyle(color: ts, fontSize: 13, height: 1.4),
                    ),
                    SizedBox(height: 20),

                    // Message input
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      maxLength: 500,
                      style: TextStyle(color: tp, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.l10n.typeYourMessageToAttendees,
                        hintStyle: TextStyle(color: ts.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : KhairColors.neutral50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: bdr),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: bdr),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: KhairColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Include link checkbox
                    if (event.isOnline)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            setSheetState(() => includeLink = !includeLink),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: includeLink,
                                onChanged: (v) => setSheetState(
                                    () => includeLink = v ?? false),
                                activeColor: KhairColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Include event link in notification',
                              style: TextStyle(color: tp, fontSize: 13),
                            ),
                          ]),
                        ),
                      ),
                    SizedBox(height: 16),

                    // Send button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSending ||
                                messageController.text.trim().isEmpty
                            ? null
                            : () async {
                                setSheetState(() => isSending = true);
                                try {
                                  final api = getIt<ApiClient>();
                                  await api.post(
                                    '/events/${event.id}/notify-attendees',
                                    data: {
                                      'message': messageController.text.trim(),
                                      'include_link': includeLink,
                                    },
                                  );
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Message sent to all attendees!'),
                                        backgroundColor: KhairColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() => isSending = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            context.l10n.adminActionFailed),
                                        backgroundColor: KhairColors.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(Icons.send_rounded, size: 18),
                        label: Text(
                            isSending
                                ? context.l10n.sending
                                : context.l10n.sendMessageToAttendees,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KhairColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              KhairColors.primary.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'approved':
        return 'Published';
      case 'pending':
        return 'Pending Review';
      case 'pending_update':
        return 'Update Pending';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
