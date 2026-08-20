import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/locale_bloc.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../../../tokens/tokens.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/registration_bloc.dart';
import '../services/google_auth_service.dart';
import '../widgets/auth_form_controls.dart';
import '../widgets/auth_responsive_shell.dart';
import '../widgets/auth_visual_panel.dart';

/// A deliberately short attendee signup. Becoming an organizer is a separate
/// action after a user account exists and is never selected here.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _googleAuth = GoogleAuthService();
  bool _obscure = true;
  bool _googleLoading = false;
  bool _emailTouched = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RegistrationBloc>(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == AuthStatus.authenticated) {
              _continueAfterAuth(context);
            } else if (state.status == AuthStatus.failure) {
              _showMessage(
                  'Google sign-up could not be completed. Please try email instead.');
              setState(() => _googleLoading = false);
            }
          },
          child: BlocConsumer<RegistrationBloc, RegistrationState>(
            listener: (context, state) {
              if (state.status == RegistrationStatus.pendingVerification) {
                final next =
                    GoRouterState.of(context).uri.queryParameters['next'];
                context.go(
                    '/register/verify?email=${Uri.encodeComponent(_email.text.trim())}${next == null ? '' : '&next=${Uri.encodeComponent(next)}'}');
              } else if (state.status == RegistrationStatus.failure) {
                _showMessage(_friendlyRegistrationError(state.errorMessage));
              }
            },
            builder: (context, registration) => AuthResponsiveShell(
              topBar: _RegisterTopBar(onBack: () => context.go('/')),
              visualPanel: AuthVisualPanel(
                heading: 'Find your next gathering',
                description:
                    'Join Khair to discover meaningful events and communities near you.',
              ),
              form: _SignupForm(
                formKey: _formKey,
                name: _name,
                email: _email,
                password: _password,
                obscure: _obscure,
                emailTouched: _emailTouched,
                loading: registration.status == RegistrationStatus.loading,
                googleLoading: _googleLoading,
                onEmailChanged: (_) => setState(() => _emailTouched = true),
                onPasswordChanged: (_) => setState(() {}),
                onTogglePassword: () => setState(() => _obscure = !_obscure),
                onGoogle: _googleLoading ? null : _googleSignUp,
                onSubmit: () => _submit(context),
                onLogin: () => _goToLogin(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final language = context.read<LocaleBloc>().state.locale.languageCode;
    context.read<RegistrationBloc>().add(SubmitSimpleRegistration(
          displayName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          preferredLanguage: language,
        ));
  }

  Future<void> _googleSignUp() async {
    setState(() => _googleLoading = true);
    try {
      final token = await _googleAuth.obtainIdToken();
      if (!mounted) return;
      if (token == null) {
        setState(() => _googleLoading = false);
        return;
      }
      context.read<AuthBloc>().add(GoogleLoginRequested(
            idToken: token,
            preferredLanguage:
                context.read<LocaleBloc>().state.locale.languageCode,
          ));
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
      setState(() => _googleLoading = false);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Google sign-up was cancelled or could not be completed.');
      setState(() => _googleLoading = false);
    }
  }

  void _continueAfterAuth(BuildContext context) {
    final next =
        _safeNext(GoRouterState.of(context).uri.queryParameters['next']);
    context.go(next == '/create-event' ? '/organizer/apply' : (next ?? '/'));
  }

  void _goToLogin(BuildContext context) {
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    context.go(
        next == null ? '/login' : '/login?next=${Uri.encodeComponent(next)}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RegisterTopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _RegisterTopBar({required this.onBack});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Row(children: [
          IconButton(
              onPressed: onBack, tooltip: context.l10n.createEventBack, icon: BackButtonIcon()),
          Spacer(),
          LanguageSwitcher(showLabel: constraints.maxWidth >= 480),
        ]),
      );
}

class _SignupForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool emailTouched;
  final bool loading;
  final bool googleLoading;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback? onGoogle;
  final VoidCallback onSubmit;
  final VoidCallback onLogin;

  const _SignupForm({
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.obscure,
    required this.emailTouched,
    required this.loading,
    required this.googleLoading,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onGoogle,
    required this.onSubmit,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = AuthMetrics(MediaQuery.sizeOf(context).width);
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)), child: child),
      ),
      child: AutofillGroup(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (metrics.isMobile) _SignupBrand(),
          if (metrics.isMobile) SizedBox(height: 26),
          Text(context.l10n.createYourKhairAccount,
              textAlign: metrics.isMobile ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: metrics.titleSize,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -.7)),
          SizedBox(height: 10),
          Text(
              'Discover events. Join communities. Be part of something meaningful.',
              textAlign: metrics.isMobile ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: metrics.bodySize,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
          SizedBox(height: metrics.sectionGap),
          SizedBox(
            height: 54,
            child: SocialLoginButton(
              label: googleLoading
                  ? 'Connecting to Google…'
                  : 'Continue with Google',
              onPressed: onGoogle ?? () {},
            ),
          ),
          SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant)),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(context.l10n.orContinueWithEmail)),
            Expanded(
                child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant)),
          ]),
          SizedBox(height: 24),
          Form(
            key: formKey,
            child: Column(children: [
              KhairAuthField(
                  controller: name,
                  label: context.l10n.registrationReviewName,
                  hint: 'Your name',
                  prefixIcon: Icons.person_outline_rounded,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null),
              SizedBox(height: 16),
              KhairAuthField(
                  controller: email,
                  label: context.l10n.email,
                  hint: 'you@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username
                  ],
                  onChanged: onEmailChanged,
                  onFieldSubmitted: (_) {},
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your email address.';
                    }
                    if (!value.contains('@')) {
                      return emailTouched
                          ? 'Enter a valid email address.'
                          : null;
                    }
                    return null;
                  }),
              SizedBox(height: 16),
              KhairAuthField(
                  controller: password,
                  label: context.l10n.password,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: onPasswordChanged,
                  onFieldSubmitted: (_) => onSubmit(),
                  suffixIcon: IconButton(
                      onPressed: onTogglePassword,
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      icon: Icon(obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined)),
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters.'
                      : null),
            ]),
          ),
          SizedBox(height: 10),
          _PasswordHint(password: password.text),
          SizedBox(height: 18),
          SizedBox(
              height: 54,
              child: FilledButton(
                  onPressed: loading ? null : onSubmit,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: loading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text(context.l10n.creatingYourAccount)
                            ])
                      : Text(context.l10n.createAccount1))),
          SizedBox(height: 22),
          Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.l10n.alreadyHaveAnAccount),
                TextButton(onPressed: onLogin, child: Text(context.l10n.signIn1))
              ]),
        ]),
      ),
    );
  }
}

