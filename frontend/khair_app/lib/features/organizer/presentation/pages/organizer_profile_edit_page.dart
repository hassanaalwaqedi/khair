import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_components.dart';
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

    // Load profile if not already loaded
    final state = context.read<OrganizerBloc>().state;
    if (state.organizer == null) {
      context.read<OrganizerBloc>().add(const LoadOrganizerProfile());
    } else {
      _populateFields(state.organizer!);
    }
  }

  void _populateFields(Organizer organizer) {
    _nameController.text = organizer.name;
    _descriptionController.text = organizer.description ?? '';
    _emailController.text = organizer.email ?? '';
    _phoneController.text = organizer.phone ?? '';
    _websiteController.text = organizer.website ?? '';
    _cityController.text = organizer.city ?? '';
    _countryController.text = organizer.country ?? '';
    _isInitialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _countryController.dispose();
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
    );

    context.read<OrganizerBloc>().add(UpdateOrganizerProfile(params));
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
              _isInitialized) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Profile updated successfully'),
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
          if (state.profileStatus == OrganizerStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
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
            return const KhairLoadingState(message: 'Loading profile...');
          }

          // Error loading profile
          if (state.profileStatus == OrganizerStatus.failure &&
              state.organizer == null) {
            return KhairErrorState(
              message: state.errorMessage ?? 'Failed to load profile.',
              onRetry: () {
                context
                    .read<OrganizerBloc>()
                    .add(const LoadOrganizerProfile());
              },
            );
          }

          final isSaving = state.isProfileLoading && state.organizer != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  if (state.organizer != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: KhairColors.primarySurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.business_rounded,
                              color: KhairColors.primary, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.organizer!.name,
                                style: KhairTypography.h3,
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(
                                status: state.organizer!.status
                                    .toUpperCase(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
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

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _onSave,
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
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
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
