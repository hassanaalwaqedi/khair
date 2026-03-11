import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/locale/l10n_extension.dart';
import '../../../../../core/theme/app_design_system.dart';
import '../../../../../shared/widgets/app_components.dart';
import '../../cubit/create_event_cubit.dart';
import '../../cubit/create_event_state.dart';

/// Step 5: Smart review — event summary, compliance, risk level, trust score, final confirm
class ReviewStep extends StatelessWidget {
  const ReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final fd = state.formData;
        final comp = fd.compliance;
        final l10n = context.l10n;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.createEventReviewSubmit, style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.lg),

            // Event Summary Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.summarize_rounded,
                        color: AppColors.goldAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.createEventEventSummary,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 14),
                  _row(l10n.createEventTitleLabel,
                      fd.title.isNotEmpty ? fd.title : '—'),
                  _row(l10n.createEventCategoryLabel,
                      fd.category[0].toUpperCase() +
                          fd.category.substring(1)),
                  _row(l10n.createEventEventTypeLabel,
                      fd.eventType == 'offline'
                          ? l10n.createEventInPerson
                          : l10n.createEventOnline),
                  _row(l10n.createEventLanguageLabel, fd.language.toUpperCase()),
                  _row(l10n.createEventStartDateTime.replaceFirst(' & Time', ''),
                      DateFormat('MMM d, yyyy – h:mm a')
                          .format(fd.startDateTime)),
                  if (fd.endDateTime != null)
                    _row(l10n.createEventEndDateTime.split(' ')[0],
                        DateFormat('MMM d, yyyy – h:mm a')
                            .format(fd.endDateTime!)),
                  if (fd.eventType == 'offline' && fd.city != null)
                    _row(l10n.createEventStepLocation,
                        '${fd.city}, ${fd.countryName ?? fd.countryCode ?? ''}'),
                  if (fd.eventType == 'online')
                    _row(l10n.createEventPlatform, fd.onlinePlatform ?? '—'),
                  _row(l10n.createEventMaxAttendees, fd.capacity.toString()),
                  if (fd.tags.isNotEmpty)
                    _row(l10n.createEventTagsLabel, fd.tags.join(', ')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Compliance Summary
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.shield_rounded,
                        color: AppColors.goldAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.createEventReviewCompliance,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 14),
                  _compRow(l10n.createEventGenderPolicy,
                      _getGenderPolicy(comp.genderPolicy, context), true),
                  _compRow(l10n.createEventFamilyFriendly,
                      comp.familyFriendly ? l10n.createEventReviewYes : l10n.createEventReviewNo,
                      comp.familyFriendly),
                  _compRow(l10n.createEventNoMusic,
                      comp.noMusic ? l10n.createEventReviewConfirmed : l10n.createEventReviewNo,
                      comp.noMusic),
                  _compRow(
                      l10n.createEventNoInappropriate,
                      comp.noInappropriateContent
                          ? l10n.createEventReviewConfirmed
                          : l10n.createEventReviewNo,
                      comp.noInappropriateContent),
                  _compRow(l10n.createEventPrayerBreak,
                      comp.prayerBreakRequired ? l10n.createEventReviewIncluded : l10n.createEventReviewNo,
                      comp.prayerBreakRequired),
                  _compRow(l10n.createEventReviewConfirmed,
                      comp.complianceConfirmed ? l10n.createEventReviewYes : l10n.createEventReviewNo,
                      comp.complianceConfirmed),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Risk Assessment
            _riskCard(comp, context),
            const SizedBox(height: AppSpacing.md),

            // Trust Impact
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.trending_up_rounded,
                        color: AppColors.goldAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.createEventReviewTrustImpact,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: AppRadius.inputRadius,
                      border: Border.all(
                          color:
                              AppColors.info.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_rounded,
                            color: AppColors.info, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.createEventTrustImpactDesc,
                            style: TextStyle(
                                color: AppColors.whiteAlpha(0.55),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Final confirmation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fd.finalConfirmed
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.whiteAlpha(0.03),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: fd.finalConfirmed
                      ? AppColors.goldAccent
                          .withValues(alpha: 0.3)
                      : AppColors.whiteAlpha(0.06),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: fd.finalConfirmed,
                    onChanged: (v) =>
                        cubit.setFinalConfirmed(v ?? false),
                    activeColor: AppColors.goldAccent,
                    side: BorderSide(
                        color: AppColors.whiteAlpha(0.3)),
                  ),
                  Expanded(
                    child: Text(
                      l10n.createEventFinalConfirm,
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
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }

  String _getGenderPolicy(String policy, BuildContext context) {
    switch (policy) {
      case 'male_only': return context.l10n.createEventGenderMaleOnly;
      case 'female_only': return context.l10n.createEventGenderFemaleOnly;
      default: return context.l10n.createEventGenderMixed;
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.whiteAlpha(0.4),
                    fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppColors.whiteAlpha(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _compRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isGood
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: isGood ? AppColors.success : AppColors.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.whiteAlpha(0.5),
                      fontSize: 12.5))),
          Text(value,
              style: TextStyle(
                  color: AppColors.whiteAlpha(0.75),
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _riskCard(ComplianceSettings comp, BuildContext context) {
    final risk = comp.riskLevel;
    final Color riskColor;
    final IconData riskIcon;
    final String riskLabel;

    switch (risk) {
      case 'low':
        riskColor = AppColors.success;
        riskIcon = Icons.check_circle_rounded;
        riskLabel = context.l10n.createEventRiskLow;
      case 'medium':
        riskColor = AppColors.warning;
        riskIcon = Icons.warning_rounded;
        riskLabel = context.l10n.createEventRiskMedium;
      default:
        riskColor = AppColors.error;
        riskIcon = Icons.error_rounded;
        riskLabel = context.l10n.createEventRiskHigh;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.analytics_rounded,
                color: AppColors.goldAccent, size: 20),
            const SizedBox(width: 10),
            Text(context.l10n.createEventReviewRiskAssessment,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.inputRadius,
              color: riskColor.withValues(alpha: 0.08),
              border: Border.all(
                  color: riskColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(riskIcon, color: riskColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    riskLabel,
                    style: TextStyle(
                        color: riskColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
