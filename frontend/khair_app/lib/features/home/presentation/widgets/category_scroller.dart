import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../events/presentation/bloc/events_bloc.dart';

/// Each category chip's metadata:
///  - id    : backend event_type value, or special tokens '_trending' / '_global'
///  - emoji : display emoji
///  - label : display text
class _Cat {
  final String id;
  final String emoji;
  final String label;
  const _Cat({required this.id, required this.emoji, required this.label});
}

/// Modern horizontal category chips.
/// Selecting a chip dispatches the correct [EventsBloc] event
/// so the events list reloads in real time from the API.
class CategoryScroller extends StatelessWidget {
  const CategoryScroller({super.key});

  List<_Cat> _categories(BuildContext context) => [
        _Cat(id: '_trending', emoji: '🔥', label: context.l10n.catTrending),
        _Cat(id: '_global', emoji: '🌍', label: context.l10n.catGlobal),
        _Cat(id: 'knowledge', emoji: '📖', label: context.l10n.catKnowledge),
        _Cat(id: 'lectures', emoji: '🎓', label: context.l10n.catLectures),
        _Cat(id: 'charity', emoji: '🤝', label: context.l10n.catCharity),
        _Cat(id: 'quran', emoji: '🕌', label: context.l10n.catMasjid),
        _Cat(id: 'community', emoji: '👥', label: context.l10n.catCommunity),
      ];

  /// Derive the "selected id" from the current EventsBloc filter state.
  String _selectedId(EventsState state) {
    if (state.filter.trending) return '_trending';
    final et = state.filter.eventType;
    if (et != null && et.isNotEmpty) return et;
    return '_global'; // default = all events
  }

  void _onTap(BuildContext context, String id) {
    final bloc = context.read<EventsBloc>();
    switch (id) {
      case '_trending':
        // If already trending, toggle off (back to global)
        if (bloc.state.filter.trending) {
          bloc.add(ClearAllFilters());
        } else {
          bloc.add(ToggleTrending());
        }
        break;
      case '_global':
        bloc.add(ClearAllFilters());
        break;
      default:
        // If same category is tapped again → clear → show all
        if (bloc.state.filter.eventType == id) {
          bloc.add(ClearAllFilters());
        } else {
          bloc.add(UpdateCategoryFilter(id));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;
    final chipBg =
        isDark ? KhairColors.darkSurfaceVariant : KhairColors.surfaceVariant;
    final textColor =
        isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;

    return BlocBuilder<EventsBloc, EventsState>(
      buildWhen: (prev, curr) =>
          prev.filter.eventType != curr.filter.eventType ||
          prev.filter.trending != curr.filter.trending,
      builder: (context, state) {
        final selectedId = _selectedId(state);
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = cats[i];
              final isSelected = cat.id == selectedId;
              return GestureDetector(
                onTap: () => _onTap(context, cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? KhairColors.primary : chipBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? KhairColors.primary : bdr,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.emoji,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : textColor,
                        ),
                        child: Text(cat.label),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
