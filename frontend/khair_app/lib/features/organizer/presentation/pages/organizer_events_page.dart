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
    context.read<OrganizerBloc>().add(const LoadOrganizerEvents());
  }

  List<Event> _filterEvents(List<Event> events) {
    if (_selectedFilter == 'all') return events;
    return events.where((e) => e.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.go('/organizer/events/create'),
            tooltip: 'Create Event',
          ),
        ],
      ),
      body: BlocBuilder<OrganizerBloc, OrganizerState>(
        builder: (context, state) {
          // Loading
          if (state.isEventsLoading && state.events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading events...'),
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
                context.read<OrganizerBloc>().add(const LoadOrganizerEvents());
              },
            );
          }

          final filteredEvents = _filterEvents(state.events);

          return RefreshIndicator(
            color: KhairColors.primary,
            onRefresh: () async {
              context.read<OrganizerBloc>().add(const LoadOrganizerEvents());
              // Wait for the events to load
              await Future.delayed(const Duration(milliseconds: 800));
            },
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
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'approved',
                            'Approved',
                            state.events
                                .where((e) => e.status == 'approved')
                                .length,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'pending',
                            'Pending',
                            state.events
                                .where((e) => e.status == 'pending')
                                .length,
                          ),
                          const SizedBox(width: 8),
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
                          ? () => context.go('/organizer/events/create')
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
      label: '$label ($count)',
      isSelected: isSelected,
      onTap: () => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event, bool isDark) {
    return KhairCard(
      onTap: () => context.go('/events/${event.id}'),
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
            const SizedBox(width: 16),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusBadge(status: _mapStatus(event.status)),
                      if (event.city != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined,
                            size: 14, color: KhairColors.textTertiary),
                        const SizedBox(width: 2),
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
              icon:
                  const Icon(Icons.more_vert, color: KhairColors.textTertiary),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (event.status == 'approved')
                  const PopupMenuItem(
                    value: 'notify',
                    child: Row(
                      children: [
                        Icon(Icons.campaign_rounded, size: 18, color: KhairColors.primary),
                        SizedBox(width: 8),
                        Text('Notify Attendees'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: KhairColors.error)),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    context.go('/events/${event.id}');
                    break;
                  case 'edit':
                    context.go('/organizer/events/${event.id}/edit');
                    break;
                  case 'notify':
                    _showNotifyAttendeesDialog(context, event);
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
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
            final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
            final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;

            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: bdr,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(children: [
                      Icon(Icons.campaign_rounded, color: KhairColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Send Message to Attendees',
                        style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.w700),
                      )),
                    ]),
                    const SizedBox(height: 6),
                    Text('Message will be sent as push notification and in-app notification to all confirmed attendees of "${event.title}".',
                      style: TextStyle(color: ts, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Message input
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      maxLength: 500,
                      style: TextStyle(color: tp, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type your message to attendees...',
                        hintStyle: TextStyle(color: ts.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : KhairColors.neutral50,
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
                          borderSide: BorderSide(color: KhairColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Include link checkbox
                    if (event.isOnline)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setSheetState(() => includeLink = !includeLink),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(
                              width: 22, height: 22,
                              child: Checkbox(
                                value: includeLink,
                                onChanged: (v) => setSheetState(() => includeLink = v ?? false),
                                activeColor: KhairColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Include event link in notification',
                              style: TextStyle(color: tp, fontSize: 13),
                            ),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Send button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSending || messageController.text.trim().isEmpty
                            ? null
                            : () async {
                                setSheetState(() => isSending = true);
                                try {
                                  final api = getIt<ApiClient>();
                                  await api.post(
                                    '/api/v1/events/${event.id}/notify-attendees',
                                    data: {
                                      'message': messageController.text.trim(),
                                      'include_link': includeLink,
                                    },
                                  );
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: const Text('Message sent to all attendees!'),
                                        backgroundColor: KhairColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() => isSending = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to send: $e'),
                                        backgroundColor: KhairColors.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSending
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(isSending ? 'Sending...' : 'Send Message',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KhairColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: KhairColors.primary.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      case 'rejected':
        return 'Rejected';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
