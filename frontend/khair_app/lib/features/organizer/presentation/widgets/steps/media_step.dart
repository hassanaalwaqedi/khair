import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_design_system.dart';
import '../../../../../shared/widgets/app_components.dart';
import '../../cubit/create_event_cubit.dart';
import '../../cubit/create_event_state.dart';

/// Step 4: Cover image upload, capacity, price, registration deadline, auto-approval
class MediaStep extends StatefulWidget {
  const MediaStep({super.key});

  @override
  State<MediaStep> createState() => _MediaStepState();
}

class _MediaStepState extends State<MediaStep> {
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _priceCtrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final fd = context.read<CreateEventCubit>().state.formData;
    _capacityCtrl = TextEditingController(text: fd.capacity.toString());
    _priceCtrl = TextEditingController(text: fd.price.toString());
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file != null && mounted) {
      context.read<CreateEventCubit>().uploadImage(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) =>
          p.formData.coverImageUrl != c.formData.coverImageUrl ||
          p.formData.autoApproval != c.formData.autoApproval ||
          p.status != c.status,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final fd = state.formData;
        final isUploading =
            state.status == CreateEventStatus.imageUploading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image Card ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Media & Details',
                      style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.lg),
                  GestureDetector(
                    onTap: isUploading ? null : _pickImage,
                    child: AnimatedContainer(
                      duration: AppAnimations.normal,
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.whiteAlpha(0.04),
                        borderRadius: AppRadius.inputRadius,
                        border: Border.all(
                          color: fd.coverImageUrl != null
                              ? AppColors.goldAccent
                                  .withValues(alpha: 0.3)
                              : AppColors.whiteAlpha(0.08),
                        ),
                      ),
                      child: isUploading
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: AppColors.goldAccent,
                                      strokeWidth: 2),
                                  SizedBox(height: 12),
                                  Text('Uploading...',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13)),
                                ],
                              ),
                            )
                          : fd.coverImageUrl != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          AppRadius.inputRadius,
                                      child: Image.network(
                                        fd.coverImageUrl!,
                                        width: double.infinity,
                                        height: 180,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                _uploadPlaceholder(),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding:
                                            const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(
                                                  alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 16),
                                      ),
                                    ),
                                  ],
                                )
                              : _uploadPlaceholder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Capacity & Price Card ──
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppInputField(
                          controller: _capacityCtrl,
                          label: 'Max Attendees',
                          hint: '100',
                          icon: Icons.people_rounded,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => cubit.updateFormData(
                              fd.copyWith(
                                  capacity:
                                      int.tryParse(v) ?? 100)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppInputField(
                          controller: _priceCtrl,
                          label: 'Ticket Price',
                          hint: '0 = Free',
                          icon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => cubit.updateFormData(
                              fd.copyWith(
                                  price:
                                      double.tryParse(v) ?? 0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Registration deadline
                  Text('Registration Deadline',
                      style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fd.registrationDeadline ??
                            fd.startDate.subtract(
                                const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: fd.startDate,
                      );
                      if (picked != null) {
                        cubit.updateFormData(fd.copyWith(
                            registrationDeadline: picked));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.whiteAlpha(0.05),
                        borderRadius: AppRadius.inputRadius,
                        border: Border.all(
                            color: AppColors.whiteAlpha(0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_rounded,
                              color: AppColors.whiteAlpha(0.3),
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            fd.registrationDeadline != null
                                ? DateFormat('MMM d, yyyy')
                                    .format(
                                        fd.registrationDeadline!)
                                : 'Select deadline',
                            style: TextStyle(
                                color:
                                    AppColors.whiteAlpha(0.7),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Auto-approval Card ──
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: fd.autoApproval
                          ? AppColors.primary
                              .withValues(alpha: 0.15)
                          : AppColors.whiteAlpha(0.04),
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.flash_on_rounded,
                        color: fd.autoApproval
                            ? AppColors.goldAccent
                            : AppColors.whiteAlpha(0.3),
                        size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Auto-Approval',
                            style: TextStyle(
                                color:
                                    AppColors.whiteAlpha(0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            'Automatically approve registrations',
                            style: TextStyle(
                                color:
                                    AppColors.whiteAlpha(0.4),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: fd.autoApproval,
                    onChanged: (v) => cubit.updateFormData(
                        fd.copyWith(autoApproval: v)),
                    activeColor: AppColors.goldAccent,
                    inactiveTrackColor:
                        AppColors.whiteAlpha(0.08),
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

  Widget _uploadPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined,
              color: AppColors.whiteAlpha(0.2), size: 40),
          const SizedBox(height: 10),
          Text('Tap to upload cover image',
              style: TextStyle(
                  color: AppColors.whiteAlpha(0.35), fontSize: 13)),
          const SizedBox(height: 4),
          Text('JPG, PNG • Max 5MB',
              style: TextStyle(
                  color: AppColors.whiteAlpha(0.2), fontSize: 11)),
        ],
      ),
    );
  }
}
