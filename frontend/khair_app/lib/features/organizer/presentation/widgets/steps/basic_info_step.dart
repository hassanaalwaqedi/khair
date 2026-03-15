import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/locale/l10n_extension.dart';
import '../../../../../core/theme/app_design_system.dart';
import '../../../../../shared/widgets/app_components.dart';
import '../../cubit/create_event_cubit.dart';
import '../../cubit/create_event_state.dart';

/// Step 1: Title, description, category, tags, event type, language, date/time
class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  static const _categories = [
    'conference', 'workshop', 'seminar', 'lecture', 'meetup',
    'festival', 'webinar', 'retreat', 'community', 'charity',
  ];

  static const _tags = [
    'Islamic', 'Education', 'Youth', 'Women', 'Family', 'Charity',
    'Community', 'Quran', 'Seerah', 'Fiqh', 'Dawah', 'Volunteer',
  ];

  @override
  void initState() {
    super.initState();
    final fd = context.read<CreateEventCubit>().state.formData;
    _titleCtrl = TextEditingController(text: fd.title);
    _descCtrl = TextEditingController(text: fd.description);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateEventCubit, CreateEventState>(
      listenWhen: (p, c) => p.status != c.status && c.status == CreateEventStatus.initial,
      listener: (context, state) {
        // Sync controllers when AI updates form data
        if (_descCtrl.text != state.formData.description) {
          _descCtrl.text = state.formData.description;
        }
      },
      child: BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) => p.formData != c.formData || p.status != c.status,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final fd = state.formData;
        final isAiLoading = state.status == CreateEventStatus.aiGenerating;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Basic Info Card ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.createEventBasicInfoTitle, style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  AppInputField(
                    controller: _titleCtrl,
                    label: context.l10n.createEventTitleLabel,
                    hint: context.l10n.createEventTitleHint,
                    icon: Icons.title_rounded,
                    maxLength: 100,
                    onChanged: (v) => cubit.updateTitle(v),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Category + AI detect button
                  Row(
                    children: [
                      Text(context.l10n.createEventCategoryLabel, style: AppTypography.label),
                      const Spacer(),
                      GestureDetector(
                        onTap: isAiLoading || fd.title.isEmpty ? null : () => cubit.detectCategory(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: fd.title.isNotEmpty && !isAiLoading
                                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                                : null,
                            color: fd.title.isEmpty || isAiLoading ? AppColors.whiteAlpha(0.06) : null,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAiLoading)
                                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                              else
                                const Text('🔍', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text('Auto-detect', style: TextStyle(
                                color: fd.title.isNotEmpty && !isAiLoading ? Colors.white : AppColors.whiteAlpha(0.3),
                                fontSize: 11, fontWeight: FontWeight.w600,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _categories.map((cat) {
                      return AppChip(
                        label: cat[0].toUpperCase() + cat.substring(1),
                        isSelected: fd.category == cat,
                        onTap: () => cubit.updateCategory(cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Description
                  AppInputField(
                    controller: _descCtrl,
                    label: context.l10n.createEventDescLabel,
                    hint: context.l10n.createEventDescHint,
                    icon: Icons.description_rounded,
                    maxLines: 5,
                    maxLength: 5000,
                    onChanged: (v) => cubit.updateDescription(v),
                  ),
                  if (_descCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        '${_descCtrl.text.length} / 5000',
                        style: TextStyle(
                          color: _descCtrl.text.length < 50
                              ? AppColors.error
                              : AppColors.whiteAlpha(0.3),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),

                  // AI Generate Description Button
                  GestureDetector(
                    onTap: isAiLoading || fd.title.isEmpty ? null : () => cubit.generateDescription(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: fd.title.isNotEmpty && !isAiLoading
                            ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                            : null,
                        color: fd.title.isEmpty || isAiLoading ? AppColors.whiteAlpha(0.06) : null,
                        borderRadius: AppRadius.inputRadius,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isAiLoading)
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          else
                            const Text('✨', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            isAiLoading ? 'Generating...' : 'Generate with AI',
                            style: TextStyle(
                              color: fd.title.isNotEmpty && !isAiLoading ? Colors.white : AppColors.whiteAlpha(0.3),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Tags Card ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.createEventTagsLabel, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _tags.map((tag) {
                      return AppChip(
                        label: tag,
                        isSelected: fd.tags.contains(tag),
                        onTap: () => cubit.toggleTag(tag),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Event Type Card ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.createEventEventTypeLabel, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                          child: _typeOption('offline', context.l10n.createEventInPerson,
                              Icons.location_on_rounded, fd.eventType, cubit)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: _typeOption('online', context.l10n.createEventOnline,
                              Icons.videocam_rounded, fd.eventType, cubit)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Language
                  Text(context.l10n.createEventLanguageLabel, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      AppChip(label: context.l10n.langEnglish, isSelected: fd.language == 'en',
                          onTap: () => cubit.updateLanguage('en')),
                      AppChip(label: context.l10n.langArabic, isSelected: fd.language == 'ar',
                          onTap: () => cubit.updateLanguage('ar')),
                      AppChip(label: context.l10n.langFrench, isSelected: fd.language == 'fr',
                          onTap: () => cubit.updateLanguage('fr')),
                      AppChip(label: context.l10n.langTurkish, isSelected: fd.language == 'tr',
                          onTap: () => cubit.updateLanguage('tr')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Date & Time Card ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.createEventStartDateTime, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(child: _datePicker(
                          context, 'Start', fd.startDate, (d) {
                        cubit.updateFormData(fd.copyWith(startDate: d));
                      })),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _timePicker(context, fd.startTime, (t) {
                        cubit.updateFormData(fd.copyWith(startTime: t));
                      })),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.l10n.createEventEndDateTime, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(child: _datePicker(
                          context, 'End', fd.endDate ?? fd.startDate, (d) {
                        cubit.updateFormData(fd.copyWith(endDate: d));
                      })),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _timePicker(
                          context,
                          fd.endTime ??
                              const TimeOfDay(hour: 17, minute: 0), (t) {
                        cubit.updateFormData(fd.copyWith(endTime: t));
                      })),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    ),
    );
  }

  Widget _typeOption(String value, String label, IconData icon,
      String current, CreateEventCubit cubit) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => cubit.updateEventType(value),
      child: AnimatedContainer(
        duration: AppAnimations.normal,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.whiteAlpha(0.04),
          borderRadius: AppRadius.inputRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.goldAccent
                : AppColors.whiteAlpha(0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? AppShadows.goldGlow(0.1) : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.goldAccent
                    : AppColors.whiteAlpha(0.4),
                size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.whiteAlpha(0.5),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }

  Widget _datePicker(BuildContext context, String label, DateTime date,
      ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.whiteAlpha(0.05),
          borderRadius: AppRadius.inputRadius,
          border: Border.all(color: AppColors.whiteAlpha(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: AppColors.whiteAlpha(0.3), size: 18),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM d, yyyy').format(date),
              style:
                  TextStyle(color: AppColors.whiteAlpha(0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePicker(BuildContext context, TimeOfDay time,
      ValueChanged<TimeOfDay> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.whiteAlpha(0.05),
          borderRadius: AppRadius.inputRadius,
          border: Border.all(color: AppColors.whiteAlpha(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded,
                color: AppColors.whiteAlpha(0.3), size: 18),
            const SizedBox(width: 8),
            Text(
              time.format(context),
              style:
                  TextStyle(color: AppColors.whiteAlpha(0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
