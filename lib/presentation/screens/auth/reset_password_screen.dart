// lib/presentation/screens/auth/reset_password_screen.dart
// Choose a new password after the OTP step (POST /api/auth/password/reset).
// The reset token arrives as the route argument.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../ui/ui.dart';
import 'password_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  bool get _strong {
    final p = _newController.text;
    return p.length >= 8 &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[a-z]')) &&
        p.contains(RegExp(r'[0-9]'));
  }

  bool get _matches =>
      _confirmController.text.isNotEmpty &&
      _confirmController.text == _newController.text;

  @override
  void initState() {
    super.initState();
    _newController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final token = ModalRoute.of(context)?.settings.arguments?.toString() ?? '';
    if (token.isEmpty) {
      dpSnack(context, 'Please request a new reset code.', error: true);
      Navigator.pushReplacementNamed(context, '/forgot-password');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await api.post('/api/auth/password/reset', {
        'resetToken': token,
        'password': _newController.text,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    showDoneSheet(
      context,
      title: 'Password Reset Successfully!',
      message:
          'Your password has been successfully changed.\nYou can now log in with your new password.',
      buttonLabel: 'Login now',
      onPressed: () => Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (_) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.surface,
      body: DPWaveBackground(child: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Create new password'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPHeadline(
                      'Create New Password',
                      subtitle: 'Enter your new password below.',
                    ),
                    const DPLabel('New Password'),
                    PasswordField(
                      controller: _newController,
                      hint: 'Enter new password',
                    ),
                    const SizedBox(height: 12),
                    PasswordRules(password: _newController.text),
                    const SizedBox(height: 16),
                    const DPLabel('Confirm Password'),
                    PasswordField(
                      controller: _confirmController,
                      hint: 'Confirm new password',
                      action: TextInputAction.done,
                    ),
                    if (_confirmController.text.isNotEmpty && !_matches)
                      const DPHelper(
                        'Passwords do not match',
                        color: DP.red,
                        icon: DPIcons.alert,
                      ),
                    const SizedBox(height: 28),
                    DPButton(
                      label: 'Reset password',
                      loading: _isLoading,
                      onPressed: _strong && _matches && !_isLoading ? _submit : null,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Remember your password? ',
                            style: DP.caption,
                          ),
                          DPTextLink(
                            label: 'Back to Login',
                            fontSize: 13,
                            onTap: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (_) => false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
