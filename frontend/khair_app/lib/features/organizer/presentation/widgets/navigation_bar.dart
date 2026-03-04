import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../cubit/create_event_cubit.dart';
import '../cubit/create_event_state.dart';

/// Bottom navigation bar for the create event wizard.
/// Shows Back / Continue on steps 0-3, Save Draft + Submit on step 4.
class CreateEventNavigationBar extends StatelessWidget {
  const CreateEventNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) =>
          p.currentStep != c.currentStep ||
          p.status != c.status ||
          p.formData.finalConfirmed != c.formData.finalConfirmed,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final isSubmitting = state.status == CreateEventStatus.submitting;
        final isValid = cubit.isCurrentStepValid;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: KhairColors.darkSurface,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Back button
              if (!state.isFirstStep)
                _outlinedButton('Back', () => cubit.previousStep()),

              const Spacer(),

              if (state.isLastStep) ...[
                // Save Draft
                _outlinedButton('Save Draft', () => cubit.saveDraft()),
                const SizedBox(width: 12),
                // Submit
                _primaryButton(
                  isSubmitting ? 'Submitting...' : 'Submit for Review',
                  isSubmitting ? null : () => cubit.submitEvent(),
                ),
              ] else
                // Continue
                _primaryButton(
                  'Continue',
                  isValid ? () => cubit.nextStep() : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: onTap != null
              ? const LinearGradient(
                  colors: [KhairColors.primary, KhairColors.primaryDark],
                )
              : null,
          color: onTap == null ? Colors.white.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null
              ? [BoxShadow(color: KhairColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap != null ? Colors.white : Colors.white.withValues(alpha: 0.3),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _outlinedButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
