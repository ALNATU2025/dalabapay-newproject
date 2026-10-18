// lib/presentation/screens/auth/forgot_password_screen.dart
// Emails a reset code (POST /api/auth/password/forgot), then the OTP screen.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/dev_code.dart';
import '../../../ui/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  bool get _isEmailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final email = _emailController.text.trim().toLowerCase();
    try {
      final r = await api.post('/api/auth/password/forgot', {'email': email});
      if (!mounted) return;
      setState(() => _isLoading = false);
      showDevCode(context, r);
      Navigator.pushNamed(context, '/otp-verification', arguments: email);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.surface,
      body: DPWaveBackground(child: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Forgot password'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPIconBadge(DPIcons.key, size: 64, iconSize: 30),
                    const SizedBox(height: 24),
                    const DPHeadline(
                      'Reset your password.',
                      subtitle:
                          'Enter the email on your account and we\'ll send you a 6-digit code.',
                    ),
                    const DPLabel('Email address'),
                    DPField(
                      controller: _emailController,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      prefix: const Icon(DPIcons.mail, size: 20),
                      suffix: _isEmailValid
                          ? const Icon(
                              DPIcons.checkCircle,
                              color: DP.green,
                              size: 20,
                            )
                          : null,
                    ),
                    const SizedBox(height: 28),
                    DPButton(
                      label: 'Send code',
                      loading: _isLoading,
                      onPressed: _isEmailValid && !_isLoading ? _sendCode : null,
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
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _TrustStrip(),
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

/// Secure · Fast · Reliable strip used on the password screens.
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    Widget badge(IconData i, String l) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 16, color: DP.green),
            const SizedBox(width: 6),
            Text(
              l,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: DP.green,
              ),
            ),
          ],
        );
    Widget sep() => Container(width: 1, height: 18, color: DP.mintLine);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: DP.mint,
        borderRadius: BorderRadius.circular(DP.rLg),
        border: Border.all(color: DP.mintLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          badge(Icons.shield_rounded, 'Secure'),
          sep(),
          badge(Icons.bolt_rounded, 'Fast'),
          sep(),
          badge(Icons.verified_rounded, 'Reliable'),
        ],
      ),
    );
  }
}
