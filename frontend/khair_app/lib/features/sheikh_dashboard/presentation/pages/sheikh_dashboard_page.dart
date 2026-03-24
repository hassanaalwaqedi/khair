import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../chat/domain/entities/lesson_request.dart';
import '../bloc/sheikh_dashboard_bloc.dart';

/// Sheikh Dashboard — main page with tab navigation.
class SheikhDashboardPage extends StatefulWidget {
  const SheikhDashboardPage({super.key});

  @override
  State<SheikhDashboardPage> createState() => _SheikhDashboardPageState();
}

class _SheikhDashboardPageState extends State<SheikhDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<SheikhDashboardBloc>().add(const LoadLessonRequests());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheikh Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: KhairColors.primary,
          unselectedLabelColor:
              isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary,
          indicatorColor: KhairColors.primary,
          isScrollable: false,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 20), text: 'Overview'),
            Tab(icon: Icon(Icons.school_rounded, size: 20), text: 'Requests'),
            Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Students'),
            Tab(icon: Icon(Icons.chat_rounded, size: 20), text: 'Messages'),
          ],
        ),
      ),
      body: BlocConsumer<SheikhDashboardBloc, SheikhDashboardState>(
        listener: (context, state) {
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.actionMessage!),
                  backgroundColor: KhairColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: KhairColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
          }
        },
        builder: (context, state) {
          if (state.status == SheikhDashboardStatus.loading &&
              state.requests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(state, isDark),
              _buildRequestsTab(state, isDark),
              _buildStudentsTab(state, isDark),
              _buildMessagesTab(isDark),
            ],
          );
        },
      ),
    );
  }

  // ─── Overview Tab ──────────────────────────────────

  Widget _buildOverviewTab(SheikhDashboardState state, bool isDark) {
    return RefreshIndicator(
      color: KhairColors.primary,
      onRefresh: () async {
        context.read<SheikhDashboardBloc>().add(const LoadLessonRequests());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B5F50), Color(0xFF2D8E75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: KhairTypography.bodyMedium.copyWith(
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sheikh Dashboard',
                              style: KhairTypography.h2
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            Text('Activity Overview',
                style: KhairTypography.headlineSmall.copyWith(
                  color: isDark
                      ? KhairColors.darkTextPrimary
                      : KhairColors.textPrimary,
                )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Requests',
                    value: '${state.requests.length}',
                    icon: Icons.inbox_rounded,
                    color: KhairColors.primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Pending',
                    value: '${state.pendingRequests.length}',
                    icon: Icons.pending_rounded,
                    color: KhairColors.warning,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Accepted',
                    value: '${state.acceptedRequests.length}',
                    icon: Icons.check_circle_rounded,
                    color: KhairColors.success,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Declined',
                    value: '${state.rejectedRequests.length}',
                    icon: Icons.cancel_rounded,
                    color: KhairColors.error,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Pending
            if (state.pendingRequests.isNotEmpty) ...[
              Text('Pending Requests',
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  )),
              const SizedBox(height: 12),
              ...state.pendingRequests.take(3).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RequestCard(
                        request: r,
                        isDark: isDark,
                        onAccept: () => _respondToRequest(r.id, 'accepted'),
                        onReject: () => _respondToRequest(r.id, 'rejected'),
                      ),
                    ),
                  ),
              if (state.pendingRequests.length > 3)
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text('View all ${state.pendingRequests.length} requests'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Requests Tab ──────────────────────────────────

  Widget _buildRequestsTab(SheikhDashboardState state, bool isDark) {
    return RefreshIndicator(
      color: KhairColors.primary,
      onRefresh: () async {
        context.read<SheikhDashboardBloc>().add(const LoadLessonRequests());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: state.requests.isEmpty
          ? _buildEmptyState(
              icon: Icons.school_outlined,
              title: 'No Lesson Requests Yet',
              subtitle: 'When students request lessons, they will appear here.',
              isDark: isDark,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: state.requests.length,
              itemBuilder: (context, index) {
                final request = state.requests[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(
                    request: request,
                    isDark: isDark,
                    showStatus: true,
                    onAccept: request.isPending
                        ? () => _respondToRequest(request.id, 'accepted')
                        : null,
                    onReject: request.isPending
                        ? () => _respondToRequest(request.id, 'rejected')
                        : null,
                    onSchedule: request.isAccepted
                        ? () => _showScheduleDialog(request.id)
                        : null,
                  ),
                );
              },
            ),
    );
  }

  // ─── Students Tab ──────────────────────────────────

  Widget _buildStudentsTab(SheikhDashboardState state, bool isDark) {
    final students = state.acceptedRequests;

    if (students.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No Students Yet',
        subtitle: 'Once you accept lesson requests, your students will appear here.',
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      color: KhairColors.primary,
      onRefresh: () async {
        context.read<SheikhDashboardBloc>().add(const LoadLessonRequests());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _StudentCard(
              request: student,
              isDark: isDark,
              onMessage: () => context.go('/conversations'),
              onSchedule: () => _showScheduleDialog(student.id),
            ),
          );
        },
      ),
    );
  }

  // ─── Messages Tab ──────────────────────────────────

  Widget _buildMessagesTab(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KhairColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: KhairColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Conversations',
              style: KhairTypography.headlineSmall.copyWith(
                color: isDark
                    ? KhairColors.darkTextPrimary
                    : KhairColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat with your students after accepting their lesson requests.',
              textAlign: TextAlign.center,
              style: KhairTypography.bodyMedium.copyWith(
                color: isDark
                    ? KhairColors.darkTextSecondary
                    : KhairColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/conversations'),
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: const Text('Open Chats'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Schedule Dialog ───────────────────────────────

  void _showScheduleDialog(String requestId) {
    final linkController = TextEditingController();
    String platform = 'Zoom';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Schedule Lesson'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: platform,
                decoration: InputDecoration(
                  labelText: 'Platform',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Zoom', 'Google Meet', 'Microsoft Teams', 'Other']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  setModalState(() => platform = val!);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: linkController,
                decoration: InputDecoration(
                  labelText: 'Meeting Link',
                  hintText: 'https://zoom.us/j/...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (linkController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                context.read<SheikhDashboardBloc>().add(ScheduleLesson(
                      requestId: requestId,
                      meetingLink: linkController.text.trim(),
                      meetingPlatform: platform,
                      scheduledTime: DateTime.now()
                          .add(const Duration(days: 1))
                          .toUtc()
                          .toIso8601String(),
                    ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: KhairColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────

  void _respondToRequest(String id, String status) {
    context
        .read<SheikhDashboardBloc>()
        .add(RespondToRequest(requestId: id, status: status));
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark
                        ? KhairColors.darkSurfaceVariant
                        : KhairColors.surfaceVariant),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: KhairColors.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: KhairTypography.headlineSmall.copyWith(
                  color: isDark
                      ? KhairColors.darkTextPrimary
                      : KhairColors.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: KhairTypography.bodyMedium.copyWith(
                color: isDark
                    ? KhairColors.darkTextSecondary
                    : KhairColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card Widget ─────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: KhairTypography.h2.copyWith(
              color: isDark
                  ? KhairColors.darkTextPrimary
                  : KhairColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: KhairTypography.bodySmall.copyWith(
              color: isDark
                  ? KhairColors.darkTextSecondary
                  : KhairColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Request Card Widget ──────────────────────────

class _RequestCard extends StatelessWidget {
  final LessonRequest request;
  final bool isDark;
  final bool showStatus;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onSchedule;

  const _RequestCard({
    required this.request,
    required this.isDark,
    this.showStatus = false,
    this.onAccept,
    this.onReject,
    this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: KhairColors.primary.withAlpha(25),
                child: Text(
                  (request.studentName ?? 'S')[0].toUpperCase(),
                  style: TextStyle(
                    color: KhairColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.studentName ?? 'Student',
                      style: KhairTypography.labelLarge.copyWith(
                        color: isDark
                            ? KhairColors.darkTextPrimary
                            : KhairColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM dd, yyyy').format(request.createdAt),
                      style: KhairTypography.bodySmall.copyWith(
                        color: isDark
                            ? KhairColors.darkTextSecondary
                            : KhairColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (showStatus) _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.message,
            style: KhairTypography.bodyMedium.copyWith(
              color: isDark
                  ? KhairColors.darkTextSecondary
                  : KhairColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (request.preferredTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: KhairColors.info),
                const SizedBox(width: 4),
                Text(
                  'Preferred: ${DateFormat('MMM dd, HH:mm').format(request.preferredTime!)}',
                  style: KhairTypography.bodySmall.copyWith(
                    color: KhairColors.info,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (onAccept != null || onReject != null || onSchedule != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: KhairColors.error.withAlpha(100)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Decline',
                            style: TextStyle(
                                color: KhairColors.error, fontSize: 13)),
                      ),
                    ),
                  ),
                if (onAccept != null && onReject != null)
                  const SizedBox(width: 10),
                if (onAccept != null)
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KhairColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                if (onSchedule != null)
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: onSchedule,
                        icon: const Icon(Icons.video_call_rounded, size: 18),
                        label: const Text('Schedule',
                            style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KhairColors.info,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;
    if (request.isPending) {
      color = KhairColors.warning;
      label = 'Pending';
    } else if (request.isAccepted) {
      color = KhairColors.success;
      label = 'Accepted';
    } else {
      color = KhairColors.error;
      label = 'Declined';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Student Card Widget ──────────────────────────

class _StudentCard extends StatelessWidget {
  final LessonRequest request;
  final bool isDark;
  final VoidCallback onMessage;
  final VoidCallback onSchedule;

  const _StudentCard({
    required this.request,
    required this.isDark,
    required this.onMessage,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: KhairColors.primary.withAlpha(25),
            child: Text(
              (request.studentName ?? 'S')[0].toUpperCase(),
              style: TextStyle(
                color: KhairColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.studentName ?? 'Student',
                  style: KhairTypography.labelLarge.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accepted ${DateFormat('MMM dd').format(request.updatedAt)}',
                  style: KhairTypography.bodySmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextSecondary
                        : KhairColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chat_rounded, color: KhairColors.primary),
            onPressed: onMessage,
            tooltip: 'Message',
          ),
          IconButton(
            icon: Icon(Icons.video_call_rounded, color: KhairColors.info),
            onPressed: onSchedule,
            tooltip: 'Schedule',
          ),
        ],
      ),
    );
  }
}
