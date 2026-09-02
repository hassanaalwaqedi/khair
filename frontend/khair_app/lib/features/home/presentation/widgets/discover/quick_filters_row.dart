import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

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
          height: 50,
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
                QuickFilter.nearby => state.filter.latitude != null &&
                    state.filter.longitude != null,
                QuickFilter.free =>
                  state.filter.freeOnly || state.filter.pricingType == 'free',
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
    final l10n = AppLocalizations.of(context)!;
    final (label, icon, color, background) = switch (filter) {
      QuickFilter.today => (
          l10n.today,
          Icons.calendar_month_rounded,
          AppColors.primary,
          const Color(0xFFFFE7EF)
        ),
      QuickFilter.weekend => (
          l10n.thisWeekend,
          Icons.wb_sunny_outlined,
          const Color(0xFFE88224),
          const Color(0xFFFFEEDB)
        ),
      QuickFilter.nearby => (
          l10n.nearMe,
          Icons.location_on_outlined,
          const Color(0xFF0F8B8D),
          const Color(0xFFDDF6F4)
        ),
      QuickFilter.free => (
          l10n.freeLabel,
          Icons.confirmation_number_outlined,
          const Color(0xFF14804A),
          const Color(0xFFE1F7EA)
        ),
      QuickFilter.online => (
          l10n.online,
          Icons.wifi_tethering_rounded,
          const Color(0xFF3974D8),
          const Color(0xFFE5EEFF)
        ),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: .24),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : const []),
          child: Material(
            color: selected ? color : background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 15, 0),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: selected ? color : color.withValues(alpha: .18)),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Icon(icon,
                        size: 18, color: selected ? Colors.white : color),
                    if (filter == QuickFilter.today)
                      PositionedDirectional(
                          end: -2,
                          top: -2,
                          child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle))),
                  ]),
                  const SizedBox(width: 7),
                  Text(label,
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
