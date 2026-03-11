import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/admin_entities.dart';
import '../../../organizer/domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../bloc/admin_bloc.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    // Load stats and users on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadStats());
      context.read<AdminBloc>().add(const LoadUsers());
    });
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<AdminBloc>().add(const LoadAdminData());
        context.read<AdminBloc>().add(const LoadStats());
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.adminDashboardTitle,
          style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.adminRefresh,
            onPressed: () {
              context.read<AdminBloc>().add(const LoadAdminData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: KhairColors.primary,
          labelColor: KhairColors.primary,
          unselectedLabelColor: KhairColors.textTertiary,
          labelStyle: KhairTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: KhairTypography.labelLarge,
          tabs: [
            BlocBuilder<AdminBloc, AdminState>(
              buildWhen: (prev, curr) =>
                  prev.pendingOrganizerCount != curr.pendingOrganizerCount,
              builder: (context, state) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.adminOrganizersTab),
                    if (state.pendingOrganizerCount > 0) ...[
                      const SizedBox(width: 6),
                      _BadgeCount(count: state.pendingOrganizerCount),
                    ],
                  ],
                ),
              ),
            ),
            BlocBuilder<AdminBloc, AdminState>(
              buildWhen: (prev, curr) =>
                  prev.pendingEventCount != curr.pendingEventCount,
              builder: (context, state) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.adminEventsTab),
                    if (state.pendingEventCount > 0) ...[
                      const SizedBox(width: 6),
                      _BadgeCount(count: state.pendingEventCount),
                    ],
                  ],
                ),
              ),
            ),
            Tab(text: context.l10n.adminReportsTab),
            Tab(text: context.l10n.adminAuditLogsTab),
            Tab(text: context.l10n.adminQuotesTab),
            Tab(text: context.l10n.adminUsersTab),
          ],
        ),
      ),
      body: BlocListener<AdminBloc, AdminState>(
        listenWhen: (prev, curr) => prev.actionStatus != curr.actionStatus,
        listener: (context, state) {
          if (state.actionStatus == AdminStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.adminActionSuccess),
                backgroundColor: KhairColors.success,
              ),
            );
          } else if (state.actionStatus == AdminStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? context.l10n.adminActionFailed),
                backgroundColor: KhairColors.error,
              ),
            );
          }
        },
        child: Column(
          children: [
            // Stats panel
            _StatsPanel(isDark: isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OrganizersTab(isDark: isDark),
                  _EventsTab(isDark: isDark),
                  _buildReportsTab(isDark),
                  _buildAuditLogsTab(isDark),
                  _QuotesTab(isDark: isDark),
                  _UsersTab(isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag, size: 64, color: KhairColors.textTertiary),
          const SizedBox(height: 16),
          Text(context.l10n.adminReportsMgmt, style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          )),
          const SizedBox(height: 8),
          Text(context.l10n.adminReviewReportsDesc,
              style: KhairTypography.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/admin/reports'),
            icon: const Icon(Icons.open_in_new),
            label: Text(context.l10n.adminOpenReports),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: KhairColors.textTertiary),
          const SizedBox(height: 16),
          Text(context.l10n.adminAuditLogsTab, style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          )),
          const SizedBox(height: 8),
          Text(context.l10n.adminAuditLogsDesc,
              style: KhairTypography.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/admin/audit-logs'),
            icon: const Icon(Icons.open_in_new),
            label: Text(context.l10n.adminViewLogs),
          ),
        ],
      ),
    );
  }
}

// ── Organizers Tab ──

class _OrganizersTab extends StatelessWidget {
  final bool isDark;
  const _OrganizersTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.organizersStatus != curr.organizersStatus ||
          prev.pendingOrganizers != curr.pendingOrganizers ||
          prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        if (state.status == AdminStatus.loading ||
            state.organizersStatus == AdminStatus.loading) {
          return const _LoadingView();
        }

        if (state.status == AdminStatus.failure) {
          return _ErrorView(
            message: state.errorMessage ?? context.l10n.adminFailedLoadOrg,
            onRetry: () =>
                context.read<AdminBloc>().add(const LoadAdminData()),
          );
        }

        final organizers = state.pendingOrganizers;

