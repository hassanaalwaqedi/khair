import 'package:khair_app/core/locale/l10n_extension.dart';
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
              constraints: BoxConstraints(maxWidth: 460),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                            onPressed: () => context.go('/register'),
                            icon: BackButtonIcon())),
                    SizedBox(height: 32),
                    Icon(Icons.mark_email_read_outlined,
                        color: Color(0xFFF43F75), size: 46),
                    SizedBox(height: 18),
                    Text(context.l10n.checkYourEmail,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    SizedBox(height: 10),
                    Text(context.l10n.verificationCodeSentTo(email),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge),
                    SizedBox(height: 32),
                    TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        autofocus: true,
                        decoration: InputDecoration(
                            labelText: context.l10n.verificationCode,
                            hintText: '000000',
                            counterText: ''),
                        onSubmitted: (_) => _verify(email)),
                    SizedBox(height: 22),
                    SizedBox(
                        height: 54,
                        child: FilledButton(
                            onPressed: _loading ? null : () => _verify(email),
                            child: _loading
                                ? CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(context.l10n.verifyEmail))),
                    SizedBox(height: 12),
                    TextButton(
                        onPressed: _loading ? null : () => _resend(email),
                        child: Text(context.l10n.resendCode)),
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
