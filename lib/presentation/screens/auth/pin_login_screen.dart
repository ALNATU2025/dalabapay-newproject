// lib/presentation/screens/auth/pin_login_screen.dart
// Opening the app with a saved login: the PIN unlocks it.
import 'package:flutter/material.dart';

import '../../../core/api/session.dart';
import '../../../ui/ui.dart';
import 'pin_unlock.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with PinUnlock<PinLoginScreen> {
  @override
  void onUnlocked() =>
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: DPWordmark(height: 32),
              ),
              const SizedBox(height: 28),
              Text('Enter your PIN.', style: DP.display),
              const SizedBox(height: 8),
              Text(
                'Use your 6-digit PIN to unlock Dalabapay.',
                style: DP.body.copyWith(color: DP.muted),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    DPAvatar(name: user?.fullName ?? '', size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? '', style: DP.bodyStrong),
                          Text(user?.email ?? '', style: DP.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: DPPinDots(
                    length: 6, filled: pin.length, error: error.isNotEmpty),
              ),
              if (error.isNotEmpty)
                DPHelper(error, color: DP.red, icon: DPIcons.alert),
              if (checking) const LinearProgressIndicator(color: DP.green),
              const SizedBox(height: 16),
              DPKeypad(onDigit: addDigit, onBackspace: removeDigit),
              const SizedBox(height: 8),
              Center(
                child: DPTextLink(
                  label: 'Log in with email or phone instead',
                  color: DP.muted,
                  onTap: logOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
