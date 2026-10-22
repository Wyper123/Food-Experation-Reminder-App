import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/auth/presentation/widgets/auth_form_field.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _invite = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            inviteCode: _invite.text,
          );
      // StartupGate (the first route) now shows the app.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create account', style: AppTextStyles.display),
                    const SizedBox(height: 8),
                    Text(
                      'Start tracking your food in under a minute.',
                      style: AppTextStyles.body.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthFormField(
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          Validators.required(v, 'Enter your name'),
                    ),
                    const SizedBox(height: 16),
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
                      textInputAction: TextInputAction.next,
                      validator: Validators.newPassword,
                    ),
                    const SizedBox(height: 16),
                    AuthFormField(
                      label: 'Confirm password',
                      icon: Icons.lock_reset_rounded,
                      controller: _confirm,
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          v != _password.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthFormField(
                      label: 'Household invite code (optional)',
                      hint: 'Leave blank to start your own',
                      icon: Icons.group_add_outlined,
                      controller: _invite,
                      textInputAction: TextInputAction.done,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 28),
                    CustomButton(
                      label: 'Create account',
                      isLoading: _submitting,
                      onPressed: _submit,
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
