import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review & Submit', style: AppTypography.sectionTitle),
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
                    const Text('Event Summary',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 14),
                  _row('Title',
                      fd.title.isNotEmpty ? fd.title : '—'),
                  _row('Category',
                      fd.category[0].toUpperCase() +
                          fd.category.substring(1)),
                  _row('Type',
                      fd.eventType == 'offline'
                          ? 'In-Person'
                          : 'Online'),
                  _row('Language', fd.language.toUpperCase()),
                  _row('Start',
                      DateFormat('MMM d, yyyy – h:mm a')
                          .format(fd.startDateTime)),
                  if (fd.endDateTime != null)
                    _row('End',
                        DateFormat('MMM d, yyyy – h:mm a')
                            .format(fd.endDateTime!)),
                  if (fd.eventType == 'offline' && fd.city != null)
                    _row('Location',
                        '${fd.city}, ${fd.countryName ?? fd.countryCode ?? ''}'),
                  if (fd.eventType == 'online')
                    _row('Platform', fd.onlinePlatform ?? '—'),
                  _row('Capacity', fd.capacity.toString()),
                  if (fd.tags.isNotEmpty)
                    _row('Tags', fd.tags.join(', ')),
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
                    const Text('Compliance',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 14),
                  _compRow('Gender Policy',
                      comp.genderPolicy.replaceAll('_', ' '), true),
                  _compRow('Family Friendly',
                      comp.familyFriendly ? 'Yes' : 'No',
                      comp.familyFriendly),
                  _compRow('No Music',
                      comp.noMusic ? 'Confirmed' : 'No',
                      comp.noMusic),
                  _compRow(
                      'No Inappropriate',
                      comp.noInappropriateContent
                          ? 'Confirmed'
                          : 'No',
                      comp.noInappropriateContent),
                  _compRow('Prayer Break',
                      comp.prayerBreakRequired ? 'Included' : 'No',
                      comp.prayerBreakRequired),
                  _compRow('Confirmed',
                      comp.complianceConfirmed ? 'Yes' : 'No',
                      comp.complianceConfirmed),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Risk Assessment
            _riskCard(comp),
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
                    const Text('Trust Impact',
                        style: TextStyle(
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
                            'Successfully hosting this event will increase your trust score. Flagged events may decrease it.',
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
                      'I confirm all information is accurate. I understand events are reviewed before publishing.',
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

  Widget _riskCard(ComplianceSettings comp) {
    final risk = comp.riskLevel;
    final Color riskColor;
    final IconData riskIcon;
    final String riskLabel;

    switch (risk) {
      case 'low':
        riskColor = AppColors.success;
        riskIcon = Icons.check_circle_rounded;
        riskLabel = 'Low Risk — Likely auto-approved';
      case 'medium':
        riskColor = AppColors.warning;
        riskIcon = Icons.warning_rounded;
        riskLabel = 'Medium Risk — Manual review required';
      default:
        riskColor = AppColors.error;
        riskIcon = Icons.error_rounded;
        riskLabel = 'High Risk — Additional review needed';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.analytics_rounded,
                color: AppColors.goldAccent, size: 20),
            const SizedBox(width: 10),
            const Text('Risk Assessment',
                style: TextStyle(
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
