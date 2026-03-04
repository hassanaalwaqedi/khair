import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
                }
              },
            ),
          ],
        ),
      ),
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
