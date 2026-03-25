import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/app_design_system.dart';
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
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
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

  // Verification controllers
  final _codeController = TextEditingController();

  /// Dynamic step labels based on selected role
  List<String> get _stepLabels {
    if (_selectedRole != null && isAuthorityRole(_selectedRole!)) {
      return ['Role', 'Account', 'Goals', 'Upload', 'Review'];
    }
    return ['Role', 'Account', 'Goals', 'Review'];
  }

  int get _reviewStepIndex => _stepLabels.length - 1;
  int get _verificationStepIndex => _stepLabels.length;
  int get _doneStepIndex => _stepLabels.length + 1;
  bool get _hasUploadStep =>
      _selectedRole != null && isAuthorityRole(_selectedRole!);

  @override
  void initState() {
    super.initState();
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
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegistrationBloc, RegistrationState>(
      listener: _blocListener,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              if (_currentStep <= _reviewStepIndex) _buildProgressDots(),
              Expanded(
                child: _currentStep <= _reviewStepIndex
                    ? _buildStepContent()
                    : _buildVerificationOrDone(),
              ),
              if (_currentStep <= _reviewStepIndex) _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 16),
            ),
            onPressed: () {
              if (_currentStep > 0 && _currentStep <= _reviewStepIndex) {
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
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Dots ────────────────────────────

  Widget _buildProgressDots() {
    final displayStep = _currentStep.clamp(0, _stepLabels.length - 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${context.l10n.registrationProgressRole} ${displayStep + 1} / ${_stepLabels.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _stepLabels[displayStep],
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 12,
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
                  margin: EdgeInsetsDirectional.only(
                      end: i < _stepLabels.length - 1 ? 4 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isCompleted
                          ? AppColors.primary
                          : isCurrent
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
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

  // ─── Step Content (in a centered card) ────────

  Widget _buildStepContent() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ),
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
    if (_hasUploadStep && _currentStep == 3) {
      return MediaUploadStep(
        selectedImageBytes: _selectedImageBytes,
        selectedImageName: _selectedImageName,
        uploadedImageUrl: _uploadedImageUrl,
        isUploading: _isUploadingImage,
        onImageSelected: (bytes, name) {
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = name;
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Row(
            children: [
              if (_currentStep > 0 && _currentStep < _reviewStepIndex) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _goToStep(_currentStep - 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(context.l10n.cancel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_currentStep < _reviewStepIndex)
                Expanded(
                  child: ElevatedButton(
                    onPressed: canContinue ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.06),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.25),
                      padding: const EdgeInsets.symmetric(vertical: 15),
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
        ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_unread_rounded,
                      color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.registrationVerifyEmailTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.registrationCodeExpiresInTenMinutes,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // OTP Input
                TextFormField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 28,
                      letterSpacing: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        state.status == RegistrationStatus.loading
                            ? null
                            : () {
                                final code = _codeController.text.trim();
                                if (code.length != 6) return;
                                final email =
                                    _emailController.text.trim();
                                context.read<RegistrationBloc>().add(
                                    SubmitVerificationCode(
                                        email: email, code: code));
                              },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: state.status == RegistrationStatus.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            context.l10n.registrationVerifyEmailButton,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
                if (state.resendSuccess)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.l10n.registrationVerificationCodeResent,
                      style: const TextStyle(
                          color: KhairColors.success, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    context.read<RegistrationBloc>().add(
                        ResendVerificationCode(
                            email: _emailController.text.trim()));
                  },
                  child: Text(
                    context.l10n.registrationResendCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneState() {
    final backendRole = mapToBackendRole(_selectedRole ?? 'student');
    final isAuthority = isAuthorityRole(_selectedRole ?? 'student');

    // Role-based onboarding hints
    String onboardingHint;
    String ctaLabel;
    String route;

    if (backendRole == 'sheikh') {
      onboardingHint =
          'Complete your profile to start receiving students and lesson requests.';
      ctaLabel = 'Go to Dashboard';
      route = '/organizer';
    } else if (isAuthority) {
      onboardingHint = 'Create your first event and grow your community!';
      ctaLabel = 'Go to Dashboard';
      route = '/organizer';
    } else {
      onboardingHint =
          'Discover events, connect with scholars, and grow your faith journey.';
      ctaLabel = context.l10n.browseEvents;
      route = '/';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: KhairColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: KhairColors.success, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.registrationCompleteTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _getWelcomeMessage(context, backendRole),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Onboarding hint chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: AppColors.primaryLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          onboardingHint,
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go(route),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Logic ───────────────────────────────────

  bool _canContinue() {
    switch (_currentStep) {
      case 0:
        return _selectedRole != null;
      case 1:
        return true;
      case 2:
        return true;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }

    if (_hasUploadStep &&
        _currentStep == 3 &&
        _selectedImageBytes != null &&
        _uploadedImageUrl == null) {
      setState(() => _isUploadingImage = true);
      context.read<RegistrationBloc>().add(UploadImage(
        imageBytes: _selectedImageBytes!,
        filename: _selectedImageName ?? 'image.jpg',
      ));
      return;
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

    if (!isAuthorityRole(_selectedRole!)) {
      bloc.add(SubmitSimpleRegistration(
        role: backendRole,
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ));
      return;
    }

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

    if (state.imageUrl != null && _isUploadingImage) {
      setState(() {
        _isUploadingImage = false;
        _uploadedImageUrl = state.imageUrl;
      });
      _goToStep(_currentStep + 1);
      return;
    }

    if (state.status == RegistrationStatus.success &&
        state.currentStep == 2) {
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

    if (state.status == RegistrationStatus.success &&
        state.currentStep == 3) {
      final step3Data = _collectStep3Data();
      if (_uploadedImageUrl != null) {
        step3Data['logo_url'] = _uploadedImageUrl;
      }
      context.read<RegistrationBloc>().add(SubmitStep3(step3Data));
      return;
    }

    if (state.status == RegistrationStatus.success &&
        state.currentStep == 4) {
      context.read<RegistrationBloc>().add(const SubmitStep4());
      return;
    }

    if (state.status == RegistrationStatus.pendingVerification) {
      setState(() {
        _isSubmitting = false;
        _currentStep = _verificationStepIndex;
      });
      return;
    }

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
      'volunteer': l10n.registrationRoleCommunityOrganizer,
      'member': l10n.registrationRoleStudent,
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
