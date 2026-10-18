// lib/presentation/screens/auth/pin_lock_screen.dart
// UI only — the "app locked" screen. Any 6 digits close it.
import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';

  void _unlock() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _onDigitPressed(String d) {
    if (_pin.length >= 6) return;
    setState(() => _pin += d);
    if (_pin.length == 6) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _unlock();
      });
    }
  }

  void _onBackspacePressed() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPAvatar(name: MockUser.fullName, size: 56),
              const SizedBox(height: 18),
              Text(
                'Welcome back, ${MockUser.firstName}.',
                style: DP.display,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 6-digit PIN to unlock.',
                style: DP.body.copyWith(color: DP.muted),
              ),
              const SizedBox(height: 20),
              DPPinDots(length: 6, filled: _pin.length),
              const SizedBox(height: 20),
              DPKeypad(
                onDigit: _onDigitPressed,
                onBackspace: _onBackspacePressed,
                leftAction: IconButton(
                  tooltip: 'Use biometrics',
                  onPressed: _unlock,
                  icon: const Icon(
                    DPIcons.fingerprint,
                    color: DP.green,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: DPTextLink(
                  label: 'Log out',
                  color: DP.muted,
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
