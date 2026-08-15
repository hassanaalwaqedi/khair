import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/registration_datasource.dart';

/// Attendee email OTP step. This replaces the legacy organizer-document page
/// that was previously used after every registration.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});
  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _code = TextEditingController();
  final _source = getIt<RegistrationRemoteDataSource>();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = GoRouterState.of(context).uri.queryParameters['email'] ?? '';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, 32 + MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                            onPressed: () => context.go('/register'),
                            icon: const BackButtonIcon())),
                    const SizedBox(height: 32),
                    const Icon(Icons.mark_email_read_outlined,
                        color: Color(0xFFF43F75), size: 46),
                    const SizedBox(height: 18),
                    Text('Check your email',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text('Enter the six-digit code we sent to $email.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 32),
                    TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'Verification code',
                            hintText: '000000',
                            counterText: ''),
                        onSubmitted: (_) => _verify(email)),
                    const SizedBox(height: 22),
                    SizedBox(
                        height: 54,
                        child: FilledButton(
                            onPressed: _loading ? null : () => _verify(email),
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Verify email'))),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: _loading ? null : () => _resend(email),
                        child: const Text('Resend code')),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verify(String email) async {
    if (email.isEmpty || _code.text.trim().length != 6) {
      _message('Enter the six-digit code from your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _source.verifyCode(email: email, code: _code.text.trim());
      if (!mounted) return;
      _message('Email verified. Sign in to continue.');
      final next = GoRouterState.of(context).uri.queryParameters['next'];
      context.go(
          next == null ? '/login' : '/login?next=${Uri.encodeComponent(next)}');
    } catch (_) {
      if (mounted) {
        _message('That code is invalid or has expired. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend(String email) async {
    try {
      await _source.resendCode(email: email);
      if (mounted) {
        _message('If the address is registered, a new code is on its way.');
      }
    } catch (_) {
      if (mounted) _message('We could not resend the code. Please try again.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
