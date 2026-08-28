import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../tokens/tokens.dart';
import '../../../../events/domain/entities/event.dart';
import '../../../../events/presentation/bloc/events_bloc.dart';

/// A scrollable row of chips showing currently active filters.
/// Each chip has an × button to remove that individual filter.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventsBloc, EventsState>(
      buildWhen: (prev, curr) => prev.filter != curr.filter,
      builder: (context, state) {
        final filter = state.filter;
        final chips = _buildChips(context, filter);
        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => chips[i],
          ),
        );
      },
    );
  }

  List<Widget> _buildChips(BuildContext context, EventFilter filter) {
    final chips = <Widget>[];
    final bloc = context.read<EventsBloc>();

    // Search query
    if (filter.searchQuery?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: '"${filter.searchQuery}"',
        icon: Icons.search_rounded,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(clearSearchQuery: true, page: 1),
        )),
      ));
    }

    // Date filter
    if (filter.dateFilter != null) {
      final label = switch (filter.dateFilter!) {
        DateFilter.today => 'Today',
        DateFilter.thisWeekend => 'This weekend',
        DateFilter.thisWeek => 'This week',
        DateFilter.thisMonth => 'This month',
      };
      chips.add(_Chip(
        label: label,
        icon: Icons.calendar_today_outlined,
        onRemove: () => bloc.add(UpdateDateFilter(null)),
      ));
    }

    // Online only
    if (filter.onlineOnly) {
      chips.add(_Chip(
        label: 'Online',
        icon: Icons.videocam_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(onlineOnly: false, page: 1),
        )),
      ));
    }

    // Free only
    if (filter.freeOnly || filter.pricingType == 'free') {
      chips.add(_Chip(
        label: 'Free',
        icon: Icons.sell_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(freeOnly: false, clearPricingType: true, page: 1),
        )),
      ));
    }

    // City
    if (filter.city?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: filter.city!,
        icon: Icons.location_city_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(clearCity: true, page: 1),
        )),
      ));
    }

    // Country
    if (filter.country?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: filter.country!,
        icon: Icons.flag_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(clearCountry: true, page: 1),
        )),
      ));
    }

    if (filter.pricingType == 'paid') {
      chips.add(_Chip(
        label: 'Paid',
        icon: Icons.credit_card_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(clearPricingType: true, page: 1),
        )),
      ));
    }

    if (filter.category?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: filter.category!,
        icon: Icons.category_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(clearCategory: true, page: 1),
        )),
      ));
    }

    // Event type (in-person or mode)
    if (filter.eventType?.isNotEmpty ?? false) {
      final label = switch (filter.eventType!.toLowerCase()) {
        'offline' => 'In-Person',
        'online' => 'Online',
        _ => filter.eventType!,
      };
      chips.add(_Chip(
        label: label,
        icon: Icons.location_on_outlined,
        onRemove: () => bloc.add(UpdateFilter(
          filter.copyWith(clearEventType: true, page: 1),
        )),
      ));
    }

    return chips;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 4, 0),
            child: Icon(icon, size: 14, color: AppColors.primaryDark),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.close_rounded, size: 14, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
