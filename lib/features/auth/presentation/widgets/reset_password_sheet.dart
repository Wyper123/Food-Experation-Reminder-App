import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/auth/presentation/widgets/auth_form_field.dart';
import 'package:provider/provider.dart';

/// "Forgot password?": emails a reset link (sent by Firebase).
Future<void> showResetPasswordSheet(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        20 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: _ResetPasswordForm(initialEmail: initialEmail),
      ),
    ),
  );
}

class _ResetPasswordForm extends StatefulWidget {
  const _ResetPasswordForm({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  bool _sending = false;
  String? _error;

  /// The address the link went to; non-null once sent.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().sendPasswordReset(_email.text);
      if (mounted) setState(() => _sentTo = _email.text.trim());
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = AppTextStyles.body.copyWith(color: cs.onSurfaceVariant);

    final sentTo = _sentTo;
    if (sentTo != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 40, color: cs.primary),
          const SizedBox(height: 12),
          Text('Check your email', style: AppTextStyles.headline),
          const SizedBox(height: 8),
          // Same wording whether or not the account exists, on purpose.
          Text(
            'If an account exists for $sentTo, we sent it a link to reset '
            'the password. Open it, choose a new password, then log in. '
            "Can't find it? Check Spam or Promotions.",
            style: muted,
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Back to login',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reset password', style: AppTextStyles.headline),
          const SizedBox(height: 8),
          Text(
            "Enter your account's email and we'll send you a link to set a "
            'new password.',
            style: muted,
          ),
          const SizedBox(height: 16),
          AuthFormField(
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.body.copyWith(color: cs.error)),
          ],
          const SizedBox(height: 20),
          CustomButton(
            label: 'Send reset link',
            icon: Icons.send_outlined,
            isLoading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
