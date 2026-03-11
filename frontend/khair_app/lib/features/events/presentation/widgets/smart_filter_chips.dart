import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/locale/l10n_extension.dart';

import '../../../../tokens/tokens.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../domain/entities/event.dart';
import '../bloc/events_bloc.dart';
import 'islamic_category_chip.dart';

class SmartFilterChips extends StatelessWidget {
  const SmartFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventsBloc, EventsState>(
      buildWhen: (previous, current) => previous.filter != current.filter,
      builder: (context, state) {
        return SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
            children: [
              _locationChip(context),
              const SizedBox(width: AppSpacing.x1),
              ..._categoryChips(context, state.filter),
              const SizedBox(width: AppSpacing.x1),
              _dateChip(context, state.filter),
              const SizedBox(width: AppSpacing.x1),
              IslamicCategoryChip(
                label: context.l10n.categoryTrending,
                emoji: '🔥',
                isSelected: state.filter.trending,
                onTap: () => context.read<EventsBloc>().add(ToggleTrending()),
              ),
              if (state.filter.hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.x1),
                _clearChip(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _locationChip(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        if (locationState is LocationLoaded) {
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Text(
              '📍 ${locationState.location.city}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Text(
            '📍 ${context.l10n.filterEventsLocating}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      },
    );
  }

  List<Widget> _categoryChips(BuildContext context, EventFilter filter) {
    final l10n = context.l10n;
    final categories = [
      (key: 'knowledge', label: l10n.categoryKnowledge, emoji: '📚'),
      (key: 'quran', label: l10n.categoryQuran, emoji: '🕌'),
      (key: 'lectures', label: l10n.categoryLectures, emoji: '🎤'),
      (key: 'community', label: l10n.categoryCommunity, emoji: '👥'),
      (key: 'youth', label: l10n.categoryYouth, emoji: '🌱'),
      (key: 'charity', label: l10n.categoryCharity, emoji: '🤲'),
      (key: 'family', label: l10n.categoryFamily, emoji: '👨‍👩‍👧'),
    ];

    return categories
        .map(
          (category) => Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.x1),
            child: IslamicCategoryChip(
              label: category.label,
              emoji: category.emoji,
              isSelected: filter.eventType == category.key,
              onTap: () {
                context.read<EventsBloc>().add(
                      UpdateCategoryFilter(
                        filter.eventType == category.key ? null : category.key,
                      ),
                    );
              },
            ),
          ),
        )
        .toList();
  }

  Widget _dateChip(BuildContext context, EventFilter filter) {
    final l10n = context.l10n;
    final label = switch (filter.dateFilter) {
      DateFilter.today => '📅 ${l10n.filterEventsToday}',
      DateFilter.thisWeek => '📅 ${l10n.filterEventsThisWeek}',
      DateFilter.thisWeekend => '📅 ${l10n.filterEventsWeekend}',
      DateFilter.thisMonth => '📅 ${l10n.filterEventsThisMonth}',
      null => '📅 ${l10n.filterEventsDate}',
    };

    return GestureDetector(
      onTap: () => _showDatePicker(context, filter.dateFilter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: filter.dateFilter != null
              ? Colors.white.withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: filter.dateFilter != null
                ? Colors.white
                : Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: filter.dateFilter != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: filter.dateFilter != null
                    ? AppColors.primary
                    : Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  Widget _clearChip(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<EventsBloc>().add(ClearAllFilters()),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: const Color(0xFFFDE7E4),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Text(
          '✖ ${context.l10n.filterEventsClear}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, DateFilter? current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.filterEventsByDate,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.x2),
              _DateOption(
                selected: current == DateFilter.today,
                label: '📅 ${context.l10n.filterEventsToday}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.today));
                  Navigator.pop(context);
                },
              ),
              _DateOption(
                selected: current == DateFilter.thisWeek,
                label: '📅 ${context.l10n.filterEventsThisWeek}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.thisWeek));
                  Navigator.pop(context);
                },
              ),
              _DateOption(
                selected: current == DateFilter.thisWeekend,
                label: '📅 ${context.l10n.filterEventsWeekend}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.thisWeekend));
                  Navigator.pop(context);
                },
              ),
              _DateOption(
                selected: current == DateFilter.thisMonth,
                label: '📅 ${context.l10n.filterEventsThisMonth}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.thisMonth));
                  Navigator.pop(context);
                },
              ),
              if (current != null) ...[
                const SizedBox(height: AppSpacing.x1),
                TextButton(
                  onPressed: () {
                    context.read<EventsBloc>().add(UpdateDateFilter(null));
                    Navigator.pop(context);
                  },
                  child: Text(context.l10n.filterEventsClearDateFilter),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DateOption extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _DateOption({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      tileColor: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
      ),
      trailing: selected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
            )
          : null,
    );
  }
}
