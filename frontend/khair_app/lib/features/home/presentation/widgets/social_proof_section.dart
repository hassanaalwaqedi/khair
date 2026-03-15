import 'package:flutter/material.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/app_design_system.dart';

/// Social proof section showing real event participation count.
class SocialProofSection extends StatelessWidget {
  final int totalReserved;
  const SocialProofSection({super.key, required this.totalReserved});

  @override
  Widget build(BuildContext context) {
    if (totalReserved <= 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(40 * (1 - value), 0),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor(context, 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF22C55E),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.communityActivity,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceColor(context, 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.peopleJoinedEvents(totalReserved),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceColor(context, 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
