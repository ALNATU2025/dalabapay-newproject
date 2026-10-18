// lib/presentation/screens/auth/login_screen.dart
// UI only — no authentication. "Login" just opens the dashboard.
import 'package:flutter/material.dart';

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

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  late final AnimationController _fadeController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..forward();
  late final Animation<double> _fadeAnimation =
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

  bool get _formValid =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacementNamed(context, '/dashboard');
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
                      DPField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'Email or Phone Number',
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
                          GestureDetector(
                            onTap: () =>
                                setState(() => _rememberMe = !_rememberMe),
                            child: Text(
                              'Remember me',
                              style:
                                  TextStyle(fontSize: 13.5, color: DP.inkSoft),
                            ),
                          ),
                          const Spacer(),
                          DPTextLink(
                            label: 'Forgot password?',
                            fontSize: 13.5,
                            onTap: () =>
                                Navigator.pushNamed(context, '/forgot-password'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      DPButton(
                        label: 'Login',
                        loading: _isLoading,
                        onPressed: _formValid ? _handleLogin : null,
                      ),
                      const SizedBox(height: 10),
                      _buildQuickBiometricButton(),
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/pin-login'),
                          icon: const Icon(
                            DPIcons.lock,
                            size: 18,
                            color: DP.green,
                          ),
                          label: const Text(
                            'Unlock with PIN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: DP.green,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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

  Widget _buildQuickBiometricButton() {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(DP.rMd),
        onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(DPIcons.fingerprint, color: DP.green, size: 26),
              SizedBox(width: 10),
              Text(
                'Login with biometrics',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: DP.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
