import 'package:flutter/material.dart';

import '../../../../core/locale/l10n_extension.dart';

/// Horizontal scrollable category chips with animated selection.
class CategoryScroller extends StatefulWidget {
  final ValueChanged<int>? onCategoryChanged;

  const CategoryScroller({super.key, this.onCategoryChanged});

  @override
  State<CategoryScroller> createState() => _CategoryScrollerState();
}

class _CategoryScrollerState extends State<CategoryScroller> {
  int _selected = 0;

  List<_Cat> _categories(BuildContext context) => [
        _Cat(icon: Icons.trending_up_rounded, label: context.l10n.catTrending),
        _Cat(icon: Icons.near_me_rounded, label: context.l10n.catNearYou),
        _Cat(
            icon: Icons.volunteer_activism_rounded,
            label: context.l10n.catCharity),
        _Cat(
            icon: Icons.menu_book_rounded,
            label: context.l10n.catKnowledge),
        _Cat(icon: Icons.mosque_rounded, label: context.l10n.catMasjid),
        _Cat(icon: Icons.public_rounded, label: context.l10n.catGlobal),
      ];

  @override
  Widget build(BuildContext context) {
    final cats = _categories(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final cat = cats[i];
          final isSelected = _selected == i;
          return GestureDetector(
            onTap: () {
              setState(() => _selected = i);
              widget.onCategoryChanged?.call(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1B6B45)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF22C55E)
                              .withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
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
  }
}

class _Cat {
  final IconData icon;
  final String label;
  const _Cat({required this.icon, required this.label});
}
