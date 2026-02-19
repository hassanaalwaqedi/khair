import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';
import 'package:khair_app/features/organizer/domain/entities/organizer.dart';
import 'package:khair_app/features/organizer/presentation/bloc/organizer_bloc.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';

/// Organizer Dashboard - Uses real data from OrganizerBloc
class OrganizerDashboardPageNew extends StatefulWidget {
  const OrganizerDashboardPageNew({super.key});

  @override
  State<OrganizerDashboardPageNew> createState() => _OrganizerDashboardPageNewState();
}

class _OrganizerDashboardPageNewState extends State<OrganizerDashboardPageNew> {
  @override
  void initState() {
    super.initState();
    // Load organizer data
    final bloc = context.read<OrganizerBloc>();
    bloc.add(const LoadOrganizerProfile());
    bloc.add(const LoadOrganizerEvents());
    bloc.add(const LoadAdminMessages());
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Dashboard'),
        actions: [
          BlocBuilder<OrganizerBloc, OrganizerState>(
            builder: (context, state) {
              final unreadCount = state.unreadMessageCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: KhairColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<OrganizerBloc, OrganizerState>(
        builder: (context, state) {
          // Loading state
          if (state.isProfileLoading && state.organizer == null) {
            return const KhairLoadingState(message: 'Loading dashboard...');
          }

          // Error state (profile failed)
          if (state.profileStatus == OrganizerStatus.failure && state.organizer == null) {
            return KhairErrorState(
              message: state.errorMessage ?? 'Failed to load profile. Please try again.',
              onRetry: () {
                context.read<OrganizerBloc>().add(const LoadOrganizerProfile());
              },
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildMainContent(state)),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildSidebar(state)),
                    ],
                  )
                : Column(
                    children: [
                      _buildMainContent(state),
                      const SizedBox(height: 24),
                      _buildSidebar(state),
                    ],
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/organizer/events/create'),
        backgroundColor: KhairColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Create Event',
          style: KhairTypography.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMainContent(OrganizerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        _buildStatusCard(state.organizer),

        const SizedBox(height: 24),

        // Events section
        SectionHeader(
          title: 'Your Events',
          subtitle: '${state.events.length} events',
          action: TextButton.icon(
            onPressed: () => context.go('/organizer/events/create'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Event'),
          ),
        ),

        // Events loading
        if (state.isEventsLoading && state.events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        // Events empty
        else if (state.events.isEmpty)
          _buildEmptyEventsCard()
        // Events list
        else
          ...state.events.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildEventCard(event),
              )),
      ],
    );
  }

  Widget _buildStatusCard(Organizer? organizer) {
    if (organizer == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: KhairColors.surfaceVariant,
          borderRadius: KhairRadius.large,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: organizer.isPending
              ? [KhairColors.warning, KhairColors.warning.withAlpha(200)]
              : organizer.isRejected
                  ? [KhairColors.error, KhairColors.error.withAlpha(200)]
                  : [KhairColors.primary, KhairColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: KhairRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            organizer.name,
                            style: KhairTypography.headlineMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                organizer.isApproved
                                    ? Icons.check_circle
                                    : organizer.isPending
                                        ? Icons.pending
                                        : Icons.cancel,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                organizer.status.toUpperCase(),
                                style: KhairTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      organizer.isVerified ? 'Verified Organizer' : organizer.organizationType,
                      style: KhairTypography.bodyMedium.copyWith(
                        color: Colors.white.withAlpha(179),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Show rejection reason if rejected
          if (organizer.isRejected && organizer.rejectionReason != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: KhairRadius.small,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection reason: ${organizer.rejectionReason}',
                      style: KhairTypography.bodySmall.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyEventsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: KhairColors.surfaceVariant,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note, size: 48, color: KhairColors.textTertiary),
          const SizedBox(height: 16),
          Text('No events yet', style: KhairTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create your first event to get started',
            style: KhairTypography.bodyMedium.copyWith(color: KhairColors.textSecondary),
          ),
          const SizedBox(height: 16),
          KhairButton(
            label: 'Create Event',
            onPressed: () => context.go('/organizer/events/create'),
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return KhairCard(
      onTap: () => context.go('/events/${event.id}'),
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
                  _getMonthAbbr(event.startDate.month),
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
                Text(event.title, style: KhairTypography.labelLarge),
                const SizedBox(height: 4),
                StatusBadge(status: _mapEventStatus(event.status)),
              ],
            ),
          ),

          // Actions
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: KhairColors.textTertiary),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'view', child: Text('View')),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: KhairColors.error)),
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
    );
  }

  String _mapEventStatus(String status) {
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

  Widget _buildSidebar(OrganizerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick stats
        _buildQuickStats(state),

        const SizedBox(height: 24),

        // Admin messages
        const SectionHeader(title: 'Messages'),

        if (state.isMessagesLoading && state.messages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.messages.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KhairColors.surfaceVariant,
              borderRadius: KhairRadius.medium,
            ),
            child: Row(
              children: [
                Icon(Icons.inbox_outlined, color: KhairColors.textTertiary),
                const SizedBox(width: 12),
                Text(
                  'No messages',
                  style: KhairTypography.bodyMedium.copyWith(color: KhairColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ...state.messages.map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMessageCard(msg),
              )),
      ],
    );
  }

  Widget _buildQuickStats(OrganizerState state) {
    final events = state.events;
    final published = events.where((e) => e.status == 'approved').length;
    final pending = events.where((e) => e.status == 'pending').length;
    final drafts = events.where((e) => e.status == 'draft').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Stats', style: KhairTypography.labelLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Published', published.toString(), Icons.public),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem('Pending', pending.toString(), Icons.pending),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Drafts', drafts.toString(), Icons.edit_note),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem('Total', events.length.toString(), Icons.event),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KhairColors.surfaceVariant,
        borderRadius: KhairRadius.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: KhairColors.textTertiary),
          const SizedBox(height: 8),
          Text(value, style: KhairTypography.headlineSmall),
          Text(label, style: KhairTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildMessageCard(AdminMessage message) {
    return GestureDetector(
      onTap: () {
        if (!message.isRead) {
          context.read<OrganizerBloc>().add(MarkMessageRead(message.id));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isRead ? KhairColors.surfaceVariant : KhairColors.infoLight,
          borderRadius: KhairRadius.medium,
          border: Border.all(
            color: message.isRead
                ? KhairColors.border
                : KhairColors.info.withAlpha(51),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  message.isRead ? Icons.mail_outline : Icons.mark_email_unread,
                  size: 16,
                  color: message.isRead ? KhairColors.textTertiary : KhairColors.info,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(message.createdAt),
                  style: KhairTypography.labelSmall.copyWith(
                    color: message.isRead ? KhairColors.textTertiary : KhairColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.subject,
              style: KhairTypography.labelMedium.copyWith(
                fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.message,
              style: KhairTypography.bodySmall.copyWith(
                color: KhairColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${_getMonthAbbr(date.month)} ${date.day}, ${date.year}';
  }
}