        if (organizers.isEmpty) {
          return _EmptyView(
            icon: Icons.business_center_outlined,
            title: context.l10n.adminNoPendingOrg,
            subtitle: context.l10n.adminAllOrgReviewed,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<AdminBloc>().add(const LoadPendingOrganizers());
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: organizers.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  context.l10n.adminPendingApproval(organizers.length),
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  ),
                );
              }
              final org = organizers[index - 1];
              return _OrganizerCard(
                organizer: org,
                isDark: isDark,
                isActionLoading: state.isActionLoading,
              );
            },
          ),
        );
      },
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final Organizer organizer;
  final bool isDark;
  final bool isActionLoading;

  const _OrganizerCard({
    required this.organizer,
    required this.isDark,
    required this.isActionLoading,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organizer.name,
                      style: KhairTypography.labelLarge.copyWith(
                        color: isDark
                            ? KhairColors.darkTextPrimary
                            : KhairColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      organizer.email ?? 'No email',
                      style: KhairTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: KhairColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  organizer.status.toUpperCase(),
                  style: KhairTypography.labelSmall.copyWith(
                    color: KhairColors.warningDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Details
          _DetailRow(
            icon: Icons.category_outlined,
            label: context.l10n.adminType,
            value: organizer.organizationType,
          ),
          if (organizer.city != null || organizer.country != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: context.l10n.adminLocation,
              value: [organizer.city, organizer.country]
                  .where((e) => e != null)
                  .join(', '),
            ),
          if (organizer.description != null && organizer.description!.isNotEmpty)
            _DetailRow(
              icon: Icons.description_outlined,
              label: context.l10n.adminAbout,
              value: organizer.description!,
            ),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: context.l10n.adminSubmitted,
            value: dateFormat.format(organizer.createdAt),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isActionLoading
                      ? null
                      : () => _showRejectDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KhairColors.error,
                    side: const BorderSide(color: KhairColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: Text(context.l10n.adminReject),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isActionLoading
                      ? null
                      : () {
                          context
                              .read<AdminBloc>()
                              .add(ApproveOrganizer(organizer.id));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KhairColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: isActionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject ${organizer.name}'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject "${organizer.name}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                hintText: 'Provide a reason...',
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
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              context
                  .read<AdminBloc>()
                  .add(RejectOrganizer(organizer.id, reason));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ── Events Tab ──

class _EventsTab extends StatelessWidget {
  final bool isDark;
  const _EventsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.eventsStatus != curr.eventsStatus ||
          prev.pendingEvents != curr.pendingEvents ||
          prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        if (state.status == AdminStatus.loading ||
            state.eventsStatus == AdminStatus.loading) {
          return const _LoadingView();
        }

        if (state.status == AdminStatus.failure) {
          return _ErrorView(
            message: state.errorMessage ?? context.l10n.adminFailedLoadEvents,
            onRetry: () =>
                context.read<AdminBloc>().add(const LoadAdminData()),
          );
        }

        final events = state.pendingEvents;

        if (events.isEmpty) {
          return _EmptyView(
            icon: Icons.event_available_outlined,
            title: context.l10n.adminNoPendingEvents,
            subtitle: context.l10n.adminAllEventsReviewed,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<AdminBloc>().add(const LoadPendingEvents());
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: events.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  context.l10n.adminPendingReview(events.length),
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  ),
                );
              }
              final event = events[index - 1];
              return _EventCard(
                event: event,
                isDark: isDark,
                isActionLoading: state.isActionLoading,
              );
            },
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isDark;
  final bool isActionLoading;

  const _EventCard({
    required this.event,
    required this.isDark,
    required this.isActionLoading,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
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
                  color: KhairColors.secondaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event, color: KhairColors.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: KhairTypography.labelLarge.copyWith(
                        color: isDark
                            ? KhairColors.darkTextPrimary
                            : KhairColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${event.organizerName ?? 'Unknown'}',
                      style: KhairTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Event details
          _DetailRow(
            icon: Icons.calendar_today,
            label: context.l10n.adminDate,
            value: dateFormat.format(event.startDate),
          ),
          if (event.eventType.isNotEmpty)
            _DetailRow(
              icon: Icons.category_outlined,
              label: context.l10n.adminType,
              value: event.eventType,
            ),
          if (event.city != null || event.country != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: context.l10n.adminLocation,
              value: [event.city, event.country]
                  .where((e) => e != null)
                  .join(', '),
            ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isActionLoading
                      ? null
                      : () => _showRejectDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KhairColors.error,
                    side: const BorderSide(color: KhairColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: Text(context.l10n.adminReject),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isActionLoading
                      ? null
                      : () {
                          context
                              .read<AdminBloc>()
                              .add(ApproveEvent(event.id));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KhairColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: isActionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.adminRejectTitle(event.title)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.adminRejectConfirm(event.title)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                hintText: 'Provide a reason...',
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
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.adminProvideReasonMsg),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              context
                  .read<AdminBloc>()
                  .add(RejectEvent(event.id, reason));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.adminReject),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ──

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: KhairColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: KhairTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: KhairTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCount extends StatelessWidget {
  final int count;
  const _BadgeCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: KhairColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: KhairTypography.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: KhairColors.primary),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: KhairColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: KhairTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: KhairColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: KhairTypography.headlineSmall.copyWith(
              color: isDark
                  ? KhairColors.darkTextPrimary
                  : KhairColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: KhairTypography.bodyMedium),
        ],
      ),
    );
  }
}

// ── Stats Panel ──

class _StatsPanel extends StatelessWidget {
  final bool isDark;
  const _StatsPanel({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      buildWhen: (prev, curr) => prev.stats != curr.stats,
      builder: (context, state) {
        final stats = state.stats;
        if (stats == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? KhairColors.darkCard : KhairColors.surface,
            border: Border(bottom: BorderSide(
              color: isDark ? KhairColors.darkBorder : KhairColors.border,
            )),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatCard(icon: Icons.people, label: 'Users', value: stats.totalUsers, color: KhairColors.primary),
                const SizedBox(width: 10),
                _StatCard(icon: Icons.business, label: 'Organizers', value: stats.totalOrganizers, color: const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                _StatCard(icon: Icons.event, label: 'Events', value: stats.totalEvents, color: const Color(0xFF0891B2)),
                const SizedBox(width: 10),
                _StatCard(icon: Icons.pending_actions, label: 'Pending', value: stats.pendingOrganizers + stats.pendingEvents, color: KhairColors.warning),
                const SizedBox(width: 10),
                _StatCard(icon: Icons.flag, label: 'Reports', value: stats.pendingReports, color: KhairColors.error),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value.toString(), style: KhairTypography.labelLarge.copyWith(
                color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                fontWeight: FontWeight.w700,
              )),
              Text(label, style: KhairTypography.labelSmall.copyWith(color: KhairColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Users Tab ──

class _UsersTab extends StatelessWidget {
  final bool isDark;
  const _UsersTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      buildWhen: (prev, curr) =>
          prev.usersStatus != curr.usersStatus ||
          prev.users != curr.users ||
          prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        if (state.usersStatus == AdminStatus.loading) {
          return const _LoadingView();
        }
        if (state.usersStatus == AdminStatus.failure) {
          return _ErrorView(
            message: state.errorMessage ?? 'Failed to load users',
            onRetry: () => context.read<AdminBloc>().add(const LoadUsers()),
          );
        }
        if (state.users.isEmpty) {
          return _EmptyView(
            icon: Icons.people_outline,
            title: 'No Users',
            subtitle: 'No users found.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<AdminBloc>().add(const LoadUsers());
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: state.users.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'All Users (${state.users.length})',
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                  ),
                );
              }
              final user = state.users[index - 1];
              return _UserCard(user: user, isDark: isDark, isActionLoading: state.isActionLoading);
            },
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final bool isDark;
  final bool isActionLoading;

  const _UserCard({required this.user, required this.isDark, required this.isActionLoading});

  Color _roleColor() {
    switch (user.role) {
      case 'admin': return KhairColors.error;
      case 'organizer': return const Color(0xFF7C3AED);
      default: return KhairColors.textTertiary;
    }
  }

  Color _statusColor() {
    switch (user.status) {
      case 'suspended': return KhairColors.warning;
      case 'banned': return KhairColors.error;
      default: return KhairColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: isDark ? KhairColors.darkBorder : KhairColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _roleColor().withValues(alpha: 0.15),
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(color: _roleColor(), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: KhairTypography.labelLarge.copyWith(
                  color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
                Text(user.email, style: KhairTypography.bodySmall),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(user.role.toUpperCase(), style: KhairTypography.labelSmall.copyWith(
                      color: _roleColor(), fontWeight: FontWeight.w700, fontSize: 10,
                    )),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(user.status.toUpperCase(), style: KhairTypography.labelSmall.copyWith(
                      color: _statusColor(), fontWeight: FontWeight.w700, fontSize: 10,
                    )),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 10, color: Color(0xFF2196F3)),
                          const SizedBox(width: 3),
                          Text('VERIFIED', style: KhairTypography.labelSmall.copyWith(
                            color: const Color(0xFF2196F3), fontWeight: FontWeight.w700, fontSize: 10,
                          )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(dateFormat.format(user.createdAt), style: KhairTypography.labelSmall.copyWith(
                    color: KhairColors.textTertiary, fontSize: 10,
                  )),
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !isActionLoading,
            icon: Icon(Icons.more_vert, color: KhairColors.textTertiary),
            onSelected: (action) => _onAction(context, action),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'view', child: ListTile(leading: Icon(Icons.person), title: Text('View Profile'), dense: true, contentPadding: EdgeInsets.zero)),
              if (!user.isVerified)
                const PopupMenuItem(value: 'verify', child: ListTile(leading: Icon(Icons.verified, color: Color(0xFF2196F3)), title: Text('Verify User'), dense: true, contentPadding: EdgeInsets.zero)),
              if (user.role != 'organizer')
                const PopupMenuItem(value: 'promote_organizer', child: ListTile(leading: Icon(Icons.business), title: Text('Promote to Organizer'), dense: true, contentPadding: EdgeInsets.zero)),
              if (user.role != 'admin')
                const PopupMenuItem(value: 'promote_admin', child: ListTile(leading: Icon(Icons.admin_panel_settings), title: Text('Promote to Admin'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              if (user.status != 'suspended')
                const PopupMenuItem(value: 'suspend', child: ListTile(leading: Icon(Icons.pause_circle, color: Colors.orange), title: Text('Suspend'), dense: true, contentPadding: EdgeInsets.zero)),
              if (user.status != 'banned')
                const PopupMenuItem(value: 'ban', child: ListTile(leading: Icon(Icons.block, color: Colors.red), title: Text('Ban'), dense: true, contentPadding: EdgeInsets.zero)),
              if (user.status != 'active')
                const PopupMenuItem(value: 'activate', child: ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Activate'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
    );
  }

  void _onAction(BuildContext context, String action) {
    switch (action) {
      case 'promote_organizer':
        _showConfirmDialog(context, 'Promote to Organizer', 'Promote "${user.name}" to organizer role?', () {
          context.read<AdminBloc>().add(UpdateUserRole(user.id, 'organizer'));
        });
        break;
      case 'promote_admin':
        _showConfirmDialog(context, 'Promote to Admin', 'Promote "${user.name}" to admin role? This grants full access.', () {
          context.read<AdminBloc>().add(UpdateUserRole(user.id, 'admin'));
        });
        break;
      case 'suspend':
        _showReasonDialog(context, 'Suspend User', 'Suspend "${user.name}"?', (reason) {
          context.read<AdminBloc>().add(UpdateUserStatus(user.id, 'suspended', reason: reason));
        });
        break;
      case 'ban':
        _showReasonDialog(context, 'Ban User', 'Ban "${user.name}"? This action is severe.', (reason) {
          context.read<AdminBloc>().add(UpdateUserStatus(user.id, 'banned', reason: reason));
        });
        break;
      case 'verify':
        _showConfirmDialog(context, 'Verify User', 'Mark "${user.name}" as verified? This adds a verified badge to their profile.', () {
          context.read<AdminBloc>().add(VerifyUserEvent(user.id));
        });
        break;
      case 'activate':
        context.read<AdminBloc>().add(UpdateUserStatus(user.id, 'active'));
        break;
      case 'delete':
        _showConfirmDialog(context, 'Delete User', 'Permanently delete "${user.name}"? This cannot be undone.', () {
          context.read<AdminBloc>().add(DeleteUserEvent(user.id));
        }, destructive: true);
        break;
    }
  }

  void _showConfirmDialog(BuildContext context, String title, String message, VoidCallback onConfirm, {bool destructive = false}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(dialogCtx); onConfirm(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? KhairColors.error : KhairColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(destructive ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _showReasonDialog(BuildContext context, String title, String message, void Function(String?) onConfirm) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'Provide a reason...'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final reason = reasonCtrl.text.trim();
              onConfirm(reason.isEmpty ? null : reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: KhairColors.warning, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ── Quotes Management Tab ──

class _QuotesTab extends StatefulWidget {
  final bool isDark;
  const _QuotesTab({required this.isDark});

  @override
  State<_QuotesTab> createState() => _QuotesTabState();
}

class _QuotesTabState extends State<_QuotesTab> {
  final ApiClient _apiClient = getIt<ApiClient>();
  List<Map<String, dynamic>> _quotes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get('/admin/quotes');
      final data = response.data['data'];
      if (data is List) {
        _quotes = data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error = 'Failed to load quotes';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteQuote(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Quote'),
        content: const Text('Are you sure you want to delete this quote?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: KhairColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _apiClient.delete('/admin/quotes/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote deleted'), backgroundColor: KhairColors.success),
      );
      _loadQuotes();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete'), backgroundColor: KhairColors.error),
      );
    }
  }

  void _showQuoteDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final textCtrl = TextEditingController(text: existing?['text_ar'] ?? '');
    final sourceCtrl = TextEditingController(text: existing?['source'] ?? '');
    final refCtrl = TextEditingController(text: existing?['reference'] ?? '');
    String type = existing?['type'] ?? 'quran';
    bool isActive = existing?['is_active'] ?? true;
    bool showHome = existing?['show_on_home'] ?? true;
    bool showDashboard = existing?['show_on_dashboard'] ?? false;
    bool showLogin = existing?['show_on_login'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Quote' : 'Add Quote'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'quran', child: Text('Quran')),
                    DropdownMenuItem(value: 'hadith', child: Text('Hadith')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(labelText: 'Arabic Text'),
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(controller: sourceCtrl, decoration: const InputDecoration(labelText: 'Source')),
                const SizedBox(height: 12),
                TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference')),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Show on Home'),
                  value: showHome,
                  onChanged: (v) => setDialogState(() => showHome = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Show on Dashboard'),
                  value: showDashboard,
                  onChanged: (v) => setDialogState(() => showDashboard = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Show on Login'),
                  value: showLogin,
                  onChanged: (v) => setDialogState(() => showLogin = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (textCtrl.text.trim().isEmpty || sourceCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext);
                final body = {
                  'type': type,
                  'text_ar': textCtrl.text.trim(),
                  'source': sourceCtrl.text.trim(),
                  'reference': refCtrl.text.trim(),
                  'is_active': isActive,
                  'show_on_home': showHome,
                  'show_on_dashboard': showDashboard,
                  'show_on_login': showLogin,
                };
                try {
                  if (isEdit) {
                    await _apiClient.put('/admin/quotes/${existing['id']}', data: body);
                  } else {
                    await _apiClient.post('/admin/quotes', data: body);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Quote updated' : 'Quote added'),
                      backgroundColor: KhairColors.success,
                    ),
                  );
                  _loadQuotes();
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save'), backgroundColor: KhairColors.error),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: KhairColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: KhairTypography.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadQuotes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                'Quotes (${_quotes.length})',
                style: KhairTypography.headlineSmall.copyWith(
                  color: widget.isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showQuoteDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _quotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_quote, size: 64, color: KhairColors.textTertiary),
                      const SizedBox(height: 16),
                      Text('No quotes yet', style: KhairTypography.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadQuotes,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _quotes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final q = _quotes[index];
                      final isQuran = q['type'] == 'quran';
                      final isActive = q['is_active'] == true;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.isDark ? KhairColors.darkCard : KhairColors.surface,
                          borderRadius: KhairRadius.medium,
                          border: Border.all(
                            color: isActive
                                ? (widget.isDark ? KhairColors.darkBorder : KhairColors.border)
                                : KhairColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isQuran
                                        ? KhairColors.primarySurface
                                        : const Color(0xFFFFF4DD),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isQuran ? 'Quran' : 'Hadith',
                                    style: KhairTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isQuran ? KhairColors.primary : const Color(0xFFB8860B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: KhairColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Inactive',
                                      style: KhairTypography.labelSmall.copyWith(
                                        color: KhairColors.error,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showQuoteDialog(q),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: KhairColors.error),
                                  onPressed: () => _deleteQuote(q['id']),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              q['text_ar'] ?? '',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                                height: 1.7,
                                color: widget.isDark
                                    ? KhairColors.darkTextPrimary
                                    : KhairColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${q['source']} • ${q['reference']}',
                              style: KhairTypography.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