class _SignupBrand extends StatelessWidget {
  const _SignupBrand();
  @override
  Widget build(BuildContext context) => Column(children: [
        KhairBrandMark(size: 64, decorative: true),
        SizedBox(height: 10),
        Text(context.l10n.appTitle,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ]);
}

class _PasswordHint extends StatelessWidget {
  final String password;
  const _PasswordHint({required this.password});
  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    return Row(children: [
      Icon(hasLength ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: hasLength ? Colors.green : AppColors.textTertiary, size: 16),
      SizedBox(width: 7),
      Text(context.l10n.use8OrMoreCharacters,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: hasLength ? Colors.green : AppColors.textSecondary))
    ]);
  }
}

String _friendlyRegistrationError(String? error) {
  final message = error?.toLowerCase() ?? '';
  if (message.contains('already')) {
    return 'An account already exists for this email. Try signing in instead.';
  }
  if (message.contains('weak') || message.contains('password')) {
    return 'Choose a stronger password with at least 8 characters.';
  }
  if (message.contains('network') || message.contains('connection')) {
    return 'We could not create your account. Check your connection and try again.';
  }
  return 'We could not create your account. Please try again.';
}

String? _safeNext(String? next) =>
    next != null && next.startsWith('/') && !next.startsWith('//')
        ? next
        : null;
