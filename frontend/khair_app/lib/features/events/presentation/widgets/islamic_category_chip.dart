import 'package:flutter/material.dart';

import '../../../../tokens/tokens.dart';

class IslamicCategoryChip extends StatefulWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const IslamicCategoryChip({
    super.key,
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<IslamicCategoryChip> createState() => _IslamicCategoryChipState();
}

class _IslamicCategoryChipState extends State<IslamicCategoryChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: selected || _hovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.96)
                  : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.30),
              ),
              boxShadow: selected || _hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: selected ? 14 : 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: AppSpacing.x1),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected ? AppColors.primary : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
