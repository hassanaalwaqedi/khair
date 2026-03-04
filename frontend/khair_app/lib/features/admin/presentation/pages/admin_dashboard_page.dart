import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: Text(
          'Admin Dashboard',
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
          tabs: const [
            Tab(text: 'Organizers'),
            Tab(text: 'Events'),
            Tab(text: 'Reports'),
            Tab(text: 'Audit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrganizersTab(isDark),
          _buildEventsTab(isDark),
          _buildReportsTab(isDark),
          _buildAuditLogsTab(isDark),
        ],
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
          Text('Reports Management', style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          )),
          const SizedBox(height: 8),
          Text('Review and resolve user reports',
              style: KhairTypography.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/admin/reports'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Reports'),
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
          Text('Audit Logs', style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          )),
          const SizedBox(height: 8),
          Text('View all admin and system actions',
              style: KhairTypography.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/admin/audit-logs'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('View Logs'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizersTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pending Approval',
          style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildOrganizerCard(
          name: 'Tech Events Co.',
          email: 'info@techevents.com',
          status: 'pending',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildOrganizerCard(
          name: 'Community Hub',
          email: 'contact@communityhub.org',
          status: 'pending',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildEventsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pending Review',
          style: KhairTypography.headlineSmall.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildEventCard(
          title: 'Quran Study Circle',
          organizer: 'Al-Khair Community',
          date: 'March 15, 2026',
          status: 'pending',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildEventCard(
          title: 'Islamic Youth Workshop',
          organizer: 'Community Hub',
          date: 'April 20, 2026',
          status: 'pending',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildOrganizerCard({
    required String name,
    required String email,
    required String status,
    required bool isDark,
  }) {
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
                    Text(name, style: KhairTypography.labelLarge.copyWith(
                      color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 2),
                    Text(email, style: KhairTypography.bodySmall),
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
                  status.toUpperCase(),
                  style: KhairTypography.labelSmall.copyWith(
                    color: KhairColors.warningDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog('organizer', name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KhairColors.error,
                    side: const BorderSide(color: KhairColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveOrganizer(name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KhairColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard({
    required String title,
    required String organizer,
    required String date,
    required String status,
    required bool isDark,
  }) {
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
                    Text(title, style: KhairTypography.labelLarge.copyWith(
                      color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 2),
                    Text('by $organizer', style: KhairTypography.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 14, color: KhairColors.textTertiary),
              const SizedBox(width: 6),
              Text(date, style: KhairTypography.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog('event', title),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KhairColors.error,
                    side: const BorderSide(color: KhairColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveEvent(title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KhairColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: KhairRadius.medium,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _approveOrganizer(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name has been approved')),
    );
  }

  void _approveEvent(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title has been approved')),
    );
  }

  void _showRejectDialog(String type, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject $type'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject "$name"?'),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Rejection reason',
                hintText: 'Provide a reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name has been rejected')),
              );
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
