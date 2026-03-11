import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/widgets/khair_components.dart';
import '../../domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../../../spiritual_quotes/domain/entities/spiritual_quote.dart';
import '../../../spiritual_quotes/presentation/widgets/spiritual_quote_section.dart';
import '../bloc/organizer_bloc.dart';
import '../widgets/dashboard_widgets.dart';

/// Organizer Dashboard – Production-grade SaaS panel.
/// Uses real data from OrganizerBloc with proper loading, error, and empty states.
class OrganizerDashboardPage extends StatefulWidget {
  const OrganizerDashboardPage({super.key});

  @override
  State<OrganizerDashboardPage> createState() => _OrganizerDashboardPageState();
}

class _OrganizerDashboardPageState extends State<OrganizerDashboardPage> {
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() {
    final bloc = context.read<OrganizerBloc>();
    bloc.add(const LoadOrganizerProfile());
    bloc.add(const LoadOrganizerEvents());
    bloc.add(const LoadAdminMessages());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: BlocBuilder<OrganizerBloc, OrganizerState>(
        builder: (context, state) {
          // Full loading state → shimmer
          if (state.isProfileLoading && state.organizer == null) {
            return const DashboardShimmer();
          }

          // Error loading profile (first load)
          if (state.profileStatus == OrganizerStatus.failure &&
              state.organizer == null) {
            // Check if user hasn't registered as organizer yet
            final msg = state.errorMessage ?? '';
            if (msg.contains('no rows') || msg.contains('not found') || msg.contains('Profile not found')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: KhairColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.business_rounded,
                            size: 40, color: KhairColors.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(context.l10n.orgBecomeOrganizer,
                          style: KhairTypography.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.orgRegisterPrompt,
                        textAlign: TextAlign.center,
                        style: KhairTypography.bodyMedium.copyWith(
                          color: KhairColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      KhairButton(
                        label: context.l10n.orgRegisterBtn,
                        onPressed: () => context.go('/organizer/apply'),
                        icon: Icons.add_business_rounded,
                      ),
                    ],
                  ),
                ),
              );
            }
            return KhairErrorState(
              message: state.errorMessage ??
                  'Failed to load dashboard. Please try again.',
              onRetry: _loadDashboardData,
            );
          }

          return RefreshIndicator(
            color: KhairColors.primary,
            onRefresh: () async {
              _loadDashboardData();
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildMainContent(state),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 1,
                              child: _buildSidebar(state),
                            ),
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
          );
        },
      ),
    );
  }

  // ─── App Bar ────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: BlocBuilder<OrganizerBloc, OrganizerState>(
        buildWhen: (prev, curr) => prev.organizer != curr.organizer,
        builder: (context, state) {
          return Text(
              state.organizer != null ? context.l10n.orgDashboardTitle : context.l10n.orgOrganizerDashboard);
        },
      ),
      actions: [
        BlocBuilder<OrganizerBloc, OrganizerState>(
          buildWhen: (prev, curr) =>
              prev.unreadMessageCount != curr.unreadMessageCount,
          builder: (context, state) {
            final count = state.unreadMessageCount;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showNotifications(context),
                  tooltip: context.l10n.orgNotifications,
                ),
                if (count > 0)
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
                        count > 9 ? '9+' : count.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/profile'),
          tooltip: context.l10n.orgSettings,
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A2E)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.orgNotifications,
                    style: KhairTypography.headlineSmall.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? KhairColors.darkTextPrimary
                          : KhairColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 48, color: KhairColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(context.l10n.orgCheckHomeNotif,
                      style: KhairTypography.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Content ──────────────────────────────────

  Widget _buildMainContent(OrganizerState state) {
    final organizer = state.organizer;
    final isApproved = organizer?.isApproved ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RBAC Banner
        if (organizer != null && !organizer.isApproved)
          RBACBanner(
            status: organizer.status,
            rejectionReason: organizer.rejectionReason,
          ),

        // Welcome Header
        _buildWelcomeHeader(organizer),
        const SizedBox(height: 24),
        const SpiritualQuoteSection(
          location: QuoteLocation.dashboard,
          compact: true,
        ),
        const SizedBox(height: 24),

        // Quick Actions
        Text(context.l10n.orgQuickActions, style: KhairTypography.headlineSmall),
        const SizedBox(height: 16),
        _buildQuickActions(isApproved),
        const SizedBox(height: 32),

        // Analytics Summary
        Text(context.l10n.orgAnalytics, style: KhairTypography.headlineSmall),
        const SizedBox(height: 16),
        _buildAnalyticsSummary(state),
        const SizedBox(height: 32),

        // Recent Events
        SectionHeader(
          title: context.l10n.orgRecentEvents,
          subtitle: context.l10n.orgTotalCount(state.events.length),
          action: TextButton.icon(
            onPressed: () => context.go('/organizer/events'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(context.l10n.orgViewAll),
          ),
        ),
        const SizedBox(height: 8),
        _buildRecentEvents(state),
      ],
    );
  }

  // ─── Welcome Header ────────────────────────────────

  Widget _buildWelcomeHeader(Organizer? organizer) {
    if (organizer == null) {
      return const ShimmerLoading(height: 120, borderRadius: 20);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: organizer.isApproved
              ? [KhairColors.primary, KhairColors.primaryDark]
              : organizer.isPending
                  ? [KhairColors.warning, KhairColors.warningDark]
                  : [KhairColors.error, KhairColors.errorDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: KhairRadius.large,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.business_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.orgWelcomeBack,
                  style: KhairTypography.bodyMedium.copyWith(
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  organizer.name,
                  style: KhairTypography.h2.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
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
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  organizer.status.toUpperCase(),
                  style: KhairTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────

  Widget _buildQuickActions(bool isApproved) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.15,
          children: [
            DashboardCard(
              icon: Icons.add_circle_outline_rounded,
              title: context.l10n.orgCreateEvent,
              subtitle: isApproved ? context.l10n.orgAddNewEvent : context.l10n.orgApprovalRequired,
              disabled: !isApproved,
              iconColor: KhairColors.primary,
              onTap: () => context.go('/organizer/events/create'),
            ),
            DashboardCard(
              icon: Icons.list_alt_rounded,
              title: context.l10n.orgMyEvents,
              subtitle: context.l10n.orgViewAllEvents,
              iconColor: KhairColors.info,
              onTap: () => context.go('/organizer/events'),
            ),
            DashboardCard(
              icon: Icons.person_outline_rounded,
              title: context.l10n.orgEditProfile,
              subtitle: context.l10n.orgUpdateInfo,
              iconColor: KhairColors.secondary,
              onTap: () => context.go('/organizer/profile'),
            ),
            DashboardCard(
              icon: Icons.analytics_outlined,
              title: context.l10n.orgAnalytics,
              subtitle: context.l10n.orgViewStats,
              iconColor: KhairColors.accent,
              onTap: () => context.go('/organizer/analytics'),
            ),
          ],
        );
      },
    );
  }

  // ─── Analytics Summary ─────────────────────────────

  Widget _buildAnalyticsSummary(OrganizerState state) {
    if (state.isEventsLoading && state.events.isEmpty) {
      return Row(
        children: List.generate(
          4,
          (_) => const Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: ShimmerLoading(height: 100),
            ),
          ),
        ),
      );
    }

    final events = state.events;
    final approved = events.where((e) => e.status == 'approved').length;
    final pending = events.where((e) => e.status == 'pending').length;
    final rejected = events.where((e) => e.status == 'rejected').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: AnimatedStatCard(
                  label: 'Total Events',
                  value: events.length,
                  icon: Icons.event_rounded,
                  color: KhairColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedStatCard(
                  label: 'Approved',
                  value: approved,
                  icon: Icons.check_circle_rounded,
                  color: KhairColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedStatCard(
                  label: 'Pending',
                  value: pending,
                  icon: Icons.pending_rounded,
                  color: KhairColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedStatCard(
                  label: 'Rejected',
                  value: rejected,
                  icon: Icons.cancel_rounded,
                  color: KhairColors.error,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AnimatedStatCard(
                    label: context.l10n.orgTotalEvents,
                    value: events.length,
                    icon: Icons.event_rounded,
                    color: KhairColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStatCard(
                    label: context.l10n.orgApproved,
                    value: approved,
                    icon: Icons.check_circle_rounded,
                    color: KhairColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AnimatedStatCard(
                    label: context.l10n.orgPending,
                    value: pending,
                    icon: Icons.pending_rounded,
                    color: KhairColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStatCard(
                    label: context.l10n.orgRejected,
                    value: rejected,
                    icon: Icons.cancel_rounded,
                    color: KhairColors.error,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ─── Recent Events ─────────────────────────────────

  Widget _buildRecentEvents(OrganizerState state) {
    if (state.isEventsLoading && state.events.isEmpty) {
      return Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerLoading(height: 72),
          ),
        ),
      );
    }

    if (state.events.isEmpty) {
      return _buildEmptyEvents();
    }

    // Show at most 5 recent events
    final recentEvents = state.events.take(5).toList();

    return Column(
      children: recentEvents
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEventCard(event),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyEvents() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark
            ? KhairColors.darkSurfaceVariant
            : KhairColors.surfaceVariant,
        borderRadius: KhairRadius.medium,
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined,
              size: 48, color: KhairColors.textTertiary),
          const SizedBox(height: 16),
          Text(context.l10n.orgNoEventsYet, style: KhairTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(
            context.l10n.orgCreateFirstEvent,
            style: KhairTypography.bodyMedium.copyWith(
              color: KhairColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          KhairButton(
            label: context.l10n.orgCreateEvent,
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
                  StatusBadge(status: _mapEventStatus(event.status)),
                ],
              ),
            ),
            PopupMenuButton(
              icon:
                  const Icon(Icons.more_vert, color: KhairColors.textTertiary),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
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

  // ─── Sidebar ───────────────────────────────────────

  Widget _buildSidebar(OrganizerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Admin Messages
        SectionHeader(title: context.l10n.orgMessages),
        const SizedBox(height: 8),

        if (state.isMessagesLoading && state.messages.isEmpty)
          Column(
            children: List.generate(
              2,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(height: 80),
              ),
            ),
          )
        else if (state.messages.isEmpty)
          _buildEmptyMessages()
        else
          ...state.messages.take(5).map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMessageCard(msg),
              )),
      ],
    );
  }

  Widget _buildEmptyMessages() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? KhairColors.darkSurfaceVariant
            : KhairColors.surfaceVariant,
        borderRadius: KhairRadius.medium,
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: KhairColors.textTertiary),
          const SizedBox(width: 12),
          Text(
            context.l10n.orgNoMessages,
            style: KhairTypography.bodyMedium.copyWith(
              color: KhairColors.textSecondary,
            ),
          ),
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
          color: message.isRead
              ? KhairColors.surfaceVariant
              : KhairColors.infoLight,
          borderRadius: KhairRadius.medium,
          border: Border.all(
            color: message.isRead
                ? KhairColors.border
                : KhairColors.info.withAlpha(50),
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
                  color: message.isRead
                      ? KhairColors.textTertiary
                      : KhairColors.info,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(message.createdAt),
                  style: KhairTypography.labelSmall.copyWith(
                    color: message.isRead
                        ? KhairColors.textTertiary
                        : KhairColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.subject,
              style: KhairTypography.labelMedium.copyWith(
                fontWeight:
                    message.isRead ? FontWeight.normal : FontWeight.bold,
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

  // ─── Helpers ───────────────────────────────────────

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

  String _formatDate(DateTime date) {
    return '${_monthAbbr(date.month)} ${date.day}, ${date.year}';
  }
}
