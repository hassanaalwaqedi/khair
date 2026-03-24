import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Step 3: Vision & Goals — "What are you hoping to achieve with Khair?"
class GoalsStep extends StatelessWidget {
  final Set<String> selectedGoals;
  final ValueChanged<String> onGoalToggled;

  const GoalsStep({
    super.key,
    required this.selectedGoals,
    required this.onGoalToggled,
  });

  List<_GoalOption> _getGoals(BuildContext context) {
    final l10n = context.l10n;
    return [
      _GoalOption(
        id: 'publish_events',
        label: l10n.goalPublishEvents,
        icon: Icons.campaign_rounded,
      ),
      _GoalOption(
        id: 'grow_community',
        label: l10n.goalGrowCommunity,
        icon: Icons.trending_up_rounded,
      ),
      _GoalOption(
        id: 'teach_knowledge',
        label: l10n.goalTeachKnowledge,
        icon: Icons.school_rounded,
      ),
      _GoalOption(
        id: 'discover_events',
        label: l10n.goalDiscoverEvents,
        icon: Icons.explore_rounded,
      ),
      _GoalOption(
        id: 'volunteer',
        label: l10n.goalVolunteer,
        icon: Icons.volunteer_activism_rounded,
      ),
      _GoalOption(
        id: 'build_network',
        label: l10n.goalBuildNetwork,
        icon: Icons.hub_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.registrationGoalsTitle,
          style: KhairTypography.h1.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.registrationGoalsSubtitle,
          style: KhairTypography.bodyLarge.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.l10n.registrationStepOptional,
            style: KhairTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _getGoals(context).map((goal) {
            final isSelected = selectedGoals.contains(goal.id);
            return _GoalChip(
              goal: goal,
              isSelected: isSelected,
              onTap: () => onGoalToggled(goal.id),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _GoalOption {
  final String id;
  final String label;
  final IconData icon;

  const _GoalOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _GoalChip extends StatefulWidget {
  final _GoalOption goal;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalChip({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GoalChip> createState() => _GoalChipState();
}

class _GoalChipState extends State<_GoalChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.12),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.goal.icon,
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                widget.goal.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.85),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
