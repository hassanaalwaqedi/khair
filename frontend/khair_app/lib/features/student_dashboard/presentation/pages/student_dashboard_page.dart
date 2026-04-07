import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/student_dashboard_bloc.dart';
import '../widgets/stats_header.dart';
import '../widgets/lesson_card.dart';
import '../widgets/request_card.dart';
import '../widgets/sheikh_card.dart';

/// Student Dashboard — "My Learning" page.
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<StudentDashboardBloc>().add(const LoadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BlocConsumer<StudentDashboardBloc, StudentDashboardState>(
        listener: (context, state) {
          if (state.reviewMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_localizeMessage(context, state.reviewMessage!)),
              ),
            );
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: KhairColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == DashboardStatus.loading &&
              state.upcomingLessons.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == DashboardStatus.error &&
              state.upcomingLessons.isEmpty) {
            return _buildErrorState(context, state.errorMessage);
          }

          return _buildDashboard(context, state, isDark);
        },
      ),
    );
  }

  Widget _buildDashboard(
      BuildContext context, StudentDashboardState state, bool isDark) {
    final authState = context.watch<AuthBloc>().state;
    final email = authState.user?.email ?? '';

    final lessonsCompleted = (state.stats['lessons_completed'] as int?) ?? 0;
    final upcomingCount = (state.stats['upcoming_count'] as int?) ?? 0;
    final pendingRequests = (state.stats['pending_requests'] as int?) ?? 0;

    final tabs = [
      context.l10n.upcomingTab,
      context.l10n.requestsTab,
      context.l10n.historyTab,
      context.l10n.sheikhsTab,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StudentDashboardBloc>().add(const LoadDashboard());
        // Wait a bit for data to load
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Safe area top spacing
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.top + 16,
            ),
          ),

          // Stats header
          SliverToBoxAdapter(
            child: StatsHeader(
              userEmail: email,
              lessonsCompleted: lessonsCompleted,
              upcomingCount: upcomingCount,
              pendingRequests: pendingRequests,
            ),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabs: tabs,
              selectedIndex: state.selectedTab,
              isDark: isDark,
              onTap: (i) =>
                  context.read<StudentDashboardBloc>().add(ChangeTab(i)),
            ),
          ),

          // Tab content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            sliver: _buildTabContent(context, state),
          ),
        ],
      ),
    );
  }

  SliverList _buildTabContent(
      BuildContext context, StudentDashboardState state) {
    switch (state.selectedTab) {
      case 0:
        return _buildUpcomingList(context, state);
      case 1:
        return _buildRequestsList(context, state);
      case 2:
        return _buildHistoryList(context, state);
      case 3:
        return _buildSheikhsList(context, state);
      default:
        return _buildUpcomingList(context, state);
    }
  }

  SliverList _buildUpcomingList(
      BuildContext context, StudentDashboardState state) {
    if (state.upcomingLessons.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _EmptyTab(
            icon: Icons.event_available_rounded,
            message: context.l10n.noUpcomingLessons,
          ),
        ]),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final booking = state.upcomingLessons[index];
          return LessonCard(
            booking: booking,
            isUpcoming: true,
            onCancel: () => _confirmCancel(context, booking),
          );
        },
        childCount: state.upcomingLessons.length,
      ),
    );
  }

  SliverList _buildRequestsList(
      BuildContext context, StudentDashboardState state) {
    if (state.lessonRequests.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _EmptyTab(
            icon: Icons.inbox_rounded,
            message: context.l10n.noRequests,
          ),
        ]),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final request = state.lessonRequests[index];
          return RequestCard(request: request);
        },
        childCount: state.lessonRequests.length,
      ),
    );
  }

  SliverList _buildHistoryList(
      BuildContext context, StudentDashboardState state) {
    if (state.pastLessons.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _EmptyTab(
            icon: Icons.history_rounded,
            message: context.l10n.noHistory,
          ),
        ]),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final booking = state.pastLessons[index];
          return LessonCard(
            booking: booking,
            isUpcoming: false,
            onRate: () => _showRateDialog(context, booking),
          );
        },
        childCount: state.pastLessons.length,
      ),
    );
  }

  SliverList _buildSheikhsList(
      BuildContext context, StudentDashboardState state) {
    if (state.mySheikhs.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _EmptyTab(
            icon: Icons.people_outline_rounded,
            message: context.l10n.noSheikhs,
          ),
        ]),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final sheikh = state.mySheikhs[index];
          return SheikhCard(sheikh: sheikh);
        },
        childCount: state.mySheikhs.length,
      ),
    );
  }

  void _confirmCancel(BuildContext context, Map<String, dynamic> booking) {
    final id = booking['id'] as String?;
    if (id == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.cancelLesson),
        content: Text(context.l10n.cancelLessonConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.no),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<StudentDashboardBloc>()
                  .add(CancelStudentBooking(id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.yes),
          ),
        ],
      ),
    );
  }

  void _showRateDialog(BuildContext context, Map<String, dynamic> booking) {
    final sheikhId = booking['sheikh_id'] as String?;
    if (sheikhId == null) return;
    final sheikhName =
        (booking['sheikh_name'] as String?)?.trim().isNotEmpty == true
            ? (booking['sheikh_name'] as String).trim()
            : context.l10n.sheikhDefaultName;

    int rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('${context.l10n.rateSheikh}: $sheikhName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = i + 1),
                    icon: Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: KhairColors.warning,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.writeReview,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () {
                      Navigator.pop(ctx);
                      context.read<StudentDashboardBloc>().add(
                            SubmitSheikhReview(
                              sheikhId: sheikhId,
                              rating: rating,
                              comment: commentController.text.isNotEmpty
                                  ? commentController.text
                                  : null,
                            ),
                          );
                    }
                  : null,
              child: Text(context.l10n.submit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message ?? context.l10n.discoverSomethingWentWrong,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<StudentDashboardBloc>()
                  .add(const LoadDashboard()),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  String _localizeMessage(BuildContext context, String message) {
    switch (message) {
      case 'sheikhReviewSubmitted':
        return context.l10n.sheikhReviewSubmitted;
      default:
        return message;
    }
  }
}

// ── Tab Bar Delegate ──

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  _TabBarDelegate({
    required this.tabs,
    required this.selectedIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bg = isDark ? KhairColors.darkBackground : KhairColors.background;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final selected = i == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: KhairAnimations.fast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? KhairColors.primary
                        : (isDark
                            ? KhairColors.darkCard
                            : KhairColors.surfaceVariant),
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? null
                        : Border.all(
                            color: isDark
                                ? KhairColors.darkBorder
                                : KhairColors.border,
                          ),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? KhairColors.darkTextSecondary
                              : KhairColors.textSecondary),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}

// ── Empty Tab State ──

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color:
                    isDark ? KhairColors.darkCard : KhairColors.surfaceVariant,
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(icon, size: 32, color: KhairColors.neutral400),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: KhairTypography.bodyMedium.copyWith(
                color: isDark
                    ? KhairColors.darkTextSecondary
                    : KhairColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
