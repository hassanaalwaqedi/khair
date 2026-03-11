import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';

/// Search bar + horizontally scrollable filter chips
class HomeSearchSection extends StatelessWidget {
  final ValueChanged<String>? onSearch;
  final String selectedFilter;
  final ValueChanged<String>? onFilterChanged;

  static const List<String> filters = [
    'Nearby',
    'This Weekend',
    'Sisters Only',
    'Educational',
    'Charity',
  ];

  const HomeSearchSection({
    super.key,
    this.onSearch,
    this.selectedFilter = 'Nearby',
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1E14),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // ── Search bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search for Halal events, workshops, or circles...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Filter chips ──
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = filters[index];
                final isSelected = label == selectedFilter;
                return GestureDetector(
                  onTap: () => onFilterChanged?.call(label),
                  child: AnimatedContainer(
                    duration: KhairAnimations.fast,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? KhairColors.primary.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? KhairColors.primary.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? KhairColors.primaryLight
                            : Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
