// lib/presentation/screens/auth/otp_verification_screen.dart
// UI only — any 6 digits continue to "Create new password".
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, this.email = 'you@example.com'});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  int _resendCountdown = 59;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() => setState(() {}));
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacementNamed(context, '/reset-password');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Verify code'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPIconBadge(DPIcons.sms, size: 64, iconSize: 30),
                    const SizedBox(height: 24),
                    DPHeadline(
                      'Verify OTP',
                      subtitle:
                          'Enter the 6-digit code sent to ${widget.email}.',
                    ),
                    DPCodeInput(
                      controller: _otpController,
                      length: 6,
                      obscure: false,
                      autofocus: true,
                      onCompleted: (_) {
                        if (!_isLoading) _verify();
                      },
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Didn\'t get it? ', style: DP.caption),
                          _resendCountdown > 0
                              ? Text(
                                  'Resend in ${_resendCountdown}s',
                                  style: DP.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : DPTextLink(
                                  label: 'Resend Code',
                                  fontSize: 13,
                                  onTap: _startTimer,
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    DPButton(
                      label: 'Verify OTP',
                      loading: _isLoading,
                      onPressed:
                          _otpController.text.length == 6 ? _verify : null,
                    ),
                    const SizedBox(height: 18),
                    const DPBanner(
                      'Check your inbox and spam folder. Codes expire after 10 minutes.',
                      tone: DPTone.info,
                      icon: DPIcons.info,
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
