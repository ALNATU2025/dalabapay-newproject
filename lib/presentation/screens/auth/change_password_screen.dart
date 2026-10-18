// lib/presentation/screens/auth/change_password_screen.dart
// UI only — change password from Profile → Security.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'password_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
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
    for (final c in [_currentController, _newController, _confirmController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);
    showDoneSheet(
      context,
      title: 'Password Changed!',
      message: 'Use your new password the next time you log in.',
      buttonLabel: 'Done',
      onPressed: () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Change Password'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPHeadline(
                      'Change Password',
                      subtitle:
                          'Enter your current password and choose a new one.',
                    ),
                    const DPLabel('Current Password'),
                    PasswordField(
                      controller: _currentController,
                      hint: 'Enter current password',
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('New Password'),
                    PasswordField(
                      controller: _newController,
                      hint: 'Enter new password',
                    ),
                    const SizedBox(height: 12),
                    PasswordRules(
                      password: _newController.text,
                      includeSpecial: true,
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('Confirm New Password'),
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
                      label: 'Change password',
                      loading: _isLoading,
                      onPressed: _currentController.text.isNotEmpty &&
                              _strong &&
                              _matches
                          ? _submit
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
