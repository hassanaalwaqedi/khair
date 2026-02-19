import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';
import 'package:khair_app/features/admin/domain/entities/admin_entities.dart';
import 'package:khair_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:khair_app/features/organizer/domain/entities/organizer.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';

/// Admin Panel - Uses real data from AdminBloc
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rejectionReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load all admin data
    context.read<AdminBloc>().add(const LoadAdminData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminBloc, AdminState>(
      listener: (context, state) {
        // Show error snackbar if action failed
        if (state.actionStatus == AdminStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: KhairColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Organizers'),
                      const SizedBox(width: 8),
                      _buildBadge(state.pendingOrganizerCount),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Events'),
                      const SizedBox(width: 8),
                      _buildBadge(state.pendingEventCount),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Reports'),
                      const SizedBox(width: 8),
                      _buildBadge(state.pendingReportCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: state.isLoading
              ? const KhairLoadingState(message: 'Loading admin data...')
              : state.status == AdminStatus.failure
                  ? KhairErrorState(
                      message: state.errorMessage ?? 'Failed to load data.',
                      onRetry: () => context.read<AdminBloc>().add(const LoadAdminData()),
                    )
                  : Stack(
                      children: [
                        TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOrganizersTab(state),
                            _buildEventsTab(state),
                            _buildReportsTab(state),
                          ],
                        ),
                        if (state.isActionLoading)
                          Container(
                            color: Colors.black26,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0 ? KhairColors.error : KhairColors.textTertiary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: KhairTypography.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildOrganizersTab(AdminState state) {
    if (state.pendingOrganizers.isEmpty) {
      return const KhairEmptyState(
        icon: Icons.check_circle,
        title: 'All Caught Up',
        message: 'No pending organizer applications to review.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdminBloc>().add(const LoadPendingOrganizers());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.pendingOrganizers.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOrganizerCard(state.pendingOrganizers[index]),
          );
        },
      ),
    );
  }

  Widget _buildOrganizerCard(Organizer organizer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KhairColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: KhairColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(organizer.name, style: KhairTypography.labelLarge),
                    Text(organizer.organizationType, style: KhairTypography.bodySmall),
                  ],
                ),
              ),
              const StatusBadge(status: 'Pending'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (organizer.email != null)
            _buildInfoRow(Icons.email_outlined, organizer.email!),
          if (organizer.city != null || organizer.country != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on_outlined,
              [organizer.city, organizer.country].where((s) => s != null).join(', '),
            ),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Submitted: ${_formatDate(organizer.createdAt)}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectOrganizerDialog(organizer),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KhairColors.error,
                    side: const BorderSide(color: KhairColors.error),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showApproveOrganizerDialog(organizer),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab(AdminState state) {
    if (state.pendingEvents.isEmpty) {
      return const KhairEmptyState(
        icon: Icons.check_circle,
        title: 'All Caught Up',
        message: 'No pending events to review.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdminBloc>().add(const LoadPendingEvents());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.pendingEvents.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEventCard(state.pendingEvents[index]),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KhairColors.secondaryLight.withAlpha(77),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event, color: KhairColors.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: KhairTypography.labelLarge),
                    Text(event.organizerName ?? 'Unknown', style: KhairTypography.bodySmall),
                  ],
                ),
              ),
              const StatusBadge(status: 'Pending'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.category_outlined, event.eventType),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.event_outlined, 'Event: ${_formatDate(event.startDate)}'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today_outlined, 'Submitted: ${_formatDate(event.createdAt)}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/events/${event.id}'),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectEventDialog(event),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KhairColors.error,
                    side: const BorderSide(color: KhairColors.error),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showApproveEventDialog(event),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(AdminState state) {
    if (state.pendingReports.isEmpty) {
      return const KhairEmptyState(
        icon: Icons.check_circle,
        title: 'No Reports',
        message: 'No reports to review at this time.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdminBloc>().add(const LoadPendingReports());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.pendingReports.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReportCard(state.pendingReports[index]),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KhairColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag, color: KhairColors.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.reportType, style: KhairTypography.labelLarge),
                    Text('Reported: ${_formatDate(report.createdAt)}', style: KhairTypography.bodySmall),
                  ],
                ),
              ),
              StatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KhairColors.surfaceVariant,
              borderRadius: KhairRadius.small,
            ),
            child: Row(
              children: [
                const Icon(Icons.report_outlined, size: 18, color: KhairColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reason: ${report.reason}',
                    style: KhairTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          if (report.description != null) ...[
            const SizedBox(height: 8),
            Text(report.description!, style: KhairTypography.bodySmall),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showResolveReportDialog(report, 'dismiss'),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showResolveReportDialog(report, 'action'),
                  child: const Text('Take Action'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: KhairColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: KhairTypography.bodyMedium)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showApproveOrganizerDialog(Organizer organizer) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Organizer'),
        content: Text('Are you sure you want to approve "${organizer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AdminBloc>().add(ApproveOrganizer(organizer.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${organizer.name} has been approved'),
                  backgroundColor: KhairColors.success,
                ),
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectOrganizerDialog(Organizer organizer) {
    _rejectionReasonController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Organizer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject "${organizer.name}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _rejectionReasonController.text;
              Navigator.pop(dialogContext);
              context.read<AdminBloc>().add(RejectOrganizer(organizer.id, reason));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${organizer.name} has been rejected'),
                  backgroundColor: KhairColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: KhairColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showApproveEventDialog(Event event) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Event'),
        content: Text('Are you sure you want to approve "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AdminBloc>().add(ApproveEvent(event.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${event.title} has been approved'),
                  backgroundColor: KhairColors.success,
                ),
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectEventDialog(Event event) {
    _rejectionReasonController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject "${event.title}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _rejectionReasonController.text;
              Navigator.pop(dialogContext);
              context.read<AdminBloc>().add(RejectEvent(event.id, reason));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${event.title} has been rejected'),
                  backgroundColor: KhairColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: KhairColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showResolveReportDialog(Report report, String type) {
    _rejectionReasonController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'dismiss' ? 'Dismiss Report' : 'Take Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type == 'dismiss'
                ? 'Provide a reason for dismissing this report:'
                : 'Describe the action taken:'),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                hintText: 'Resolution details...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final resolution = _rejectionReasonController.text;
              Navigator.pop(dialogContext);
              context.read<AdminBloc>().add(ResolveReport(
                    report.id,
                    resolution,
                    action: type == 'action' ? 'warn' : null,
                  ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Report has been ${type == 'dismiss' ? 'dismissed' : 'resolved'}'),
                  backgroundColor: KhairColors.success,
                ),
              );
            },
            child: Text(type == 'dismiss' ? 'Dismiss' : 'Confirm'),
          ),
        ],
      ),
    );
  }
}
