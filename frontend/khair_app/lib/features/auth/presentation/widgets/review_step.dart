import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';

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
          'Review Your Profile',
          style: KhairTypography.h1.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please confirm everything looks correct',
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
                KhairColors.secondary.withValues(alpha: 0.2),
                KhairColors.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: KhairColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined,
                  color: KhairColors.secondary, size: 18),
              const SizedBox(width: 8),
              Text(
                roleLabelText,
                style: KhairTypography.labelLarge.copyWith(
                  color: KhairColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Account info card
        _buildSection(
          title: 'Account Information',
          items: {
            'Name': name,
            'Email': email,
          },
        ),

        // Role-specific info
        if (roleSpecificData.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection(
            title: 'Role Details',
            items: roleSpecificData,
          ),
        ],

        // Goals
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGoalsSection(),
        ],

        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.secondary,
              foregroundColor: const Color(0xFF1A1A2E),
              disabledBackgroundColor:
                  KhairColors.secondary.withValues(alpha: 0.4),
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
                        'Create Account',
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
            'By creating an account, you agree to our Terms & Privacy Policy',
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

  Widget _buildGoalsSection() {
    final goalLabels = {
      'publish_events': 'Publish Events',
      'grow_community': 'Grow Community',
      'teach_knowledge': 'Teach Knowledge',
      'discover_events': 'Discover Local Gatherings',
      'volunteer': 'Volunteer',
      'build_network': 'Build Islamic Network',
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
            'Goals',
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
                  color: KhairColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: KhairColors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  goalLabels[g] ?? g,
                  style: KhairTypography.labelSmall.copyWith(
                    color: KhairColors.secondary,
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
