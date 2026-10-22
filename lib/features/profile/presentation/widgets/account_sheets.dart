import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/auth/presentation/widgets/auth_form_field.dart';
import 'package:provider/provider.dart';

Future<void> showEditProfileSheet(BuildContext context) =>
    _showSheet(context, const _EditProfileForm());

/// Resolves to true when the password was changed.
Future<bool?> showChangePasswordSheet(BuildContext context) =>
    _showSheet<bool>(context, const _ChangePasswordForm());

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        20 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm();

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _session = context.read<SessionController>();
  late final _name = TextEditingController(text: _session.user!.name);
  late String _accountType = _session.user!.accountType;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _session.updateProfile(name: _name.text, accountType: _accountType);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Older accounts may hold a type that is no longer offered.
    final types = {...AppConstants.accountTypes, _accountType}.toList();
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit profile', style: AppTextStyles.headline),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Full name',
            controller: _name,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) => Validators.required(v, 'Enter your name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _accountType,
            isExpanded: true,
            decoration: CustomTextField.decoration(
              context,
              label: 'Account type',
              prefixIcon: Icons.badge_outlined,
            ),
            items: [
              for (final t in types) DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => _accountType = v!),
          ),
          const SizedBox(height: 20),
          CustomButton(label: 'Save', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<SessionController>()
          .changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change password', style: AppTextStyles.headline),
          const SizedBox(height: 16),
          AuthFormField(
            label: 'Current password',
            icon: Icons.lock_outline_rounded,
            controller: _current,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.required(v, 'Enter your password'),
          ),
          const SizedBox(height: 12),
          AuthFormField(
            label: 'New password',
            icon: Icons.lock_reset_rounded,
            controller: _next,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: Validators.newPassword,
          ),
          const SizedBox(height: 12),
          AuthFormField(
            label: 'Confirm new password',
            icon: Icons.lock_reset_rounded,
            controller: _confirm,
            isPassword: true,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                v != _next.text ? 'Passwords do not match' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTextStyles.body.copyWith(color: cs.error),
            ),
          ],
          const SizedBox(height: 20),
          CustomButton(
            label: 'Update password',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
