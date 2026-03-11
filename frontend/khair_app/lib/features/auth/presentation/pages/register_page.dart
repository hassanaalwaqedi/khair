import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../data/models/country_model.dart';
import '../../data/datasources/countries_datasource.dart';
import '../bloc/registration_bloc.dart';
import '../widgets/role_selection_step.dart';
import '../widgets/account_details_step.dart';
import '../widgets/goals_step.dart';
import '../widgets/review_step.dart';
import '../widgets/country_search_field.dart';
import '../widgets/media_upload_step.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RegistrationBloc>(),
      child: const _RegisterWizard(),
    );
  }
}

class _RegisterWizard extends StatefulWidget {
  const _RegisterWizard();

  @override
  State<_RegisterWizard> createState() => _RegisterWizardState();
}

class _RegisterWizardState extends State<_RegisterWizard>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  String? _selectedRole;
  final _selectedGoals = <String>{};
  bool _isSubmitting = false;

  // Country state
  List<Country> _countries = [];
  Country? _selectedCountry;
  bool _countriesLoading = true;

  // Image upload state
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  // Role-specific controllers
  final _specializationController = TextEditingController();
  final _yearsController = TextEditingController();
  final _socialController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _focusController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Page controller for smooth transitions
  late final PageController _pageController;

  // Verification controllers
  final _codeController = TextEditingController();

  /// Dynamic step labels based on selected role
  List<String> get _stepLabels {
    if (_selectedRole != null && isAuthorityRole(_selectedRole!)) {
      return ['Role', 'Account', 'Goals', 'Upload', 'Review'];
    }
    return ['Role', 'Account', 'Goals', 'Review'];
  }

  /// The step index where the review step begins
  int get _reviewStepIndex => _stepLabels.length - 1;

  /// The step index where the verification code page is shown
  int get _verificationStepIndex => _stepLabels.length;

  /// The step index where the done page is shown
  int get _doneStepIndex => _stepLabels.length + 1;

  /// Whether the current role has an upload step
  bool get _hasUploadStep =>
      _selectedRole != null && isAuthorityRole(_selectedRole!);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final ds = CountriesDataSource(getIt());
      final countries = await ds.getAll();
      if (mounted) {
        setState(() {
          _countries = countries;
          _countriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _countriesLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _specializationController.dispose();
    _yearsController.dispose();
    _socialController.dispose();
    _orgNameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _focusController.dispose();
    _pageController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegistrationBloc, RegistrationState>(
      listener: _blocListener,
      child: Scaffold(
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
              child: CustomPaint(
                painter: _IslamicPatternPainter(),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  _buildProgressBar(),
                  Expanded(
                    child: _currentStep <= _reviewStepIndex
                        ? _buildStepContent()
                        : _buildVerificationOrDone(),
                  ),
                  if (_currentStep <= _reviewStepIndex) _buildBottomButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_currentStep > 0 && _currentStep < 4) {
                _goToStep(_currentStep - 1);
              } else {
                context.go('/');
              }
            },
          ),
          const Spacer(),
          Text(
            'Khair',
            style: KhairTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(
              context.l10n.signIn,
              style: TextStyle(
                color: KhairColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Bar ────────────────────────────

  Widget _buildProgressBar() {
    final displayStep = _currentStep.clamp(0, 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${context.l10n.registrationProgressRole} ${displayStep + 1} / ${_stepLabels.length}',
                style: KhairTypography.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _stepLabels[displayStep],
                style: KhairTypography.labelSmall.copyWith(
                  color: KhairColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_stepLabels.length, (i) {
              final isCompleted = i < displayStep;
              final isCurrent = i == displayStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsetsDirectional.only(end: i < 3 ? 6 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isCompleted
                          ? KhairColors.secondary
                          : isCurrent
                              ? KhairColors.secondary.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Step Content ────────────────────────────

  Widget _buildStepContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentStep),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return RoleSelectionStep(
          selectedRole: _selectedRole,
          onRoleSelected: (role) {
            setState(() => _selectedRole = role);
          },
        );
      case 1:
        return AccountDetailsStep(
          selectedRole: _selectedRole!,
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          nameController: _nameController,
          cityController: _cityController,
          countryWidget: CountrySearchField(
            countries: _countries,
            selectedCountry: _selectedCountry,
            isLoading: _countriesLoading,
            onCountrySelected: (c) => setState(() => _selectedCountry = c),
          ),
          specializationController: _specializationController,
          yearsController: _yearsController,
          socialController: _socialController,
          orgNameController: _orgNameController,
          phoneController: _phoneController,
          focusController: _focusController,
          obscurePassword: _obscurePassword,
          obscureConfirm: _obscureConfirm,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onToggleConfirm: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        );
      case 2:
        return GoalsStep(
          selectedGoals: _selectedGoals,
          onGoalToggled: (goal) {
            setState(() {
              if (_selectedGoals.contains(goal)) {
                _selectedGoals.remove(goal);
              } else {
                _selectedGoals.add(goal);
              }
            });
          },
        );
      default:
        break;
    }

    // For authority roles: step 3 = Upload, step 4 = Review
    // For simple roles: step 3 = Review
    if (_hasUploadStep && _currentStep == 3) {
      return MediaUploadStep(
        selectedImage: _selectedImage,
        uploadedImageUrl: _uploadedImageUrl,
        isUploading: _isUploadingImage,
        onImageSelected: (file) {
          setState(() {
            _selectedImage = file;
            _uploadedImageUrl = null;
          });
        },
      );
    }

    if (_currentStep == _reviewStepIndex) {
      return ReviewStep(
        selectedRole: _selectedRole!,
        roleLabelText: _getRoleLabel(context, _selectedRole!),
        name: _nameController.text,
        email: _emailController.text,
        goals: _selectedGoals,
        roleSpecificData: _collectRoleSpecificData(),
        isSubmitting: _isSubmitting,
        onSubmit: _submitRegistration,
      );
    }

    return const SizedBox.shrink();
  }

  // ─── Bottom Buttons ──────────────────────────

  Widget _buildBottomButtons() {
    final canContinue = _canContinue();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          if (_currentStep > 0 && _currentStep < _reviewStepIndex)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(_currentStep - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side:
                      BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(context.l10n.cancel, // using cancel for back button here
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          if (_currentStep > 0 && _currentStep < _reviewStepIndex)
            const SizedBox(width: 12),
          if (_currentStep < _reviewStepIndex)
            Expanded(
              child: ElevatedButton(
                onPressed: canContinue ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.secondary,
                  foregroundColor: const Color(0xFF1A1A2E),
                  disabledBackgroundColor:
                      Colors.white.withValues(alpha: 0.08),
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  context.l10n.registrationContinue,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Verification / Done ─────────────────────

  Widget _buildVerificationOrDone() {
    return BlocBuilder<RegistrationBloc, RegistrationState>(
      builder: (context, state) {
        if (state.status == RegistrationStatus.complete) {
          return _buildDoneState();
        }
        return _buildVerificationState(state);
      },
    );
  }

  Widget _buildVerificationState(RegistrationState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: KhairColors.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_unread_rounded,
                color: KhairColors.secondary, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.registrationVerifyEmailTitle,
            style: KhairTypography.h2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to\n${_emailController.text}',
            style: KhairTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 28,
                letterSpacing: 12,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: KhairColors.secondary, width: 1.5),
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
            ),
          ],
          if (state.resendSuccess) ...[
            const SizedBox(height: 12),
            Text(
              'A new code has been sent!',
              style: TextStyle(color: KhairColors.success, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: state.status == RegistrationStatus.loading
                  ? null
                  : () {
                      if (_codeController.text.length == 6) {
                        context.read<RegistrationBloc>().add(
                              SubmitVerificationCode(
                                email: _emailController.text,
                                code: _codeController.text,
                              ),
                            );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: KhairColors.secondary,
                foregroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: state.status == RegistrationStatus.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(context.l10n.registrationVerifyEmailButton,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: state.status == RegistrationStatus.loading
                ? null
                : () {
                    context.read<RegistrationBloc>().add(
                          ResendVerificationCode(
                              email: _emailController.text),
                        );
                  },
            child: Text(
              context.l10n.registrationResendCode,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    final backendRole = mapToBackendRole(_selectedRole ?? 'student');
    final isAuthority = isAuthorityRole(_selectedRole ?? 'student');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: KhairColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: KhairColors.success, size: 56),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.registrationCompleteTitle,
            style: KhairTypography.h1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            _getWelcomeMessage(context, backendRole),
            style: KhairTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (isAuthority) {
                  context.go('/verification');
                } else {
                  context.go('/');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: KhairColors.secondary,
                foregroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isAuthority ? context.l10n.registrationRoleStepTitleOrganization : context.l10n.browseEvents,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logic ───────────────────────────────────

  bool _canContinue() {
    switch (_currentStep) {
      case 0:
        return _selectedRole != null;
      case 1:
        return true; // validation happens on tap
      case 2:
        return true; // goals are optional
      case 3:
        return true; // upload is optional
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }

    // If leaving upload step and an image was selected but not uploaded, upload it
    if (_hasUploadStep && _currentStep == 3 && _selectedImage != null && _uploadedImageUrl == null) {
      setState(() => _isUploadingImage = true);
      context.read<RegistrationBloc>().add(UploadImage(_selectedImage!));
      return; // Wait for upload result in _blocListener
    }

    _goToStep(_currentStep + 1);
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  void _submitRegistration() {
    setState(() => _isSubmitting = true);

    final backendRole = mapToBackendRole(_selectedRole!);
    final bloc = context.read<RegistrationBloc>();

    // Simple roles: submit everything in one go
    if (!isAuthorityRole(_selectedRole!)) {
      bloc.add(SubmitSimpleRegistration(
        role: backendRole,
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ));
      return;
    }

    // Authority roles: submit step by step
    bloc.add(SubmitStep1(
      role: backendRole,
      email: _emailController.text.trim(),
      password: _passwordController.text,
    ));
  }

  void _blocListener(BuildContext context, RegistrationState state) {
    if (state.status == RegistrationStatus.failure) {
      setState(() {
        _isSubmitting = false;
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Registration failed'),
          backgroundColor: KhairColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Image uploaded successfully → proceed to next step
    if (state.imageUrl != null && _isUploadingImage) {
      setState(() {
        _isUploadingImage = false;
        _uploadedImageUrl = state.imageUrl;
      });
      _goToStep(_currentStep + 1);
      return;
    }

    // After step 1 success for authority roles → submit step 2
    if (state.status == RegistrationStatus.success && state.currentStep == 2) {
      context.read<RegistrationBloc>().add(SubmitStep2(
            displayName: _nameController.text.trim(),
            bio: '',
            location: '',
            city: _cityController.text.trim(),
            country: _selectedCountry?.name ?? '',
            language: 'en',
          ));
      return;
    }

    // After step 2 → submit step 3 (with logo_url if available)
    if (state.status == RegistrationStatus.success && state.currentStep == 3) {
      final step3Data = _collectStep3Data();
      if (_uploadedImageUrl != null) {
        step3Data['logo_url'] = _uploadedImageUrl;
      }
      context.read<RegistrationBloc>().add(SubmitStep3(step3Data));
      return;
    }

    // After step 3 → submit step 4
    if (state.status == RegistrationStatus.success && state.currentStep == 4) {
      context.read<RegistrationBloc>().add(const SubmitStep4());
      return;
    }

    // Pending verification → show verification UI
    if (state.status == RegistrationStatus.pendingVerification) {
      setState(() {
        _isSubmitting = false;
        _currentStep = _verificationStepIndex;
      });
      return;
    }

    // Complete → redirect
    if (state.status == RegistrationStatus.complete) {
      setState(() {
        _isSubmitting = false;
        _currentStep = _doneStepIndex;
      });
    }
  }

  Map<String, dynamic> _collectStep3Data() {
    final data = <String, dynamic>{
      'goals': _selectedGoals.toList(),
    };

    switch (_selectedRole) {
      case 'sheikh':
        data['specialization'] = _specializationController.text.trim();
        if (_yearsController.text.isNotEmpty) {
          data['years_experience'] =
              int.tryParse(_yearsController.text) ?? 0;
        }
        if (_socialController.text.isNotEmpty) {
          data['social_media'] = _socialController.text.trim();
        }
        break;
      case 'organization_mosque':
      case 'organization_quran':
      case 'organization':
        data['org_name'] = _orgNameController.text.trim();
        data['org_city'] = _cityController.text.trim();
        data['org_country'] = _selectedCountry?.name ?? '';
        if (_phoneController.text.isNotEmpty) {
          data['phone'] = _phoneController.text.trim();
        }
        data['org_type'] = _selectedRole == 'organization_mosque'
            ? 'mosque'
            : _selectedRole == 'organization_quran'
                ? 'quran_center'
                : 'organization';
        break;
      case 'community_organizer':
      case 'volunteer':
        data['org_name'] = _orgNameController.text.trim();
        data['community_focus'] = _focusController.text.trim();
        data['org_city'] = _cityController.text.trim();
        data['org_country'] = _selectedCountry?.name ?? '';
        break;
    }

    return data;
  }

  Map<String, String> _collectRoleSpecificData() {
    switch (_selectedRole) {
      case 'sheikh':
        return {
          'Specialization': _specializationController.text,
          'Years of Experience': _yearsController.text,
          if (_socialController.text.isNotEmpty)
            'Social Media': _socialController.text,
        };
      case 'organization_mosque':
      case 'organization_quran':
      case 'organization':
        return {
          _selectedRole == 'organization_mosque'
                  ? 'Mosque Name'
                  : _selectedRole == 'organization_quran'
                      ? 'Center Name'
                      : 'Organization Name':
              _orgNameController.text,
          'City': _cityController.text,
          'Country': _selectedCountry?.name ?? '',
          if (_phoneController.text.isNotEmpty) 'Phone': _phoneController.text,
        };
      case 'community_organizer':
      case 'volunteer':
        return {
          'Community Name': _orgNameController.text,
          if (_focusController.text.isNotEmpty)
            'Focus Area': _focusController.text,
          'City': _cityController.text,
          'Country': _selectedCountry?.name ?? '',
        };
      default:
        return {};
    }
  }

  String _getRoleLabel(BuildContext context, String role) {
    final l10n = context.l10n;
    final labels = {
      'sheikh': l10n.registrationRoleSheikh,
      'organization_mosque': l10n.registrationOrgTypeMosque,
      'organization_quran': l10n.registrationOrgTypeQuranCenter,
      'organization': l10n.registrationRoleOrganization,
      'community_organizer': l10n.registrationRoleCommunityOrganizer,
      'student': l10n.registrationRoleStudent,
      'new_muslim': l10n.registrationRoleNewMuslim,
      'volunteer': l10n.registrationRoleCommunityOrganizer, // mapping volunteer to community organizer
      'member': l10n.registrationRoleStudent, // mapping member to student
    };
    return labels[role] ?? role;
  }

  String _getWelcomeMessage(BuildContext context, String backendRole) {
    final l10n = context.l10n;
    final messages = {
      'organization': l10n.registrationRoleDescOrganization,
      'sheikh': l10n.registrationRoleDescSheikh,
      'new_muslim': l10n.registrationWelcomeIslamSubtitle,
      'student': l10n.registrationRoleDescStudent,
      'community_organizer': l10n.registrationRoleDescCommunityOrganizer,
    };
    return messages[backendRole] ?? l10n.registrationWelcomeIslamSubtitle;
  }
}

// ─── Subtle Islamic Geometric Pattern ────────

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
        _drawOctagonStar(canvas, cx, cy, 14, paint);
      }
    }
  }

  void _drawOctagonStar(
      Canvas canvas, double cx, double cy, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 8;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
