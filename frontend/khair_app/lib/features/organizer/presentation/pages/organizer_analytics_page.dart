import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_components.dart';

import '../bloc/organizer_bloc.dart';
import '../widgets/dashboard_widgets.dart';

/// Lightweight analytics page for organizer – computes stats from events.
/// No separate analytics API needed; derived from getMyEvents response.
class OrganizerAnalyticsPage extends StatefulWidget {
  const OrganizerAnalyticsPage({super.key});

  @override
  State<OrganizerAnalyticsPage> createState() => _OrganizerAnalyticsPageState();
}

class _OrganizerAnalyticsPageState extends State<OrganizerAnalyticsPage> {
  @override
  void initState() {
    super.initState();
    final state = context.read<OrganizerBloc>().state;
    if (state.events.isEmpty) {
      context.read<OrganizerBloc>().add(const LoadOrganizerEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: BlocBuilder<OrganizerBloc, OrganizerState>(
        builder: (context, state) {
          if (state.isEventsLoading && state.events.isEmpty) {
            return const KhairLoadingState(message: 'Loading analytics...');
          }

          if (state.eventsStatus == OrganizerStatus.failure &&
              state.events.isEmpty) {
            return KhairErrorState(
              message:
                  state.errorMessage ?? 'Failed to load analytics data.',
              onRetry: () {
                context
                    .read<OrganizerBloc>()
                    .add(const LoadOrganizerEvents());
              },
            );
          }

          final events = state.events;
          final total = events.length;
          final approved =
              events.where((e) => e.status == 'approved').length;
          final pending =
              events.where((e) => e.status == 'pending').length;
          final rejected =
              events.where((e) => e.status == 'rejected').length;

          // Group events by type
          final typeMap = <String, int>{};
          for (final event in events) {
            typeMap[event.eventType] =
                (typeMap[event.eventType] ?? 0) + 1;
          }

          // Upcoming events
          final now = DateTime.now();
          final upcoming =
              events.where((e) => e.startDate.isAfter(now)).length;
          final past =
              events.where((e) => e.startDate.isBefore(now)).length;

          return RefreshIndicator(
            color: KhairColors.primary,
            onRefresh: () async {
              context
                  .read<OrganizerBloc>()
                  .add(const LoadOrganizerEvents());
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overview', style: KhairTypography.h3),
                  const SizedBox(height: 16),

                  // Main stat cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 500;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(
                              child: AnimatedStatCard(
                                label: 'Total Events',
                                value: total,
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
                                  label: 'Total Events',
                                  value: total,
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
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
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Timeline section
                  Text('Timeline', style: KhairTypography.h3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedStatCard(
                          label: 'Upcoming',
                          value: upcoming,
                          icon: Icons.upcoming_rounded,
                          color: KhairColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedStatCard(
                          label: 'Past',
                          value: past,
                          icon: Icons.history_rounded,
                          color: KhairColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Events by type
                  Text('Events by Type', style: KhairTypography.h3),
                  const SizedBox(height: 16),

                  if (typeMap.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? KhairColors.darkSurfaceVariant
                            : KhairColors.surfaceVariant,
                        borderRadius: KhairRadius.medium,
                      ),
                      child: Center(
                        child: Text(
                          'No event data to display',
                          style: KhairTypography.bodyMedium.copyWith(
                            color: KhairColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...typeMap.entries.map((entry) {
                      final fraction =
                          total > 0 ? entry.value / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? KhairColors.darkCard
                                : KhairColors.surface,
                            borderRadius: KhairRadius.medium,
                            border: Border.all(
                              color: isDark
                                  ? KhairColors.darkBorder
                                  : KhairColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatEventType(entry.key),
                                    style: KhairTypography.labelLarge,
                                  ),
                                  Text(
                                    '${entry.value} event${entry.value == 1 ? '' : 's'}',
                                    style: KhairTypography.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  backgroundColor: isDark
                                      ? KhairColors.darkSurfaceVariant
                                      : KhairColors.neutral200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    KhairColors.primary,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatEventType(String type) {
    return type
        .split('_')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
