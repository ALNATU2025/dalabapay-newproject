// lib/presentation/screens/auth/pin_login_screen.dart
// UI only — any 6 digits unlock and open the dashboard.
import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';

  void _onPinDigitPressed(String digit) {
    if (_pin.length >= 6) return;
    setState(() => _pin += digit);
    if (_pin.length == 6) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: DPWordmark(height: 32),
              ),
              const SizedBox(height: 28),
              const Text('Enter your PIN.', style: DP.display),
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
                    const DPAvatar(name: MockUser.fullName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(MockUser.fullName, style: DP.bodyStrong),
                          Text(MockUser.email, style: DP.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: DPPinDots(length: 6, filled: _pin.length),
              ),
              const SizedBox(height: 16),
              DPKeypad(
                onDigit: _onPinDigitPressed,
                onBackspace: _onBackspacePressed,
                leftAction: IconButton(
                  tooltip: 'Use biometrics',
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/dashboard'),
                  icon: const Icon(
                    DPIcons.fingerprint,
                    color: DP.green,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: DPTextLink(
                  label: 'Log in with email or phone instead',
                  color: DP.muted,
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
