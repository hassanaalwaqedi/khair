import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/widgets/password_strength_indicator.dart';
import '../../data/datasources/join_datasource.dart';
import '../bloc/join_bloc.dart';

/// Shows a bottom sheet modal for the 2-step join registration flow
void showJoinEventModal(BuildContext context, String eventId, String eventTitle) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider(
      create: (_) => JoinBloc(JoinDataSource(getIt<ApiClient>()))
        ..add(CheckAvailability(eventId)),
      child: _JoinEventSheet(eventId: eventId, eventTitle: eventTitle),
    ),
  );
}

class _JoinEventSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const _JoinEventSheet({required this.eventId, required this.eventTitle});

  @override
  State<_JoinEventSheet> createState() => _JoinEventSheetState();
}

class _JoinEventSheetState extends State<_JoinEventSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  bool _obscurePassword = true;
  String _selectedGender = '';
  int? _age;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JoinBloc, JoinState>(
      listener: (context, state) {
        if (state.status == JoinStatus.step2Complete) {
          Navigator.of(context).pop();
          _showVerificationPrompt(context);
        }
        if (state.status == JoinStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      builder: (context, state) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                _buildHeader(state),
                const SizedBox(height: 20),
                // Progress indicator
                _buildProgress(state),
                const SizedBox(height: 24),
                // Form content
                if (state.currentStep == 1) _buildStep1(context, state),
                if (state.currentStep == 2) _buildStep2(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(JoinState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_seat_rounded, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.eventTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create a simple account to reserve your seat.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (state.remaining != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: state.remaining! <= 5
                  ? AppTheme.warningColor.withValues(alpha: 0.1)
                  : AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${state.remaining} seats remaining',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: state.remaining! <= 5 ? AppTheme.warningColor : AppTheme.successColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgress(JoinState state) {
    return Row(
      children: [
        _progressDot(1, state.currentStep >= 1, state.currentStep == 1),
        Expanded(
          child: Container(
            height: 2,
            color: state.currentStep >= 2
                ? AppTheme.primaryColor
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        _progressDot(2, state.currentStep >= 2, state.currentStep == 2),
      ],
    );
  }

  Widget _progressDot(int step, bool active, bool current) {
    return Column(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.grey[500],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step == 1 ? 'Identity' : 'Security',
          style: TextStyle(
            fontSize: 10,
            fontWeight: current ? FontWeight.w600 : FontWeight.normal,
            color: current ? AppTheme.primaryColor : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // ── Step 1: Name + Email ──

  Widget _buildStep1(BuildContext context, JoinState state) {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your name & email',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              if (v.trim().length < 2) return 'At least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.status == JoinStatus.loading
                  ? null
                  : () {
                      if (_step1Key.currentState!.validate()) {
                        context.read<JoinBloc>().add(SubmitJoinStep1(
                              name: _nameController.text.trim(),
                              email: _emailController.text.trim(),
                              eventId: widget.eventId,
                            ));
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.status == JoinStatus.loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          _buildLoginLink(context),
        ],
      ),
    );
  }

  // ── Step 2: Password + Gender + Age ──

  Widget _buildStep2(BuildContext context, JoinState state) {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Secure your account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          PasswordStrengthIndicator(password: _passwordController.text),
          const SizedBox(height: 20),
          const Text('Gender', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              _genderChip('Male', Icons.male_rounded),
              const SizedBox(width: 12),
              _genderChip('Female', Icons.female_rounded),
            ],
          ),
          if (_selectedGender.isEmpty) ...[
            const SizedBox(height: 4),
            Text('Please select your gender',
                style: TextStyle(fontSize: 12, color: Colors.red[400])),
          ],
          const SizedBox(height: 16),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Age (optional)',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
            onChanged: (v) {
              if (v.isNotEmpty) _age = int.tryParse(v);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.status == JoinStatus.loading || _selectedGender.isEmpty
                  ? null
                  : () {
                      if (_step2Key.currentState!.validate()) {
                        context.read<JoinBloc>().add(SubmitJoinStep2(
                              password: _passwordController.text,
                              gender: _selectedGender.toLowerCase(),
                              age: _age,
                            ));
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.successColor,
              ),
              child: state.status == JoinStatus.loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Account & Reserve Seat',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderChip(String label, IconData icon) {
    final selected = _selectedGender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20,
                  color: selected ? AppTheme.primaryColor : Colors.grey[500]),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppTheme.primaryColor : Colors.grey[600],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: TextStyle(color: Colors.grey[600])),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            // Navigate to login — handled by the calling page
          },
          child: const Text(
            'Sign In',
            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showVerificationPrompt(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, size: 40, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text(
              "You're almost there!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please verify your email to confirm your seat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppTheme.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your seat is held for 10 minutes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it!'),
            ),
          ),
        ],
      ),
    );
  }
}
