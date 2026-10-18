// lib/presentation/screens/auth/password_widgets.dart
// Shared pieces for the password screens (UI only).
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Password field with a show / hide toggle.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputAction action;
  const PasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.action = TextInputAction.next,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return DPField(
      controller: widget.controller,
      hint: widget.hint,
      obscureText: _obscure,
      textInputAction: widget.action,
      prefix: const Icon(DPIcons.lock, size: 20),
      suffix: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(_obscure ? DPIcons.eyeOff : DPIcons.eye, size: 20),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

/// Live checklist of password rules.
class PasswordRules extends StatelessWidget {
  final String password;
  final bool includeSpecial;
  const PasswordRules({
    super.key,
    required this.password,
    this.includeSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      'At least 8 characters': password.length >= 8,
      'One uppercase letter': password.contains(RegExp(r'[A-Z]')),
      'One lowercase letter': password.contains(RegExp(r'[a-z]')),
      'One number': password.contains(RegExp(r'[0-9]')),
      if (includeSpecial)
        'One special character':
            password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]')),
    };
    return DPCard(
      color: DP.bg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DP.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rules.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    r.value
                        ? DPIcons.checkCircle
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: r.value ? DP.green : DP.faint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r.key,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: r.value ? DP.green : DP.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet with a big tick, title, message and one button.
Future<void> showDoneSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String buttonLabel,
  required VoidCallback onPressed,
}) {
  return showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: DP.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DPSheetHandle(),
            const SizedBox(height: 16),
            const DPStatusHero(size: 88),
            const SizedBox(height: 18),
            Text(title, style: DP.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: DP.body.copyWith(color: DP.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DPButton(
              label: buttonLabel,
              onPressed: () {
                Navigator.pop(ctx);
                onPressed();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
