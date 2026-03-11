import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';

/// Post-registration verification page for authority roles
/// (Sheikh, Mosque, Organization, Community Organizer)
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final ApiClient _apiClient = getIt<ApiClient>();
  final ImagePicker _imagePicker = ImagePicker();

  File? _profileImageFile;
  File? _documentFile;
  String? _profileImageName;
  String? _documentName;
  String? _uploadedProfileImageUrl;
  String? _uploadedDocumentUrl;
  bool _confirmed = false;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _isUploadingDocument = false;
  String? _errorMessage;

  bool get _canSubmit =>
      _uploadedProfileImageUrl != null &&
      _uploadedDocumentUrl != null &&
      _confirmed &&
      !_isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Emerald gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2E1C),
                  Color(0xFF0D3D26),
                  Color(0xFF0B2E23),
                  Color(0xFF071E18),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          // Subtle Islamic geometric pattern
          Positioned.fill(
            child: CustomPaint(painter: _IslamicPatternPainter()),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: KhairColors.secondary
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified_user_rounded,
                                color: KhairColors.secondary, size: 40),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Apply for Official\nOrganizer Status',
                            style: KhairTypography.h1.copyWith(
                              color: Colors.white,
                              fontSize: 28,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Upload your documents so our team can verify your identity',
                            style: KhairTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: KhairColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: KhairColors.error
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: KhairColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: KhairTypography.bodySmall.copyWith(
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Profile Image Upload
                        _buildUploadCard(
                          title: 'Official Profile Image',
                          description:
                              'A clear photo of yourself or your organization\'s logo',
                          icon: Icons.camera_alt_rounded,
                          isUploaded: _uploadedProfileImageUrl != null,
                          isUploading: _isUploadingImage,
                          fileName: _profileImageName,
                          file: _profileImageFile,
                          required: true,
                          onTap: _pickProfileImage,
                        ),
                        const SizedBox(height: 16),

                        // Document Upload
                        _buildUploadCard(
                          title: 'Qualification Document',
                          description:
                              'Certificate, license, or legal document (PDF or image)',
                          icon: Icons.description_rounded,
                          isUploaded: _uploadedDocumentUrl != null,
                          isUploading: _isUploadingDocument,
                          fileName: _documentName,
                          file: _documentFile,
                          required: true,
                          onTap: _pickDocument,
                        ),
                        const SizedBox(height: 24),

                        // Confirmation checkbox
                        GestureDetector(
                          onTap: () =>
                              setState(() => _confirmed = !_confirmed),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _confirmed
                                    ? KhairColors.secondary
                                        .withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: _confirmed
                                        ? KhairColors.secondary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _confirmed
                                          ? KhairColors.secondary
                                          : Colors.white
                                              .withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: _confirmed
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'I confirm that all provided documents are authentic and I am authorized to represent this organization.',
                                    style: KhairTypography.bodySmall.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KhairColors.secondary,
                              foregroundColor: const Color(0xFF1A1A2E),
                              disabledBackgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
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
                                      const Icon(Icons.send_rounded, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Submit for Review',
                                        style:
                                            KhairTypography.labelLarge.copyWith(
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
                          child: TextButton(
                            onPressed: () => context.go('/'),
                            child: Text(
                              'Skip for now — I\'ll do this later',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── File Pickers ──

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() {
        _profileImageFile = File(image.path);
        _profileImageName = image.name;
        _isUploadingImage = true;
        _errorMessage = null;
      });

      // Upload the image
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path, filename: image.name),
      });

      final response = await _apiClient.post('/upload/image', data: formData);
      final url = response.data['data']?['url'] ?? response.data['url'];

      setState(() {
        _uploadedProfileImageUrl = url;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _profileImageFile = null;
        _profileImageName = null;
        _errorMessage = 'Failed to upload image. Please try again.';
      });
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() {
        _documentFile = File(file.path!);
        _documentName = file.name;
        _isUploadingDocument = true;
        _errorMessage = null;
      });

      // Upload the document
      final formData = FormData.fromMap({
        'document':
            await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      final response =
          await _apiClient.post('/upload/document', data: formData);
      final url = response.data['data']?['url'] ?? response.data['url'];

      setState(() {
        _uploadedDocumentUrl = url;
        _isUploadingDocument = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingDocument = false;
        _documentFile = null;
        _documentName = null;
        _errorMessage = 'Failed to upload document. Please try again.';
      });
    }
  }

  // ── Submit ──

  void _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.post('/verification/submit', data: {
        'profile_image_path': _uploadedProfileImageUrl,
        'document_path': _uploadedDocumentUrl,
        'document_type': 'general',
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Show success and redirect
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0D3522),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: KhairColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: KhairColors.success, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Submitted!',
                style: KhairTypography.h2.copyWith(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'Your verification request has been submitted. Our team will review it within 24–48 hours. You\'ll receive a notification.',
            style: KhairTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.secondary,
                  foregroundColor: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Start Exploring',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['error'] ?? 'Submission failed')
          : 'Submission failed. Please try again.';
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg.toString();
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  // ── UI Builders ──

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/'),
          ),
          const Spacer(),
          Text(
            'Verification',
            style: KhairTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isUploaded,
    required bool isUploading,
    required bool required,
    String? fileName,
    File? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isUploaded
              ? KhairColors.success.withValues(alpha: 0.08)
              : isUploading
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded
                ? KhairColors.success.withValues(alpha: 0.4)
                : isUploading
                    ? KhairColors.secondary.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
            width: isUploaded ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Show image thumbnail if it's an image file that was picked
            if (file != null &&
                isUploaded &&
                (fileName?.endsWith('.jpg') == true ||
                    fileName?.endsWith('.jpeg') == true ||
                    fileName?.endsWith('.png') == true))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? KhairColors.success.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KhairColors.secondary,
                        ),
                      )
                    : Icon(
                        isUploaded ? Icons.check_circle_rounded : icon,
                        color: isUploaded
                            ? KhairColors.success
                            : Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: KhairTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (required)
                        Text(
                          ' *',
                          style: TextStyle(
                            color: KhairColors.error.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isUploading
                        ? 'Uploading...'
                        : isUploaded
                            ? fileName ?? 'Uploaded ✓'
                            : description,
                    style: KhairTypography.bodySmall.copyWith(
                      color: isUploaded
                          ? KhairColors.success.withValues(alpha: 0.8)
                          : isUploading
                              ? KhairColors.secondary.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!isUploading)
              Icon(
                isUploaded ? Icons.swap_horiz_rounded : Icons.upload_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Islamic Pattern (shared util) ─────────

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 60.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * spacing + (row.isOdd ? spacing / 2 : 0);
        final cy = row * spacing;
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 8;
          final x = cx + 14 * math.cos(angle);
          final y = cy + 14 * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
