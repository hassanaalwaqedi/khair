import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/locale/locale_bloc.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../../../tokens/tokens.dart';
import '../bloc/auth_bloc.dart';
import '../services/google_auth_service.dart';
import '../widgets/auth_form_controls.dart';
import '../widgets/auth_responsive_shell.dart';
import '../widgets/auth_visual_panel.dart';

/// Event-focused sign in that keeps the existing JWT and deep-link flow while
/// adapting its composition for phones, tablets, and desktop browsers.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleAuth = GoogleAuthService();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            final next = GoRouterState.of(context).uri.queryParameters['next'];
            context.go(_safeNext(next) ?? '/');
          } else if (state.status == AuthStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyError(state.errorMessage))),
            );
          }
        },
        builder: (context, state) => AuthResponsiveShell(
          topBar: _LoginTopBar(onBack: () => context.go('/')),
          visualPanel: const AuthVisualPanel(),
          form: _LoginForm(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            loading: state.status == AuthStatus.loading,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onSubmit: () => _login(context),
            onForgotPassword: () => _showUnavailable(
                'Password reset is not available yet. Please contact support if you need help.'),
            onGoogle: _googleLogin,
            onRegister: () => _goToRegister(context),
          ),
        ),
      ),
    );
  }

  void _login(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    context.read<AuthBloc>().add(LoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
  }

  void _goToRegister(BuildContext context) {
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    context.go(next == null
        ? '/register'
        : '/register?next=${Uri.encodeComponent(next)}');
  }

  Future<void> _googleLogin() async {
    try {
      final idToken = await _googleAuth.obtainIdToken();
      if (!mounted || idToken == null) return;
      context.read<AuthBloc>().add(GoogleLoginRequested(
            idToken: idToken,
            preferredLanguage:
                context.read<LocaleBloc>().state.locale.languageCode,
          ));
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      _showUnavailable(error.message);
    } catch (_) {
      if (!mounted) return;
      _showUnavailable(
          'Google sign-in was cancelled or could not be completed.');
    }
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LoginTopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _LoginTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Semantics(
              button: true,
              label: 'Back to event discovery',
              child: IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const BackButtonIcon(),
              ),
            ),
            const Spacer(),
            LanguageSwitcher(showLabel: constraints.maxWidth >= 480),
          ],
        ),
      );
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogle;
  final VoidCallback onRegister;

  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onGoogle,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = AuthMetrics(MediaQuery.sizeOf(context).width);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    final cameFromCreate = _safeNext(next) == '/create-event';
    final colorScheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)), child: child),
      ),
      child: FocusTraversalGroup(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (metrics.isMobile) const _MobileBrand(),
              if (metrics.isMobile) const SizedBox(height: 28),
              Text(
                context.l10n.welcomeBack,
                textAlign:
                    metrics.isMobile ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: metrics.titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.signInToContinue,
                textAlign:
                    metrics.isMobile ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: metrics.bodySize,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
              ),
              if (cameFromCreate) ...[
                const SizedBox(height: 18),
                const _AuthContextNotice(),
              ],
              SizedBox(height: metrics.sectionGap),
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KhairAuthField(
                      controller: emailController,
                      label: context.l10n.email,
                      hint: 'you@example.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.enterEmail;
                        }
                        if (!value.contains('@')) {
                          return context.l10n.validEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    KhairAuthField(
                      controller: passwordController,
                      label: context.l10n.password,
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => onSubmit(),
                      suffixIcon: IconButton(
                        tooltip:
                            obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: onTogglePassword,
                        icon: Icon(obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? context.l10n.enterPassword
                          : null,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: loading ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: loading
                        ? const Row(
                            key: ValueKey('loading'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text('Signing in…'),
                            ],
                          )
                        : Text(context.l10n.signIn,
                            key: const ValueKey('sign-in')),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(child: Divider(color: colorScheme.outlineVariant)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or continue with')),
                Expanded(child: Divider(color: colorScheme.outlineVariant)),
              ]),
              const SizedBox(height: 22),
              SocialLoginButton(
                  label: 'Continue with Google', onPressed: onGoogle),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(context.l10n.noAccount),
                  TextButton(
                      onPressed: onRegister, child: const Text('Create one')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBrand extends StatelessWidget {
  const _MobileBrand();
  @override
  Widget build(BuildContext context) => Column(children: [
        const KhairBrandMark(size: 72, decorative: true),
        const SizedBox(height: 12),
        Text('Khair',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ]);
}

class _AuthContextNotice extends StatelessWidget {
  const _AuthContextNotice();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: .2)),
        ),
        child: const Row(children: [
          Icon(Icons.event_available_outlined,
              color: AppColors.primary, size: 19),
          SizedBox(width: 9),
          Expanded(child: Text('Sign in to continue creating your event.')),
        ]),
      );
}

String _friendlyError(String? message) {
  final lower = message?.toLowerCase() ?? '';
  if (lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('connection')) {
    return 'We could not sign you in. Check your connection and try again.';
  }
  return 'Email or password is incorrect. Please try again.';
}

String? _safeNext(String? next) =>
    next != null && next.startsWith('/') && !next.startsWith('//')
        ? next
        : null;
