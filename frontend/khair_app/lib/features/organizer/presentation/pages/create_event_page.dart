import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../cubit/create_event_cubit.dart';
import '../cubit/create_event_state.dart';
import '../widgets/steps/basic_info_step.dart';
import '../widgets/steps/location_step.dart';
import '../widgets/steps/compliance_step.dart';
import '../widgets/steps/media_step.dart';
import '../widgets/steps/review_step.dart';

/// Create Event page — 5-step wizard with BLoC state management.
class CreateEventPage extends StatelessWidget {
  const CreateEventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateEventCubit(getIt<EventsRepository>()),
      child: const _CreateEventView(),
    );
  }
}

class _CreateEventView extends StatefulWidget {
  const _CreateEventView();

  @override
  State<_CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<_CreateEventView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  List<String> _getStepLabels(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.createEventStepBasicInfo,
      l10n.createEventStepLocation,
      l10n.createEventStepCompliance,
      l10n.createEventStepMedia,
      l10n.createEventStepReview,
    ];
  }


  static const _stepIcons = [
    Icons.edit_rounded,
    Icons.location_on_rounded,
    Icons.shield_rounded,
    Icons.image_rounded,
    Icons.check_circle_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: AppAnimations.slow,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: AppAnimations.defaultCurve));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocListener<CreateEventCubit, CreateEventState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        switch (state.status) {
          case CreateEventStatus.success:
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.createEventSuccess),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.inputRadius),
            ));
            context.go('/organizer');
          case CreateEventStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(state.errorMessage ?? context.l10n.createEventError),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.inputRadius),
            ));
          case CreateEventStatus.draftSaved:
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.createEventDraftSaved),
              backgroundColor: AppColors.surfaceHigh,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.inputRadius),
            ));
            context.go('/organizer');
          default:
            break;
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.surfaceBase : AppColors.lightSurfaceBase,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              BlocBuilder<CreateEventCubit, CreateEventState>(
                buildWhen: (p, c) => p.currentStep != c.currentStep,
                builder: (context, state) {
                  final cubit = context.read<CreateEventCubit>();
                  return AppStepper(
                    currentStep: state.currentStep,
                    totalSteps: 5,
                    labels: _getStepLabels(context),
                    icons: _stepIcons,
                    onStepTap: (i) {
                      if (i < state.currentStep ||
                          cubit.validateStep(state.currentStep)) {
                        cubit.goToStep(i);
                      }
                    },
                  );
                },
              ),
              Expanded(
                child: BlocBuilder<CreateEventCubit, CreateEventState>(
                  buildWhen: (p, c) => p.currentStep != c.currentStep,
                  builder: (context, state) {
                    _slideController.reset();
                    _slideController.forward();
                    return SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: AppSpacing.pagePadding,
                        physics: const BouncingScrollPhysics(),
                        child: _buildCurrentStep(state.currentStep),
                      ),
                    );
                  },
                ),
              ),
              const _CreateEventBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) => p.currentStep != c.currentStep,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated,
            border: Border(
                bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/organizer'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.whiteAlpha(0.06) : AppColors.lightSurfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(context.l10n.createEventTitle,
                    style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
              Text(
                context.l10n.createEventStepCount(state.currentStep + 1, 5),
                style: TextStyle(
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep(int step) {
    switch (step) {
      case 0:
        return const BasicInfoStep();
      case 1:
        return const LocationStep();
      case 2:
        return const ComplianceStep();
      case 3:
        return const MediaStep();
      case 4:
        return const ReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Bottom navigation bar — blue primary actions.
class _CreateEventBottomBar extends StatelessWidget {
  const _CreateEventBottomBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) =>
          p.currentStep != c.currentStep ||
          p.status != c.status ||
          p.formData.finalConfirmed != c.formData.finalConfirmed,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final isSubmitting =
            state.status == CreateEventStatus.submitting;
        final isValid = cubit.isCurrentStepValid;

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated,
            border: Border(
                top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight)),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!state.isFirstStep)
                GestureDetector(
                  onTap: () => cubit.previousStep(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.buttonRadius,
                      border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Text(context.l10n.createEventBack,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        )),
                  ),
                ),
              const Spacer(),
              if (state.isLastStep) ...[
                GestureDetector(
                  onTap: () => cubit.saveDraft(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.buttonRadius,
                      border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Text(context.l10n.createEventSaveDraft,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap:
                      isSubmitting ? null : () => cubit.submitEvent(),
                  child: AnimatedContainer(
                    duration: AppAnimations.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: !isSubmitting
                          ? AppColors.primary
                          : isDark ? AppColors.whiteAlpha(0.06) : AppColors.lightSurfaceHigh,
                      borderRadius: AppRadius.buttonRadius,
                      boxShadow: !isSubmitting
                          ? AppShadows.primaryGlow(0.2)
                          : null,
                    ),
                    child: Text(
                      isSubmitting
                          ? context.l10n.createEventSubmitting
                          : context.l10n.createEventSubmit,
                      style: TextStyle(
                        color: isSubmitting
                            ? isDark ? AppColors.textMuted : AppColors.lightTextMuted
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ] else
                GestureDetector(
                  onTap: isValid ? () => cubit.nextStep() : null,
                  child: AnimatedContainer(
                    duration: AppAnimations.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: isValid
                          ? AppColors.primary
                          : isDark ? AppColors.whiteAlpha(0.06) : AppColors.lightSurfaceHigh,
                      borderRadius: AppRadius.buttonRadius,
                      boxShadow: isValid
                          ? AppShadows.primaryGlow(0.2)
                          : null,
                    ),
                    child: Text(
                      context.l10n.createEventContinue,
                      style: TextStyle(
                        color: isValid
                            ? Colors.white
                            : isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
