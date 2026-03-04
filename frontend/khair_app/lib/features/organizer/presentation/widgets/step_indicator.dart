import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../cubit/create_event_cubit.dart';
import '../cubit/create_event_state.dart';

/// Step info for the indicator
class StepInfo {
  final String label;
  final IconData icon;
  const StepInfo(this.label, this.icon);
}

const kCreateEventSteps = [
  StepInfo('Basic Info', Icons.edit_rounded),
  StepInfo('Location', Icons.location_on_rounded),
  StepInfo('Compliance', Icons.shield_rounded),
  StepInfo('Media', Icons.image_rounded),
  StepInfo('Review', Icons.check_circle_rounded),
];

/// Animated step indicator with progress connector lines.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) => p.currentStep != c.currentStep,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final current = state.currentStep;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: kCreateEventSteps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final isActive = i == current;
              final isCompleted = i < current;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i < current || cubit.validateStep(current)) {
                      cubit.goToStep(i);
                    }
                  },
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Left connector
                          if (i > 0)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: isCompleted
                                    ? KhairColors.primary
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          // Circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isActive ? 36 : 28,
                            height: isActive ? 36 : 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? KhairColors.primary
                                  : isActive
                                      ? KhairColors.primary.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                              border: isActive
                                  ? Border.all(color: KhairColors.primary, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_rounded : step.icon,
                              color: isCompleted || isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              size: isActive ? 18 : 14,
                            ),
                          ),
                          // Right connector
                          if (i < kCreateEventSteps.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: isCompleted
                                    ? KhairColors.primary
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.label,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
