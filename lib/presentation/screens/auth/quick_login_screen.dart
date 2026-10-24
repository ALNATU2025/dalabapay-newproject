// lib/presentation/screens/auth/quick_login_screen.dart
// "Welcome back": the person's photo and name, then the PIN (or
// fingerprint / face) to get back in — used when the session has expired,
// after logging out, and when opening the app.
//   POST /api/auth/quick-login   (device key + PIN, or biometric key)
// Older installs without a device key unlock with the saved session
// (POST /api/auth/pin/verify), or go to the password login.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/quick_login.dart';
import '../../../ui/ui.dart';

class QuickLoginScreen extends StatefulWidget {
  /// Shown above the PIN, e.g. "Your session has ended".
  final String? notice;
  const QuickLoginScreen({super.key, this.notice});

  @override
  State<QuickLoginScreen> createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends State<QuickLoginScreen> {
  QuickProfile? _profile;
  bool _hasDevice = false;
  bool _bioReady = false;
  bool _bioSupported = false;
  String _pin = '';
  String _error = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    SecureScreen.enter();
    _load();
  }

  @override
  void dispose() {
    SecureScreen.exit();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await QuickLogin.profile();
    final bio = await QuickLogin.biometricEnabled;
    final supported = await QuickLogin.biometricsSupported;
    if (!mounted) return;
    // No device key and no saved session: password login.
    if (p == null && !api.hasToken) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    setState(() {
      _profile = p;
      _hasDevice = p != null;
      _bioReady = bio && supported && p != null;
      _bioSupported = supported;
    });
    // Offer the fingerprint straight away.
    if (_bioReady) _biometric();
  }

  String get _name {
    final p = _profile;
    if (p != null) return p.firstName;
    return Session.instance.user?.firstName ?? 'there';
  }

  String get _fullName => _profile?.fullName ?? Session.instance.user?.fullName ?? '';

  Uint8List? get _photo => _profile?.avatarBytes ?? Session.instance.user?.avatarBytes;

  void _digit(String d) {
    if (_checking || _pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = '';
      _pin += d;
    });
    if (_pin.length == 6) _submit();
  }

  void _back() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _done(Map<String, dynamic>? data) async {
    if (data != null) await Session.instance.start(data);
    await Session.instance.refreshQuietly();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Session.instance.homeRoute, (_) => false);
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final pin = _pin;
    try {
      if (_hasDevice) {
        final data = await QuickLogin.signInWithPin(pin);
        if (!mounted) return;
        await _offerBiometric(data, pin);
        await _done(data);
      } else {
        // Saved session from before quick sign-in existed.
        await api.post('/api/auth/pin/verify', {'pin': pin});
        await _done(null);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'DEVICE_REVOKED') {
        await QuickLogin.revoked();
        if (!mounted) return;
        await dpDialog(context,
            title: 'Please log in again', message: 'For your security, log in with your password on this phone.', tone: DPTone.info);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      HapticFeedback.heavyImpact();
      setState(() {
        _checking = false;
        _pin = '';
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _pin = '';
        _error = errorMessage(e);
      });
    }
  }

  /// After a PIN sign-in, offer fingerprint sign-in once.
  Future<void> _offerBiometric(Map<String, dynamic> data, String pin) async {
    if (!_bioSupported || await QuickLogin.biometricEnabled) return;
    if (await api.readFlag('bio_offered')) return;
    await api.setFlag('bio_offered');
    if (!mounted) return;
    final yes = await dpDialog(
      context,
      title: 'Use your fingerprint next time?',
      message: 'Sign in faster with your fingerprint or face. You can turn it off in Profile → Security.',
      confirmLabel: 'Turn on',
      cancelLabel: 'Not now',
      tone: DPTone.info,
    );
    if (yes != true) return;
    // The new session is needed to turn it on.
    final token = data['token']?.toString();
    if (token != null) await api.setToken(token);
    try {
      await QuickLogin.enableBiometric(pin);
    } catch (_) {}
  }

  Future<void> _biometric() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = '';
    });
    try {
      final data = await QuickLogin.signInWithBiometric();
      if (!mounted) return;
      if (data == null) {
        setState(() => _checking = false);
        return;
      }
      await _done(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'BIOMETRIC_INVALID') await QuickLogin.disableBiometric();
      setState(() {
        _checking = false;
        _bioReady = e.code != 'BIOMETRIC_INVALID';
        _error = e.message;
      });
    }
  }

  Future<void> _usePassword() async {
    final notMe = await dpDialog(
      context,
      title: 'Log in with password?',
      message: 'This removes $_name\'s quick sign-in from this phone.',
      confirmLabel: 'Continue',
      cancelLabel: 'Cancel',
      tone: DPTone.info,
    );
    if (notMe != true) return;
    await QuickLogin.forget();
    await Session.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      backgroundColor: DP.bg,
      body: Column(
        children: [
          // Brand header with the photo overlapping it.
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: double.infinity,
                height: 210,
                decoration: const BoxDecoration(
                  gradient: DP.navyGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      children: [
                        const DPAppear(child: DPWordmark(height: 32, light: true)),
                        const SizedBox(height: 10),
                        Text(
                          widget.notice ?? 'Secure sign-in',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -52,
                child: DPAppear(
                  scaleFrom: 0.8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DP.bg,
                      boxShadow: DP.shadowMd,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [DP.green, DP.navyIcon]),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 98,
                          height: 98,
                          child: DPAvatar(name: _fullName, bytes: photo, size: 98),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 62),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  DPAppear(
                    delay: const Duration(milliseconds: 120),
                    child: Text('Welcome back, $_name', textAlign: TextAlign.center, style: DP.title.copyWith(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _bioReady ? 'Use your fingerprint or enter your PIN' : 'Enter your 6-digit PIN to continue',
                    textAlign: TextAlign.center,
                    style: DP.body.copyWith(color: DP.muted),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: DPPinDots(length: 6, filled: _pin.length, error: _error.isNotEmpty),
                  ),
                  if (_error.isNotEmpty) DPHelper(_error, color: DP.red, icon: DPIcons.alert),
                  SizedBox(height: 4, child: _checking ? const LinearProgressIndicator(color: DP.green) : null),
                  const SizedBox(height: 12),
                  DPKeypad(
                    onDigit: _digit,
                    onBackspace: _back,
                    leftAction: _bioReady
                        ? IconButton(
                            tooltip: 'Use fingerprint',
                            iconSize: 34,
                            icon: const Icon(Icons.fingerprint_rounded, color: DP.green),
                            onPressed: _biometric,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  DPTextLink(label: 'Not $_name? Log in with password', color: DP.muted, onTap: _usePassword),
                  const SizedBox(height: 4),
                  DPTextLink(label: 'Forgot PIN?', color: DP.muted, onTap: () => Navigator.pushNamed(context, '/forgot-password')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
