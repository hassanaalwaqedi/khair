import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/generated/app_localizations.dart';

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
                label: AppLocalizations.of(context)?.trending ?? 'Trending',
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
            '📍 ${AppLocalizations.of(context)?.locating ?? 'Locating...'}',
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
    final l10n = AppLocalizations.of(context);
    final categories = [
      (key: 'knowledge', label: l10n?.catKnowledge ?? 'Knowledge', emoji: '📚'),
      (key: 'quran', label: l10n?.catQuran ?? 'Quran', emoji: '🕌'),
      (key: 'lectures', label: l10n?.catLectures ?? 'Lectures', emoji: '🎤'),
      (key: 'community', label: l10n?.catCommunity ?? 'Community', emoji: '👥'),
      (key: 'youth', label: l10n?.catYouth ?? 'Youth', emoji: '🌱'),
      (key: 'charity', label: l10n?.catCharity ?? 'Charity', emoji: '🤲'),
      (key: 'family', label: l10n?.catFamily ?? 'Family', emoji: '👨‍👩‍👧'),
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
    final l10n = AppLocalizations.of(context);
    final label = switch (filter.dateFilter) {
      DateFilter.today => '📅 ${l10n?.today ?? 'Today'}',
      DateFilter.thisWeek => '📅 ${l10n?.thisWeek ?? 'This Week'}',
      DateFilter.thisWeekend => '📅 ${l10n?.weekend ?? 'Weekend'}',
      DateFilter.thisMonth => '📅 ${l10n?.thisMonth ?? 'This Month'}',
      null => '📅 ${l10n?.dateLabel ?? 'Date'}',
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
          '✖ ${AppLocalizations.of(context)?.clear ?? 'Clear'}',
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
                AppLocalizations.of(context)?.filterByDate ?? 'Filter by Date',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.x2),
              _DateOption(
                selected: current == DateFilter.today,
                label: '📅 ${AppLocalizations.of(context)?.today ?? 'Today'}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.today));
                  Navigator.pop(context);
                },
              ),
              _DateOption(
                selected: current == DateFilter.thisWeek,
                label: '📅 ${AppLocalizations.of(context)?.thisWeek ?? 'This Week'}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.thisWeek));
                  Navigator.pop(context);
                },
              ),
              _DateOption(
                selected: current == DateFilter.thisWeekend,
                label: '📅 ${AppLocalizations.of(context)?.weekend ?? 'Weekend'}',
                onTap: () {
                  context
                      .read<EventsBloc>()
                      .add(UpdateDateFilter(DateFilter.thisWeekend));
                  Navigator.pop(context);
                },
              ),
              _DateOption(
                selected: current == DateFilter.thisMonth,
                label: '📅 ${AppLocalizations.of(context)?.thisMonth ?? 'This Month'}',
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
                  child: Text(AppLocalizations.of(context)?.clearDateFilter ?? 'Clear Date Filter'),
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
