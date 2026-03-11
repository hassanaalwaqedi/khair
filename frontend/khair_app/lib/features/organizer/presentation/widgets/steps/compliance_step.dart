import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/locale/l10n_extension.dart';
import '../../../../../core/theme/app_design_system.dart';
import '../../../../../shared/widgets/app_components.dart';
import '../../cubit/create_event_cubit.dart';
import '../../cubit/create_event_state.dart';

/// Step 3: Islamic compliance toggles + gender policy + confirmation
class ComplianceStep extends StatelessWidget {
  const ComplianceStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) => p.formData.compliance != c.formData.compliance,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final comp = state.formData.compliance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.createEventIslamicCompliance,
                      style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.createEventComplianceDesc,
                    style: TextStyle(
                        color: AppColors.whiteAlpha(0.4), fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Gender policy
                  Text(context.l10n.createEventGenderPolicy, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      AppChip(
                          label: context.l10n.createEventGenderMixed,
                          isSelected: comp.genderPolicy == 'mixed',
                          onTap: () => cubit.updateCompliance(
                              comp.copyWith(genderPolicy: 'mixed'))),
                      AppChip(
                          label: context.l10n.createEventGenderMaleOnly,
                          isSelected: comp.genderPolicy == 'male_only',
                          onTap: () => cubit.updateCompliance(
                              comp.copyWith(genderPolicy: 'male_only'))),
                      AppChip(
                          label: context.l10n.createEventGenderFemaleOnly,
                          isSelected: comp.genderPolicy == 'female_only',
                          onTap: () => cubit.updateCompliance(comp
                              .copyWith(genderPolicy: 'female_only'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Toggles Card ──
            AppCard(
              child: Column(
                children: [
                  _toggle(context.l10n.createEventFamilyFriendly,
                      context.l10n.createEventFamilyFriendlyDesc,
                      Icons.family_restroom_rounded, comp.familyFriendly,
                      (v) => cubit.updateCompliance(
                          comp.copyWith(familyFriendly: v))),
                  _toggle(
                      context.l10n.createEventNoMusic,
                      context.l10n.createEventNoMusicDesc,
                      Icons.music_off_rounded,
                      comp.noMusic,
                      (v) => cubit.updateCompliance(
                          comp.copyWith(noMusic: v))),
                  _toggle(
                      context.l10n.createEventNoInappropriate,
                      context.l10n.createEventNoInappropriateDesc,
                      Icons.verified_user_rounded,
                      comp.noInappropriateContent,
                      (v) => cubit.updateCompliance(
                          comp.copyWith(noInappropriateContent: v))),
                  _toggle(
                      context.l10n.createEventPrayerBreak,
                      context.l10n.createEventPrayerBreakDesc,
                      Icons.access_time_rounded,
                      comp.prayerBreakRequired,
                      (v) => cubit.updateCompliance(
                          comp.copyWith(prayerBreakRequired: v))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Confirmation ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: comp.complianceConfirmed
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.whiteAlpha(0.03),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: comp.complianceConfirmed
                      ? AppColors.goldAccent.withValues(alpha: 0.3)
                      : AppColors.whiteAlpha(0.06),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: comp.complianceConfirmed,
                    onChanged: (v) => cubit.updateCompliance(
                        comp.copyWith(complianceConfirmed: v ?? false)),
                    activeColor: AppColors.goldAccent,
                    side: BorderSide(
                        color: AppColors.whiteAlpha(0.3)),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.createEventComplianceConfirm,
                      style: TextStyle(
                        color: AppColors.whiteAlpha(0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!comp.complianceConfirmed) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.inputRadius,
                  color: AppColors.warning.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.createEventComplianceWarning,
                        style: TextStyle(
                            color: AppColors.whiteAlpha(0.6),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }

  Widget _toggle(String title, String subtitle, IconData icon,
      bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha(0.04),
        borderRadius: AppRadius.inputRadius,
        border: Border.all(color: AppColors.whiteAlpha(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.whiteAlpha(0.04),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon,
                color: value
                    ? AppColors.goldAccent
                    : AppColors.whiteAlpha(0.3),
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.whiteAlpha(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.whiteAlpha(0.4),
                        fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.goldAccent,
            inactiveTrackColor: AppColors.whiteAlpha(0.08),
          ),
        ],
      ),
    );
  }
}
