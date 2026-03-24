import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Step 4: Review — Summary before final submission
class ReviewStep extends StatelessWidget {
  final String selectedRole;
  final String roleLabelText;
  final String name;
  final String email;
  final Set<String> goals;
  final Map<String, String> roleSpecificData;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const ReviewStep({
    super.key,
    required this.selectedRole,
    required this.roleLabelText,
    required this.name,
    required this.email,
    required this.goals,
    required this.roleSpecificData,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.registrationReviewTitle,
          style: KhairTypography.h1.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.registrationReviewSubtitle,
          style: KhairTypography.bodyLarge.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 28),

        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                roleLabelText,
                style: KhairTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Account info card
        _buildSection(
          title: context.l10n.registrationReviewAccountInfo,
          items: {
            context.l10n.name: name,
            context.l10n.email: email,
          },
        ),

        // Role-specific info
        if (roleSpecificData.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection(
            title: context.l10n.registrationReviewRoleDetails,
            items: roleSpecificData,
          ),
        ],

        // Goals
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGoalsSection(context),
        ],

        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.registrationReviewSubmit,
                        style: KhairTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            context.l10n.registrationReviewTerms,
            style: KhairTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required Map<String, String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: KhairTypography.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...items.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        entry.key,
                        style: KhairTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.isNotEmpty ? entry.value : '—',
                        style: KhairTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(BuildContext context) {
    final l10n = context.l10n;
    final goalLabels = {
      'publish_events': l10n.goalPublishEvents,
      'grow_community': l10n.goalGrowCommunity,
      'teach_knowledge': l10n.goalTeachKnowledge,
      'discover_events': l10n.goalDiscoverEvents,
      'volunteer': l10n.goalVolunteer,
      'build_network': l10n.goalBuildNetwork,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.registrationReviewGoals,
            style: KhairTypography.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goals.map((g) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  goalLabels[g] ?? g,
                  style: KhairTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
