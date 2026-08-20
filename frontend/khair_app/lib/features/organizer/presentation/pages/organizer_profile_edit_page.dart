import 'package:khair_app/core/locale/l10n_extension.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_components.dart';
import '../../../../core/widgets/discard_changes_dialog.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/utils/image_upload_client.dart';
import '../../../../core/utils/image_upload_validator.dart';
import '../../domain/entities/organizer.dart';
import '../../domain/repositories/organizer_repository.dart';
import '../bloc/organizer_bloc.dart';

/// Organizer profile editing page with form validation, save with loading,
/// and success/error feedback via SnackBar.
class OrganizerProfileEditPage extends StatefulWidget {
  const OrganizerProfileEditPage({super.key});

  @override
  State<OrganizerProfileEditPage> createState() =>
      _OrganizerProfileEditPageState();
}

class _OrganizerProfileEditPageState extends State<OrganizerProfileEditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _cityController;
  late TextEditingController _countryController;

  bool _isInitialized = false;
  bool _hydrating = false;
  bool _allowPop = false;
  bool _discardDialogOpen = false;
  bool _saveRequested = false;
  List<String> _initialValues = const [];

  bool _uploadingImage = false;
  String? _logoUrl;
  Uint8List? _logoPreview;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _websiteController = TextEditingController();
    _cityController = TextEditingController();
    _countryController = TextEditingController();
    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }

    // Load profile if not already loaded
    final state = context.read<OrganizerBloc>().state;
    if (state.organizer == null) {
      context.read<OrganizerBloc>().add(LoadOrganizerProfile());
    } else {
      _populateFields(state.organizer!);
    }
  }

  void _populateFields(Organizer organizer) {
    _hydrating = true;
    _nameController.text = organizer.name;
    _descriptionController.text = organizer.description ?? '';
    _emailController.text = organizer.email ?? '';
    _phoneController.text = organizer.phone ?? '';
    _websiteController.text = organizer.website ?? '';
    _cityController.text = organizer.city ?? '';
    _countryController.text = organizer.country ?? '';
    _logoUrl = organizer.logoUrl;
    _captureInitialValues();
    _hydrating = false;
    _isInitialized = true;
  }

  List<TextEditingController> get _controllers => [
        _nameController,
        _descriptionController,
        _emailController,
        _phoneController,
        _websiteController,
        _cityController,
        _countryController,
      ];

  List<String> get _currentValues =>
      _controllers.map((controller) => controller.text).toList();

  void _captureInitialValues() {
    _initialValues = _currentValues;
  }

  bool get _hasUnsavedChanges {
    if (!_isInitialized || _initialValues.length != _currentValues.length) {
      return false;
    }
    for (var index = 0; index < _initialValues.length; index++) {
      if (_initialValues[index] != _currentValues[index]) return true;
    }
    return false;
  }

  void _onFieldChanged() {
    if (!_hydrating && mounted) setState(() {});
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop || _discardDialogOpen) return;
    if (!_hasUnsavedChanges) {
      context.popOrGo('/organizer');
      return;
    }
    _discardDialogOpen = true;
    final discard = await showDiscardChangesDialog(context);
    if (!mounted) return;
    _discardDialogOpen = false;
    if (!discard) return;
    setState(() => _allowPop = true);
    context.popOrGo('/organizer');
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final params = UpdateProfileParams(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      logoUrl: _logoUrl,
    );

    _saveRequested = true;
    context.read<OrganizerBloc>().add(UpdateOrganizerProfile(params));
  }

  Future<void> _pickLogo() async {
    if (_uploadingImage) return;
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final issue = await inspectImageUpload(filename: image.name, bytes: bytes);
    if (!mounted) return;
    setState(() {
      _logoPreview = bytes;
      _uploadingImage = true;
    });
    if (issue != null) {
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(imageUploadIssueMessage(issue)),
        backgroundColor: KhairColors.error,
      ));
      return;
    }

    try {
      final url = await uploadImageBytes(
        dio: getIt<Dio>(),
        path: '/upload/image',
        bytes: bytes,
        filename: image.name,
      );
      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _uploadingImage = false;
        _onFieldChanged();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(imageUploadFailureMessage(error)),
          backgroundColor: KhairColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: (_allowPop || !_hasUnsavedChanges) && context.canNavigateBack,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.editProfile),
        ),
        body: BlocConsumer<OrganizerBloc, OrganizerState>(
          listener: (context, state) {
            // Populate fields when profile loads for the first time
            if (state.organizer != null && !_isInitialized) {
              _populateFields(state.organizer!);
              setState(() {});
            }

            // Success feedback
            if (state.profileStatus == OrganizerStatus.success &&
                _saveRequested) {
              _saveRequested = false;
              _captureInitialValues();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text(context.l10n.profileUpdatedSuccessfully),
                    ],
                  ),
                  backgroundColor: KhairColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: KhairRadius.medium,
                  ),
                ),
              );
            }

            // Error feedback
            if (state.profileStatus == OrganizerStatus.failure &&
                _saveRequested) {
              _saveRequested = false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            state.errorMessage ?? 'Failed to update profile'),
                      ),
                    ],
                  ),
                  backgroundColor: KhairColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: KhairRadius.medium,
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            // Loading profile
            if (state.isProfileLoading && state.organizer == null) {
              return KhairLoadingState(message: context.l10n.loadingProfile);
            }

            // Error loading profile
            if (state.profileStatus == OrganizerStatus.failure &&
                state.organizer == null) {
              return KhairErrorState(
                message: state.errorMessage ?? 'Failed to load profile.',
                onRetry: () {
                  context.read<OrganizerBloc>().add(LoadOrganizerProfile());
                },
              );
            }

            final isSaving = state.isProfileLoading && state.organizer != null;

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile header
                      if (state.organizer != null) ...[
                        Row(
                          children: [
                            InkWell(
                              onTap: _uploadingImage ? null : _pickLogo,
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: KhairColors.primarySurface,
                                      borderRadius: BorderRadius.circular(16),
                                      image: _logoPreview != null
                                          ? DecorationImage(
                                              image: MemoryImage(_logoPreview!),
                                              fit: BoxFit.cover,
                                            )
                                          : _logoUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                      ApiConfig.resolveUrl(
                                                          _logoUrl!)),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                    ),
                                    child:
                                        _logoPreview == null && _logoUrl == null
                                            ? Icon(Icons.business_rounded,
                                                color: KhairColors.primary,
                                                size: 32)
                                            : null,
                                  ),
                                  if (_uploadingImage)
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.organizer!.name,
                                    style: KhairTypography.h3,
                                  ),
                                  SizedBox(height: 4),
                                  StatusBadge(
                                    status:
                                        state.organizer!.status.toUpperCase(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32),
                      ],

                      // Form fields
                      _buildField(
                        'Organization Name *',
                        _nameController,
                        Icons.business_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      _buildField(
                        'Bio / Description',
                        _descriptionController,
                        Icons.description_outlined,
                        maxLines: 3,
                      ),
                      _buildField(
                        'Contact Email',
                        _emailController,
                        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !v.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildField(
                        'Phone',
                        _phoneController,
                        Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildField(
                        'Website',
                        _websiteController,
                        Icons.language_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _buildField(
                        'City',
                        _cityController,
                        Icons.location_city_outlined,
                      ),
                      _buildField(
                        'Country',
                        _countryController,
                        Icons.flag_outlined,
                      ),

                      SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _onSave,
                          child: isSaving
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(context.l10n.ownerSaveChanges),
                        ),
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.emailAddress ||
                keyboardType == TextInputType.url)
            ? TextDirection.ltr
            : null,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
