// lib/presentation/screens/auth/register_screen.dart
// UI only — two steps (details → email code). Nothing is sent anywhere;
// "Verify email" continues to PIN setup.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _showVerifyStep = false;
  bool _isLoading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));

  bool get _detailsValid =>
      _fullNameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text &&
      _agreedToTerms;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _fullNameController,
      _emailController,
      _phoneController,
      _passwordController,
      _confirmPasswordController,
      _otpController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 59);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  void _continueToVerification() {
    FocusScope.of(context).unfocus();
    setState(() => _showVerifyStep = true);
    _startResendTimer();
  }

  void _backToDetails() {
    _otpController.clear();
    setState(() => _showVerifyStep = false);
  }

  Future<void> _verifyAndCreate() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacementNamed(context, '/pin-setup');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showVerifyStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showVerifyStep) _backToDetails();
      },
      child: Scaffold(
        backgroundColor: DP.bg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showVerifyStep
                ? KeyedSubtree(
                    key: const ValueKey('verify'),
                    child: _buildEmailVerificationBlock(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('details'),
                    child: _buildDetails(),
                  ),
          ),
        ),
      ),
    );
  }

  /// Step 1 — account details.
  Widget _buildDetails() {
    return Column(
      children: [
        DPTopBar(
          title: 'Create your account',
          onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DPHeadline(
                  'Make room for simpler.',
                  subtitle: 'Your bills, wallet and rewards. Together.',
                ),
                const DPLabel('Full name'),
                DPField(
                  controller: _fullNameController,
                  hint: 'Adaeze Okafor',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  suffix: const Icon(DPIcons.user, size: 21),
                ),
                const SizedBox(height: 16),
                const DPLabel('Email address'),
                DPField(
                  controller: _emailController,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  suffix: const Icon(DPIcons.mail, size: 21),
                ),
                const SizedBox(height: 16),
                const DPLabel('Phone number'),
                DPField(
                  controller: _phoneController,
                  hint: '0803 456 7890',
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffix: const Icon(DPIcons.phone, size: 21),
                ),
                const SizedBox(height: 16),
                const DPLabel('Create password'),
                DPField(
                  controller: _passwordController,
                  hint: '••••••••••',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  suffix: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscurePassword ? DPIcons.eyeOff : DPIcons.eye,
                      size: 21,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                _buildPasswordRequirements(),
                const SizedBox(height: 16),
                const DPLabel('Confirm password'),
                DPField(
                  controller: _confirmPasswordController,
                  hint: '••••••••••',
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.next,
                  suffix: IconButton(
                    tooltip: _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscureConfirmPassword ? DPIcons.eyeOff : DPIcons.eye,
                      size: 21,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const DPLabel('Referral code (optional)'),
                DPField(
                  controller: _referralCodeController,
                  hint: 'Enter a referral code',
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 18),
                _buildTermsCheckbox(),
                const SizedBox(height: 22),
                DPButton(
                  label: 'Create account',
                  icon: DPIcons.forward,
                  onPressed: _detailsValid ? _continueToVerification : null,
                ),
                const SizedBox(height: 18),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: DP.caption,
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          'Log in',
                          style: DP.caption.copyWith(
                            color: DP.green,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  /// Step 2 — "One quick check." email code.
  Widget _buildEmailVerificationBlock() {
    final email = _emailController.text.trim();
    return Column(
      children: [
        DPTopBar(title: 'Verify your email', onBack: _backToDetails),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DPIconBadge(DPIcons.mail, size: 64, iconSize: 30),
                const SizedBox(height: 28),
                const Text('One quick check.', style: DP.display),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code we sent to $email.',
                  style: DP.body.copyWith(color: DP.muted),
                ),
                const SizedBox(height: 26),
                DPCodeInput(
                  controller: _otpController,
                  length: 6,
                  obscure: false,
                  autofocus: true,
                  onCompleted: (_) {
                    if (!_isLoading) _verifyAndCreate();
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend code in 00:${_resendSeconds.toString().padLeft(2, '0')}',
                          style: DP.caption,
                        )
                      : DPTextLink(
                          label: 'Resend code',
                          onTap: _startResendTimer,
                        ),
                ),
                const SizedBox(height: 22),
                DPButton(
                  label: _isLoading ? 'Creating your account…' : 'Verify email',
                  loading: _isLoading,
                  onPressed: _otpController.text.trim().length == 6
                      ? _verifyAndCreate
                      : null,
                ),
                const SizedBox(height: 10),
                Center(
                  child: DPTextLink(
                    label: 'Change email address',
                    onTap: _isLoading ? null : _backToDetails,
                  ),
                ),
                const SizedBox(height: 18),
                const DPBanner(
                  'Can\'t find your code? Check your inbox and spam folder. Codes expire after 10 minutes.',
                ),
                const SizedBox(height: 36),
                Center(
                  child: Column(
                    children: [
                      const Text('Still having trouble?', style: DP.caption),
                      const SizedBox(height: 4),
                      DPTextLink(
                        label: 'Get help from our team',
                        onTap: () => Navigator.pushNamed(context, '/help'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final ok = _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _buildRequirementItem('8+ characters', _hasMinLength),
          _buildRequirementItem(
            'Upper & lower case',
            _hasUppercase && _hasLowercase,
          ),
          _buildRequirementItem('A number', _hasNumber),
          if (ok)
            const Text(
              'Strong password',
              style: TextStyle(
                fontSize: 12.5,
                color: DP.green,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isValid) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isValid ? DPIcons.checkCircle : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: isValid ? DP.green : DP.faint,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: isValid ? DP.green : DP.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'By creating an account, you agree to our Terms of use and Privacy policy.',
              style: DP.caption,
            ),
          ),
        ],
      ),
    );
  }
}
