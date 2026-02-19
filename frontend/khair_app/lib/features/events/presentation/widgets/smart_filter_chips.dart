import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/emoji_mapper.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../domain/entities/event.dart';
import '../bloc/events_bloc.dart';

class SmartFilterChips extends StatelessWidget {
  const SmartFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventsBloc, EventsState>(
      buildWhen: (previous, current) => previous.filter != current.filter,
      builder: (context, state) {
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Location chip (auto from LocationBloc)
              _buildLocationChip(context),
              const SizedBox(width: 8),
              // Category chips
              ..._buildCategoryChips(context, state.filter),
              // Date filter chip
              _buildDateChip(context, state.filter),
              const SizedBox(width: 8),
              // Trending chip
              _buildTrendingChip(context, state.filter),
              // Clear all (only if filters active)
              if (state.filter.hasActiveFilters) ...[
                const SizedBox(width: 8),
                _buildClearChip(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationChip(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        if (locationState is LocationLoaded) {
          return Chip(
            avatar: Text(locationEmoji, style: const TextStyle(fontSize: 14)),
            label: Text(
              '${locationState.location.city}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            backgroundColor: KhairColors.primary.withAlpha(25),
            side: BorderSide(color: KhairColors.primary.withAlpha(60)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }
        if (locationState is LocationLoading) {
          return Chip(
            avatar: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.grey[400],
              ),
            ),
            label: Text(
              'Locating...',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  List<Widget> _buildCategoryChips(BuildContext context, EventFilter filter) {
    final categories = [
      ('conference', '${getCategoryEmoji('conference')} Conference'),
      ('workshop', '${getCategoryEmoji('workshop')} Workshop'),
      ('seminar', '${getCategoryEmoji('seminar')} Seminar'),
      ('festival', '${getCategoryEmoji('festival')} Festival'),
      ('meetup', '${getCategoryEmoji('meetup')} Meetup'),
    ];

    return categories.map((cat) {
      final isSelected = filter.eventType == cat.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(
            cat.$2,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : null,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            context.read<EventsBloc>().add(
                  UpdateCategoryFilter(selected ? cat.$1 : null),
                );
          },
          selectedColor: KhairColors.primary,
          backgroundColor: Colors.grey[100],
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
        ),
      );
    }).toList();
  }

  Widget _buildDateChip(BuildContext context, EventFilter filter) {
    final isActive = filter.dateFilter != null;
    final label = switch (filter.dateFilter) {
      DateFilter.today => 'Today',
      DateFilter.thisWeek => 'This Week',
      DateFilter.thisWeekend => 'Weekend',
      DateFilter.thisMonth => 'This Month',
      null => '📅 Date',
    };

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive ? Colors.white : null,
        ),
      ),
      selected: isActive,
      onSelected: (_) => _showDateFilterSheet(context, filter.dateFilter),
      selectedColor: KhairColors.primary,
      backgroundColor: Colors.grey[100],
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: false,
    );
  }

  Widget _buildTrendingChip(BuildContext context, EventFilter filter) {
    return ChoiceChip(
      label: Text(
        '$trendingEmoji Trending',
        style: TextStyle(
          fontSize: 13,
          fontWeight: filter.trending ? FontWeight.w600 : FontWeight.w400,
          color: filter.trending ? Colors.white : null,
        ),
      ),
      selected: filter.trending,
      onSelected: (_) {
        context.read<EventsBloc>().add(ToggleTrending());
      },
      selectedColor: Colors.deepOrange,
      backgroundColor: Colors.grey[100],
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: false,
    );
  }

  Widget _buildClearChip(BuildContext context) {
    return ActionChip(
      label: const Text(
        '✕ Clear',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      onPressed: () {
        context.read<EventsBloc>().add(ClearAllFilters());
      },
      backgroundColor: Colors.red[50],
      side: BorderSide(color: Colors.red.withAlpha(60)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showDateFilterSheet(BuildContext context, DateFilter? current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DateFilterSheet(
        current: current,
        onSelected: (dateFilter) {
          context.read<EventsBloc>().add(UpdateDateFilter(dateFilter));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _DateFilterSheet extends StatelessWidget {
  final DateFilter? current;
  final ValueChanged<DateFilter?> onSelected;

  const _DateFilterSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Filter by Date',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOption(context, DateFilter.today, '📅 Today'),
          _buildOption(context, DateFilter.thisWeek, '📆 This Week'),
          _buildOption(context, DateFilter.thisWeekend, '🎉 This Weekend'),
          _buildOption(context, DateFilter.thisMonth, '🗓️ This Month'),
          if (current != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
              title: const Text('Clear Date Filter'),
              onTap: () => onSelected(null),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, DateFilter filter, String label) {
    final isSelected = current == filter;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? KhairColors.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: KhairColors.primary)
          : null,
      onTap: () => onSelected(filter),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      tileColor: isSelected ? KhairColors.primary.withAlpha(15) : null,
    );
  }
}
