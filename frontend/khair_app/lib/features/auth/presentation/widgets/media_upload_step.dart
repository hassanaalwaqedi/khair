import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Step: Media Upload — Logo / Profile Photo for authority roles
class MediaUploadStep extends StatefulWidget {
  final File? selectedImage;
  final String? uploadedImageUrl;
  final bool isUploading;
  final ValueChanged<File?> onImageSelected;

  const MediaUploadStep({
    super.key,
    this.selectedImage,
    this.uploadedImageUrl,
    this.isUploading = false,
    required this.onImageSelected,
  });

  @override
  State<MediaUploadStep> createState() => _MediaUploadStepState();
}

class _MediaUploadStepState extends State<MediaUploadStep>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        // Read bytes for cross-platform display (web + mobile)
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
        widget.onImageSelected(File(pickedFile.path));
      }
    } catch (_) {
      // Handle permission errors silently
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D3D26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.mediaSourceTitle,
                style: KhairTypography.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),
              _buildPickerOption(
                icon: Icons.camera_alt_rounded,
                label: context.l10n.mediaSourceCamera,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _buildPickerOption(
                icon: Icons.photo_library_rounded,
                label: context.l10n.mediaSourceGallery,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (widget.selectedImage != null) ...[
                const SizedBox(height: 12),
                _buildPickerOption(
                  icon: Icons.delete_outline_rounded,
                  label: context.l10n.mediaSourceRemove,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onImageSelected(null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFF8A80).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? const Color(0xFFFF8A80)
                  : KhairColors.secondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? const Color(0xFFFF8A80)
                    : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.selectedImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.mediaUploadTitle,
          style: KhairTypography.h1.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.mediaUploadSubtitleOrg,
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
        const SizedBox(height: 40),

        // Upload area
        Center(
          child: GestureDetector(
            onTap: widget.isUploading ? null : _showPickerOptions,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: hasImage ? 1.0 : _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasImage
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: hasImage
                        ? KhairColors.secondary
                        : Colors.white.withValues(alpha: 0.15),
                    width: hasImage ? 3 : 2,
                  ),
                  boxShadow: hasImage
                      ? [
                          BoxShadow(
                            color: KhairColors.secondary.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: widget.isUploading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: KhairColors.secondary,
                          strokeWidth: 3,
                        ),
                      )
                    : hasImage
                        ? ClipOval(
                            child: _imageBytes != null
                                ? Image.memory(
                                    _imageBytes!,
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  )
                                : (kIsWeb
                                    ? const Icon(Icons.image, size: 60, color: Colors.white30)
                                    : Image.file(
                                        widget.selectedImage!,
                                        width: 180,
                                        height: 180,
                                        fit: BoxFit.cover,
                                      )),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                color: KhairColors.secondary.withValues(alpha: 0.7),
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.mediaUploadTap,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ),

        if (hasImage && !widget.isUploading) ...[
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _showPickerOptions,
              icon: Icon(
                Icons.edit_rounded,
                color: KhairColors.secondary,
                size: 18,
              ),
              label: Text(
                context.l10n.mediaUploadChange,
                style: TextStyle(
                  color: KhairColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        if (widget.uploadedImageUrl != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: KhairColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: KhairColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.mediaUploadSuccess,
                    style: TextStyle(
                      color: KhairColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
