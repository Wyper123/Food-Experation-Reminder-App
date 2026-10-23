import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/auth/presentation/screens/register_screen.dart';
import 'package:food_expiration_reminder/features/auth/presentation/widgets/auth_form_field.dart';
import 'package:food_expiration_reminder/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:food_expiration_reminder/features/auth/presentation/widgets/reset_password_sheet.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // StartupGate swaps in the app once the session is set.
      await context.read<SessionController>().signIn(
            _email.text,
            _password.text,
          );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  Future<void> _continueWithGoogle() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      // StartupGate swaps in the app once signed in; backing out of the
      // account picker simply leaves the login screen.
      await context.read<SessionController>().signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.brandGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Welcome back', style: AppTextStyles.display),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to see what needs eating first.',
                      style: AppTextStyles.body.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AuthFormField(
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    AuthFormField(
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      controller: _password,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          Validators.required(v, 'Enter your password'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showResetPasswordSheet(
                          context,
                          initialEmail: _email.text,
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 8),
                    CustomButton(
                      label: 'Log in',
                      isLoading: _submitting,
                      onPressed: _googleBusy ? null : _submit,
                    ),
                    const SizedBox(height: 16),
                    const OrDivider(),
                    const SizedBox(height: 16),
                    GoogleSignInButton(
                      isLoading: _googleBusy,
                      onPressed: _submitting ? null : _continueWithGoogle,
                    ),
                    const SizedBox(height: 20),
                    // Wraps instead of overflowing with large font sizes.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New here?',
                          style: AppTextStyles.body.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
