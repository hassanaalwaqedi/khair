import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _preferredLanguage = 'en';
  String? _avatarUrl;
  Uint8List? _pendingImageBytes; // local preview only
  bool _loading = true;
  bool _saving = false;
  bool _moderatingImage = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final dio = getIt<Dio>();
      final resp = await dio.get('/profile');
      final data = resp.data['data'] ?? resp.data;
      setState(() {
        _displayNameCtrl.text = data['display_name'] ?? '';
        _bioCtrl.text = data['bio'] ?? '';
        _cityCtrl.text = data['city'] ?? '';
        _countryCtrl.text = data['country'] ?? '';
        _locationCtrl.text = data['location'] ?? '';
        _preferredLanguage = data['preferred_language'] ?? 'en';
        _avatarUrl = data['avatar_url'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = context.l10n.failedLoadProfile;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final dio = getIt<Dio>();
      await dio.put('/profile', data: {
        'display_name': _displayNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'preferred_language': _preferredLanguage,
        // Only send real URLs, not data: URLs
        if (_avatarUrl != null && !_avatarUrl!.startsWith('data:'))
          'avatar_url': _avatarUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(context.l10n.profileUpdatedSuccess),
              ],
            ),
            backgroundColor: KhairColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data != null && data['error'] == 'content_moderation_failed') {
        _showModerationWarning(data['warning'] ?? context.l10n.contentNotAllowed);
      } else {
        final detail = data != null ? data['error']?.toString() ?? '' : '';
        setState(() => _errorMessage = '${context.l10n.failedSaveProfile}: $detail');
      }
    } catch (e) {
      setState(() => _errorMessage = '${context.l10n.failedSaveProfile}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndModerateImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _moderatingImage = true);

      // Read image bytes
      final bytes = await picked.readAsBytes();

      // Moderate image via AI
      final dio = getIt<Dio>();
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: picked.name,
        ),
      });

      final modResp = await dio.post(
        '/profile/moderate-image',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final modData = modResp.data['data'] ?? modResp.data;
      if (modData['passed'] != true) {
        if (mounted) {
          _showModerationWarning(
              modData['warning'] ?? context.l10n.contentNotAllowed);
        }
        setState(() => _moderatingImage = false);
        return;
      }

      // Image passed moderation — upload to server
      final uploadFormData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: picked.name,
        ),
      });

      final uploadResp = await dio.post(
        '/profile/upload-avatar',
        data: uploadFormData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final uploadData = uploadResp.data['data'] ?? uploadResp.data;
      final uploadedUrl = uploadData['avatar_url'] as String?;

      setState(() {
        _moderatingImage = false;
        _pendingImageBytes = bytes;
        if (uploadedUrl != null) _avatarUrl = uploadedUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(context.l10n.imageApproved),
              ],
            ),
            backgroundColor: KhairColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _moderatingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failedProcessImage),
            backgroundColor: KhairColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showModerationWarning(String warning) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: KhairColors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: KhairColors.warning, size: 32),
        ),
        title: Text(context.l10n.contentNotAllowed),
        content: Text(
          warning,
          style: KhairTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.understood),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.editProfile),
        backgroundColor: KhairColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.l10n.save,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(isDark),
    );
  }

  Widget _buildForm(bool isDark) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Error banner
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: KhairColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: KhairColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: KhairColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: KhairColors.error))),
                ],
              ),
            ),

          // Avatar section
          Center(child: _buildAvatarSection(isDark)),
          const SizedBox(height: 28),

          // Form fields
          _buildTextField(
            controller: _displayNameCtrl,
            label: context.l10n.displayName,
            icon: Icons.person_outline,
            isDark: isDark,
            validator: (v) =>
                v == null || v.trim().isEmpty ? context.l10n.nameRequired : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _bioCtrl,
            label: context.l10n.bio,
            icon: Icons.info_outline,
            isDark: isDark,
            maxLines: 4,
            hint: context.l10n.tellUsAboutYourself,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _cityCtrl,
            label: context.l10n.city,
            icon: Icons.location_city_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _countryCtrl,
            label: context.l10n.country,
            icon: Icons.public_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _locationCtrl,
            label: context.l10n.fullAddress,
            icon: Icons.map_outlined,
            isDark: isDark,
            hint: context.l10n.yourLocationOrAddress,
          ),
          const SizedBox(height: 16),

          // Language selector
          _buildLanguageSelector(isDark),
          const SizedBox(height: 32),

          // AI moderation notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KhairColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: KhairColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KhairColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: KhairColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.aiModerationNotice,
                    style: KhairTypography.bodySmall.copyWith(
                      color: KhairColors.info,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(bool isDark) {
    return GestureDetector(
      onTap: _moderatingImage ? null : _pickAndModerateImage,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      KhairColors.primary,
                      KhairColors.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  border: Border.all(
                    color: KhairColors.primary.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: _moderatingImage
                    ? const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : _pendingImageBytes != null
                        ? ClipOval(
                            child: Image.memory(
                                _pendingImageBytes!,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100))
                        : _avatarUrl != null && _avatarUrl!.startsWith('http')
                            ? ClipOval(
                                child: Image.network(_avatarUrl!,
                                    fit: BoxFit.cover, width: 100, height: 100))
                            : _avatarUrl != null && _avatarUrl!.startsWith('/')
                                ? ClipOval(
                                    child: Image.network(
                                        '${const String.fromEnvironment('API_URL', defaultValue: 'https://khair.it.com/api/v1').replaceAll('/api/v1', '')}$_avatarUrl',
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100))
                                : Center(
                                    child: Text(
                                      _displayNameCtrl.text.isNotEmpty
                                          ? _displayNameCtrl.text[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: KhairColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDark ? KhairColors.darkBackground : Colors.white,
                        width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _moderatingImage ? context.l10n.checkingImage : context.l10n.tapToChangePhoto,
            style: KhairTypography.labelSmall.copyWith(
              color: _moderatingImage
                  ? KhairColors.warning
                  : KhairColors.textTertiary,
            ),
          ),
          if (_moderatingImage)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.aiVerifyingPhoto,
                style: KhairTypography.labelSmall.copyWith(
                  color: KhairColors.warning,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? KhairColors.darkCard : KhairColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? KhairColors.darkBorder : KhairColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? KhairColors.darkBorder : KhairColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KhairColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildLanguageSelector(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _preferredLanguage,
      decoration: InputDecoration(
        labelText: context.l10n.preferredLanguage,
        prefixIcon: const Icon(Icons.language, size: 20),
        filled: true,
        fillColor: isDark ? KhairColors.darkCard : KhairColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? KhairColors.darkBorder : KhairColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? KhairColors.darkBorder : KhairColors.border),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'en', child: Text('English')),
        DropdownMenuItem(value: 'ar', child: Text('العربية')),
        DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
      ],
      onChanged: (v) => setState(() => _preferredLanguage = v ?? 'en'),
    );
  }
}
