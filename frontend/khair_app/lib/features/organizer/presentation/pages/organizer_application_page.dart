import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';
import 'package:khair_app/features/organizer/presentation/bloc/organizer_bloc.dart';
import 'package:khair_app/features/organizer/domain/repositories/organizer_repository.dart';

/// Organizer Application Page - Convert real organizations
class OrganizerApplicationPage extends StatefulWidget {
  const OrganizerApplicationPage({super.key});

  @override
  State<OrganizerApplicationPage> createState() => _OrganizerApplicationPageState();
}

class _OrganizerApplicationPageState extends State<OrganizerApplicationPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitted = false;

  // Form controllers
  final _orgNameController = TextEditingController();
  final _orgTypeController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgTypeController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocListener<OrganizerBloc, OrganizerState>(
      listener: (context, state) {
        if (state.applicationStatus == OrganizerStatus.success) {
          setState(() => _isSubmitted = true);
        } else if (state.applicationStatus == OrganizerStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Failed to submit application. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register Organization'),
        ),
        body: _isSubmitted ? _buildSuccessState() : _buildApplicationForm(isWide),
      ),
    );
  }

  Widget _buildApplicationForm(bool isWide) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildInfoCards(isWide),
              const SizedBox(height: 32),
              _buildProgressSteps(),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: _buildCurrentStep(),
              ),
              const SizedBox(height: 32),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Become a Verified Organizer', style: KhairTypography.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Join Khair to publish events and reach the Muslim community in your area.',
          style: KhairTypography.bodyLarge.copyWith(color: KhairColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildInfoCards(bool isWide) {
    final cards = [
      _InfoCard(icon: Icons.verified_user, title: 'Who Can Apply',
        description: 'Mosques, Islamic centers, educational institutions, and community organizations.'),
      _InfoCard(icon: Icons.fact_check, title: 'Verification Process',
        description: 'We verify all applications to ensure authenticity and trust.'),
      _InfoCard(icon: Icons.schedule, title: 'Review Time',
        description: 'Most applications are reviewed within 2-3 business days.'),
    ];

    if (isWide) {
      return Row(
        children: cards.map((card) => Expanded(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: card),
        )).toList(),
      );
    }
    return Column(
      children: cards.map((card) => Padding(
        padding: const EdgeInsets.only(bottom: 12), child: card,
      )).toList(),
    );
  }

  Widget _buildProgressSteps() {
    final steps = ['Organization Info', 'Contact Details', 'Review & Submit'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: KhairColors.surfaceVariant, borderRadius: KhairRadius.medium),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? KhairColors.success : isActive ? KhairColors.primary : KhairColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text('${index + 1}', style: KhairTypography.labelLarge.copyWith(
                            color: isActive ? Colors.white : KhairColors.textTertiary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(steps[index],
                    style: KhairTypography.labelMedium.copyWith(
                      color: isActive ? KhairColors.textPrimary : KhairColors.textTertiary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (index < steps.length - 1) ...[
                  const SizedBox(width: 8),
                  Container(width: 24, height: 2, color: isCompleted ? KhairColors.success : KhairColors.border),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildOrganizationInfoStep();
      case 1: return _buildContactDetailsStep();
      case 2: return _buildReviewStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildOrganizationInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Organization Information', style: KhairTypography.headlineMedium),
        const SizedBox(height: 24),
        _buildFormField(label: 'Organization Name *', hint: 'e.g., Al-Noor Islamic Center',
          controller: _orgNameController, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
        const SizedBox(height: 16),
        _buildFormField(label: 'Organization Type *', hint: 'e.g., Mosque, Islamic Center, School',
          controller: _orgTypeController, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
        const SizedBox(height: 16),
        _buildFormField(label: 'Website (Optional)', hint: 'https://www.example.com', controller: _websiteController),
        const SizedBox(height: 16),
        _buildFormField(label: 'Address *', hint: 'Street address',
          controller: _addressController, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildFormField(label: 'City *', hint: 'City',
            controller: _cityController, validator: (v) => v?.isEmpty ?? true ? 'Required' : null)),
          const SizedBox(width: 16),
          Expanded(child: _buildFormField(label: 'Country *', hint: 'Country',
            controller: _countryController, validator: (v) => v?.isEmpty ?? true ? 'Required' : null)),
        ]),
        const SizedBox(height: 16),
        _buildFormField(label: 'Description *', hint: 'Tell us about your organization...',
          controller: _descriptionController, maxLines: 4,
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
      ],
    );
  }

  Widget _buildContactDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact Details', style: KhairTypography.headlineMedium),
        const SizedBox(height: 8),
        Text('This information will be used to verify your organization and send important updates.',
          style: KhairTypography.bodyMedium),
        const SizedBox(height: 24),
        _buildFormField(label: 'Contact Person Name *', hint: 'Full name',
          controller: _contactNameController, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
        const SizedBox(height: 16),
        _buildFormField(label: 'Email Address *', hint: 'contact@organization.com',
          controller: _emailController, keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Required';
            if (!v!.contains('@')) return 'Invalid email';
            return null;
          }),
        const SizedBox(height: 16),
        _buildFormField(label: 'Phone Number *', hint: '+1 (555) 123-4567',
          controller: _phoneController, keyboardType: TextInputType.phone,
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Your Application', style: KhairTypography.headlineMedium),
        const SizedBox(height: 8),
        Text('Please review the information below before submitting.', style: KhairTypography.bodyMedium),
        const SizedBox(height: 24),
        _buildReviewSection('Organization', [
          _ReviewItem('Name', _orgNameController.text),
          _ReviewItem('Type', _orgTypeController.text),
          _ReviewItem('Website', _websiteController.text.isEmpty ? 'Not provided' : _websiteController.text),
          _ReviewItem('Address', _addressController.text),
          _ReviewItem('City', _cityController.text),
          _ReviewItem('Country', _countryController.text),
        ]),
        const SizedBox(height: 16),
        _buildReviewSection('Contact', [
          _ReviewItem('Name', _contactNameController.text),
          _ReviewItem('Email', _emailController.text),
          _ReviewItem('Phone', _phoneController.text),
        ]),
        const SizedBox(height: 16),
        _buildReviewSection('Description', [_ReviewItem('', _descriptionController.text)]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KhairColors.infoLight,
            borderRadius: KhairRadius.medium,
            border: Border.all(color: KhairColors.info.withAlpha(51)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: KhairColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'By submitting this application, you agree to our Terms of Service, Privacy Policy, and Organizer Agreement. You confirm that all information provided is accurate.',
                  style: KhairTypography.bodyMedium.copyWith(color: KhairColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(String title, List<_ReviewItem> items) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: KhairColors.border), borderRadius: KhairRadius.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: KhairColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(KhairRadius.md)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: KhairTypography.labelLarge),
                TextButton(onPressed: () => setState(() => _currentStep = title == 'Contact' ? 1 : 0),
                  child: const Text('Edit')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                if (item.label.isEmpty) return Text(item.value, style: KhairTypography.bodyMedium);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 100, child: Text(item.label, style: KhairTypography.labelMedium)),
                      Expanded(child: Text(item.value, style: KhairTypography.bodyMedium)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label, required String hint, required TextEditingController controller,
    int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KhairTypography.labelLarge),
        const SizedBox(height: 8),
        TextFormField(controller: controller, maxLines: maxLines, keyboardType: keyboardType,
          validator: validator, decoration: InputDecoration(hintText: hint)),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final isSubmitting = context.watch<OrganizerBloc>().state.applicationStatus == OrganizerStatus.loading;
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(child: KhairButton(label: 'Back', isOutlined: true,
            onPressed: () => setState(() => _currentStep--))),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          child: KhairButton(
            label: _currentStep == 2 ? 'Submit Application' : 'Continue',
            isLoading: isSubmitting, fullWidth: true, onPressed: _handleNext,
          ),
        ),
      ],
    );
  }

  void _handleNext() {
    if (_currentStep < 2) {
      if (_formKey.currentState?.validate() ?? false) {
        setState(() => _currentStep++);
      }
    } else {
      _submitApplication();
    }
  }

  void _submitApplication() {
    final params = OrganizerApplicationParams(
      name: _orgNameController.text.trim(),
      organizationType: _orgTypeController.text.trim(),
      description: _descriptionController.text.trim(),
      street: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
    );
    context.read<OrganizerBloc>().add(ApplyAsOrganizer(params));
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: KhairColors.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 56, color: KhairColors.success),
            ),
            const SizedBox(height: 32),
            Text('Application Submitted!', style: KhairTypography.displaySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              'Thank you for applying to become a verified organizer on Khair. We will review your application and get back to you within 2-3 business days.',
              style: KhairTypography.bodyLarge.copyWith(color: KhairColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: KhairColors.surfaceVariant, borderRadius: KhairRadius.medium),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined, color: KhairColors.textSecondary),
                  const SizedBox(width: 12),
                  Text('Confirmation sent to ${_emailController.text}', style: KhairTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 32),
            KhairButton(label: 'Go to Dashboard', onPressed: () => context.go('/organizer/dashboard')),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KhairColors.surface, borderRadius: KhairRadius.medium,
        border: Border.all(color: KhairColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: KhairColors.primarySurface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: KhairColors.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: KhairTypography.labelLarge),
          const SizedBox(height: 4),
          Text(description, style: KhairTypography.bodySmall),
        ],
      ),
    );
  }
}

class _ReviewItem {
  final String label;
  final String value;
  _ReviewItem(this.label, this.value);
}
