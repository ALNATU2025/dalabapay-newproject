// lib/presentation/screens/auth/pin_lock_screen.dart
// The "app locked" screen shown when returning to the app.
import 'package:flutter/material.dart';

import '../../../core/api/session.dart';
import '../../../ui/ui.dart';
import 'pin_unlock.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with PinUnlock<PinLockScreen> {
  @override
  void onUnlocked() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DPAvatar(name: user?.fullName ?? '', size: 56),
              const SizedBox(height: 18),
              Text(
                'Welcome back, ${user?.firstName ?? 'there'}.',
                style: DP.display,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 6-digit PIN to unlock.',
                style: DP.body.copyWith(color: DP.muted),
              ),
              const SizedBox(height: 20),
              DPPinDots(length: 6, filled: pin.length, error: error.isNotEmpty),
              if (error.isNotEmpty)
                DPHelper(error, color: DP.red, icon: DPIcons.alert),
              if (checking) const LinearProgressIndicator(color: DP.green),
              const SizedBox(height: 20),
              DPKeypad(onDigit: addDigit, onBackspace: removeDigit),
              const SizedBox(height: 12),
              Center(
                child: DPTextLink(
                  label: 'Log out',
                  color: DP.muted,
                  onTap: logOut,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
