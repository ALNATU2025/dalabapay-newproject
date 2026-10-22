// lib/presentation/screens/auth/register_screen.dart
// Two steps: details (POST /api/auth/register emails a code) → code
// (POST /api/auth/register/verify creates the account and logs in).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/dev_code.dart';
import '../../../core/firebase_setup.dart';
import '../../../core/format.dart';
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

  /// NG or SL — decides the account's services, dashboard and currency.
  /// Set when the server verifies sign-ups by SMS (Firebase) instead of
  /// an email code.
  bool _sms = false;
  String _phoneE164 = '';
  bool _sendingSms = false;
  final _smsVerifier = SmsVerification();

  /// Null until the person picks one (they must choose).
  String? _country;
  DPCountry get _countryInfo => DPCountry.of(_country);
  bool get _sl => _country == 'SL';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _showVerifyStep = false;
  bool _isLoading = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));

  bool get _detailsValid =>
      _country != null &&
      _fullNameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
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

  Future<void> _continueToVerification() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final r = await api.post('/api/auth/register', {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _countryInfo.localPhone(_phoneController.text) ??
            _phoneController.text.trim(),
        'country': _country,
        'password': _passwordController.text,
        'referralCode': _referralCodeController.text.trim(),
      });
      if (!mounted) return;
      final data = asMap(r);
      setState(() {
        _isLoading = false;
        _showVerifyStep = true;
        _sms = data['verification'] == 'sms';
        _phoneE164 = str(data['phoneE164']);
      });
      if (_sms) {
        await _sendSms();
      } else {
        _startResendTimer();
        showDevCode(context, r);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = errorMessage(e);
      });
    }
  }

  void _backToDetails() {
    _otpController.clear();
    setState(() {
      _showVerifyStep = false;
      _error = null;
    });
  }

  /// Asks Firebase to text the code (also used for "Resend code").
  Future<void> _sendSms() async {
    setState(() {
      _sendingSms = true;
      _error = null;
    });
    try {
      await _smsVerifier.send(
        _phoneE164,
        onCodeSent: () {
          if (!mounted) return;
          setState(() => _sendingSms = false);
          _startResendTimer();
          dpSnack(context, 'Code sent to $_phoneE164', success: true);
        },
        // Android can read the SMS itself: finish without typing.
        onAutoVerified: (idToken) {
          if (mounted && !_isLoading) _finishWithFirebase(idToken);
        },
        onError: (message) {
          if (!mounted) return;
          setState(() {
            _sendingSms = false;
            _error = message;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingSms = false;
        _error = errorMessage(e);
      });
    }
  }

  /// Firebase confirmed the phone: the server checks the token and creates
  /// the account.
  Future<void> _finishWithFirebase(String idToken) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await api.post('/api/auth/register/verify-phone', {
        'email': _emailController.text.trim().toLowerCase(),
        'idToken': idToken,
      });
      await Session.instance.start((data as Map).cast<String, dynamic>());
      await SmsVerification.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/pin-setup', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _resend() async {
    if (_sms) return _sendSms();
    try {
      final r = await api.post('/api/auth/register/resend',
          {'email': _emailController.text.trim().toLowerCase()});
      _startResendTimer();
      if (!mounted) return;
      dpSnack(context, 'A new code is on its way.', success: true);
      showDevCode(context, r);
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _verifyAndCreate() async {
    FocusScope.of(context).unfocus();
    if (_sms) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final token = await _smsVerifier.confirm(_otpController.text.trim());
        if (!mounted) return;
        await _finishWithFirebase(token);
      } catch (e) {
        if (!mounted) return;
        _otpController.clear();
        setState(() {
          _isLoading = false;
          _error = errorMessage(e);
        });
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await api.post('/api/auth/register/verify', {
        'email': _emailController.text.trim().toLowerCase(),
        'code': _otpController.text.trim(),
      });
      await Session.instance.start((data as Map).cast<String, dynamic>());
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/pin-setup', (_) => false);
    } catch (e) {
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _isLoading = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showVerifyStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showVerifyStep) _backToDetails();
      },
      child: Scaffold(
        backgroundColor: DP.surface,
        body: DPWaveBackground(child: SafeArea(
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
        )),
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
                const DPLabel('Select country'),
                DPSelectField(
                  value: _country == null
                      ? null
                      : '${_countryInfo.name} · ${_countryInfo.currencyName}',
                  hint: 'Select country',
                  leading: _country == null
                      ? const Icon(DPIcons.globe, size: 21)
                      : DPFlag(_country!, width: 24),
                  onTap: () async {
                    final picked = await dpPickFromList<DPCountry>(
                      context,
                      title: 'Select country',
                      items: DPCountry.all,
                      selected: _country == null ? null : _countryInfo,
                      labelOf: (c) => c.name,
                      subtitleOf: (c) => c.currencyName,
                      leadingOf: (c) => DPFlag(c.code, width: 28),
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      if (picked.code != _country) _phoneController.clear();
                      _country = picked.code;
                    });
                  },
                ),
                if (_country != null) ...[
                  const SizedBox(height: 6),
                  DPHelper(
                    'You\'ll see ${_countryInfo.name} services and pay in ${_countryInfo.currencyName}. This can\'t be changed later.',
                  ),
                ],
                const SizedBox(height: 16),
                const DPLabel('Full name'),
                DPField(
                  controller: _fullNameController,
                  hint: _sl ? 'Fatmata Kamara' : 'Adaeze Okafor',
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
                  key: ValueKey('phone_$_country'),
                  controller: _phoneController,
                  hint: _countryInfo.phoneHint,
                  keyboardType: TextInputType.phone,
                  maxLength: _countryInfo.phoneLength,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefix: _country == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          child: DPFlag(_country!, width: 24),
                        ),
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
                if (_error != null)
                  DPHelper(_error!, color: DP.red, icon: DPIcons.alert),
                const SizedBox(height: 22),
                DPButton(
                  label: 'Create account',
                  icon: DPIcons.forward,
                  loading: _isLoading,
                  onPressed: _detailsValid && !_isLoading
                      ? _continueToVerification
                      : null,
                ),
                const SizedBox(height: 18),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
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
        DPTopBar(title: _sms ? 'Verify your phone' : 'Verify your email', onBack: _backToDetails),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DPIconBadge(_sms ? DPIcons.sms : DPIcons.mail, size: 64, iconSize: 30),
                const SizedBox(height: 28),
                Text('One quick check.', style: DP.display),
                const SizedBox(height: 10),
                Text(
                  _sms
                      ? (_sendingSms
                          ? 'Sending a 6-digit code by SMS to $_phoneE164…'
                          : 'Enter the 6-digit code we texted to $_phoneE164.')
                      : 'Enter the 6-digit code we sent to $email.',
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
                if (_error != null)
                  DPHelper(_error!, color: DP.red, icon: DPIcons.alert),
                const SizedBox(height: 16),
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend code in 00:${_resendSeconds.toString().padLeft(2, '0')}',
                          style: DP.caption,
                        )
                      : DPTextLink(
                          label: 'Resend code',
                          onTap: _resend,
                        ),
                ),
                const SizedBox(height: 22),
                DPButton(
                  label: _isLoading
                      ? 'Creating your account…'
                      : (_sms ? 'Verify phone' : 'Verify email'),
                  loading: _isLoading,
                  onPressed: _otpController.text.trim().length == 6 && !_isLoading
                      ? _verifyAndCreate
                      : null,
                ),
                const SizedBox(height: 10),
                Center(
                  child: DPTextLink(
                    label: _sms ? 'Change phone number' : 'Change email address',
                    onTap: _isLoading ? null : _backToDetails,
                  ),
                ),
                const SizedBox(height: 18),
                DPBanner(
                  _sms
                      ? 'The SMS can take up to a minute. Make sure the number is right and your phone has signal.'
                      : 'Can\'t find your code? Check your inbox and spam folder. Codes expire after 10 minutes.',
                ),
                const SizedBox(height: 36),
                Center(
                  child: Column(
                    children: [
                      Text('Still having trouble?', style: DP.caption),
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
          Expanded(
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
