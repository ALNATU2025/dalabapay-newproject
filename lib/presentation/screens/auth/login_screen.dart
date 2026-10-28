// lib/presentation/screens/auth/login_screen.dart
// Email/phone + password login (POST /api/auth/login).
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/dev_code.dart';
import '../../../core/format.dart';
import 'device_verify_screen.dart';
import '../../../ui/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// NG or SL — must be picked before logging in.
  String? _country;
  DPCountry get _countryInfo => DPCountry.of(_country);

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _error;

  late final AnimationController _fadeController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..forward();
  late final Animation<double> _fadeAnimation =
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

  bool get _formValid =>
      _country != null &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _restoreCountry();
  }

  /// Pre-selects the country used last time on this device.
  Future<void> _restoreCountry() async {
    final sl = await api.readFlag('login_country_sl');
    final ng = await api.readFlag('login_country_ng');
    if (!mounted || (!sl && !ng)) return;
    setState(() => _country ??= sl ? 'SL' : 'NG');
  }

  Future<void> _rememberCountry(String code) async {
    await api.setFlag(code == 'SL' ? 'login_country_sl' : 'login_country_ng', on: true);
    await api.setFlag(code == 'SL' ? 'login_country_ng' : 'login_country_sl', on: false);
  }

  /// Email as typed; a phone number in the chosen country's local form.
  String get _identifier {
    final raw = _emailController.text.trim();
    if (raw.contains('@')) return raw;
    return _countryInfo.localPhone(raw) ?? raw;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await api.post('/api/auth/login', {
        'identifier': _identifier,
        'password': _passwordController.text,
        'country': _country,
      });
      await _rememberCountry(_country!);
      final m = (data as Map).cast<String, dynamic>();
      // New device: confirm with the code emailed to the account first.
      if (m['verification'] == 'device') {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showDevCode(context, m);
        final remember = _rememberMe;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceVerifyScreen(
              challenge: str(m['challenge']),
              email: str(m['email']),
              onVerified: (session) => Session.instance.start(session, remember: remember),
            ),
          ),
        );
        return;
      }
      await Session.instance.start(m, remember: _rememberMe);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, Session.instance.homeRoute, (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: DP.surface,
      body: DPWaveBackground(
        child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(28, canPop ? 0 : 28, 28, 24),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canPop)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DPIconSquare(
                            icon: DPIcons.back,
                            size: 40,
                            background: Colors.transparent,
                            semanticLabel: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      Center(child: _buildLogo()),
                      const SizedBox(height: 30),
                      DPAppear(
                        child: Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: DP.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Login to your Dalabapay account',
                        style: DP.body.copyWith(color: DP.muted),
                      ),
                      const SizedBox(height: 24),
                      DPSelectField(
                        value: _country == null
                            ? null
                            : '${_countryInfo.name} · ${_countryInfo.currencyName}',
                        hint: 'Select country',
                        leading: _country == null
                            ? const Icon(DPIcons.globe, size: 20)
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
                          if (picked != null && mounted) {
                            setState(() {
                              _country = picked.code;
                              _error = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      DPField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        hint: _country == null
                            ? 'Email or Phone Number'
                            : 'Email or phone (e.g. ${_countryInfo.phoneHint})',
                        textInputAction: TextInputAction.next,
                        prefix: const Icon(DPIcons.user, size: 20),
                      ),
                      const SizedBox(height: 14),
                      DPField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        hint: 'Password',
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_formValid && !_isLoading) _handleLogin();
                        },
                        prefix: const Icon(DPIcons.lock, size: 20),
                        suffix: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword ? DPIcons.eyeOff : DPIcons.eye,
                            color: DP.muted,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: DP.green,
                              side: BorderSide(color: DP.faint),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Flexible: large system text sizes must not
                          // push "Forgot password?" off the screen.
                          Flexible(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: Text(
                                'Remember me',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5, color: DP.inkSoft),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Spacer(),
                          DPTextLink(
                            label: 'Forgot password?',
                            fontSize: 13.5,
                            onTap: () =>
                                Navigator.pushNamed(context, '/forgot-password'),
                          ),
                        ],
                      ),
                      if (_error != null)
                        DPHelper(_error!, color: DP.red, icon: DPIcons.alert),
                      const SizedBox(height: 22),
                      DPButton(
                        label: 'Login',
                        loading: _isLoading,
                        onPressed: _formValid && !_isLoading ? _handleLogin : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: DP.border)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: DP.caption),
                          ),
                          Expanded(child: Divider(color: DP.border)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DPOutlineButton(
                        label: 'Create an Account',
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/register'),
                      ),
                      const SizedBox(height: 26),
                      Center(
                        child: Text(
                          'Safe  •  Secure  •  Fast',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: DP.muted,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildLogo() {
    return DPAppear(
      scaleFrom: 0.9,
      offsetY: 0,
      child: Column(
        children: [
          DPLogoMark(size: 56),
          SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Dalaba', style: TextStyle(color: DP.navyInk)),
                TextSpan(text: 'pay', style: TextStyle(color: DP.green)),
              ],
            ),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}
