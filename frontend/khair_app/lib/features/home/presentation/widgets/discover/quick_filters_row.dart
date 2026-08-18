import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../tokens/tokens.dart';
import '../../../../events/domain/entities/event.dart';
import '../../../../events/presentation/bloc/events_bloc.dart';

/// The quick-filter values available on Discover.
enum QuickFilter { today, weekend, nearby, free, online }

class QuickFiltersRow extends StatelessWidget {
  const QuickFiltersRow({super.key, required this.onTap});
  final ValueChanged<QuickFilter> onTap;

  @override
  Widget build(BuildContext context) => BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) => SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: QuickFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = QuickFilter.values[index];
              final selected = switch (filter) {
                QuickFilter.today =>
                  state.filter.dateFilter == DateFilter.today,
                QuickFilter.weekend =>
                  state.filter.dateFilter == DateFilter.thisWeekend,
                QuickFilter.nearby => false,
                QuickFilter.free => state.filter.freeOnly,
                QuickFilter.online => state.filter.onlineOnly,
              };
              return _QuickFilterChip(
                filter: filter,
                selected: selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(filter);
                },
              );
            },
          ),
        ),
      );
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });
  final QuickFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (filter) {
      QuickFilter.today => ('Today', Icons.calendar_today_outlined),
      QuickFilter.weekend => ('This weekend', Icons.weekend_outlined),
      QuickFilter.nearby => ('Near me', Icons.near_me_outlined),
      QuickFilter.free => ('Free', Icons.sell_outlined),
      QuickFilter.online => ('Online', Icons.videocam_outlined),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsetsDirectional.fromSTEB(13, 0, 14, 0),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 17,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                    color:
                        selected ? AppColors.primaryDark : AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
