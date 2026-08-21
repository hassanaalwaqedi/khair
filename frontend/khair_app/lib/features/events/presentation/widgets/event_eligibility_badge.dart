import 'package:flutter/material.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../tokens/tokens.dart';
import '../../domain/entities/attendance_policy.dart';

/// A compact, text-labelled eligibility indicator.
///
/// Everyone events intentionally render no badge to keep discovery surfaces
/// quiet. Restricted events always include text so the meaning is not carried
/// by colour or iconography alone.
class EventEligibilityBadge extends StatelessWidget {
  const EventEligibilityBadge({super.key, required this.policy});

  final String policy;

  @override
  Widget build(BuildContext context) {
    final normalized = AttendancePolicy.normalize(policy);
    if (normalized == AttendancePolicy.everyone) {
      return const SizedBox.shrink();
    }

    final womenOnly = normalized == AttendancePolicy.womenOnly;
    final label = womenOnly
        ? context.l10n.eventEligibilityWomenOnly
        : context.l10n.eventEligibilityMenOnly;
    final icon = womenOnly ? Icons.woman_rounded : Icons.man_rounded;

    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.primary.withValues(alpha: .22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryDark),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
