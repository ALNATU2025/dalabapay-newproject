// lib/presentation/screens/auth/device_verify_screen.dart
// Logging in on a phone this account hasn't used before: the server
// emails a 6-digit code (POST /api/auth/login answered
// { verification: 'device', challenge, email }) and the session only
// starts after the code is entered (POST /api/auth/login/verify-device).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/dev_code.dart';
import '../../../core/firebase_setup.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';

class DeviceVerifyScreen extends StatefulWidget {
  final String challenge;
  final String email; // masked, e.g. fo••••@gmail.com

  /// 'email' (Nigeria) or 'sms' (Sierra Leone: Firebase texts the code).
  final String method;
  final String phoneE164; // for the SMS
  final String phone; // masked, for display

  /// Called with { token, user } once the code is right.
  final Future<void> Function(Map<String, dynamic> session) onVerified;

  const DeviceVerifyScreen({
    super.key,
    required this.challenge,
    required this.email,
    required this.onVerified,
    this.method = 'email',
    this.phoneE164 = '',
    this.phone = '',
  });

  @override
  State<DeviceVerifyScreen> createState() => _DeviceVerifyScreenState();
}

class _DeviceVerifyScreenState extends State<DeviceVerifyScreen> {
  final _code = TextEditingController();
  int _resendIn = 59;
  Timer? _timer;
  bool _loading = false;
  String? _error;
  final _sms = SmsVerification();
  bool _smsSending = false;

  bool get _bySms => widget.method == 'sms';

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _startTimer();
    if (_bySms) WidgetsBinding.instance.addPostFrameCallback((_) => _sendSms());
  }

  Future<void> _sendSms() async {
    setState(() {
      _smsSending = true;
      _error = null;
    });
    try {
      await _sms.send(
        widget.phoneE164,
        onCodeSent: () {
          if (mounted) setState(() => _smsSending = false);
        },
        onAutoVerified: (token) => _submit(idToken: token),
        onError: (m) {
          if (mounted) {
            setState(() {
              _smsSending = false;
              _error = m;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _smsSending = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!_bySms) return _submit(code: _code.text.trim());
    setState(() {
      _loading = true;
      _error = null;
    });
    String token;
    try {
      token = await _sms.confirm(_code.text.trim());
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
      return;
    }
    await _submit(idToken: token);
  }

  Future<void> _submit({String? code, String? idToken}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = asMap(await api.post('/api/auth/login/verify-device', {
        'challenge': widget.challenge,
        if (code != null) 'code': code,
        if (idToken != null) 'idToken': idToken,
      }));
      if (_bySms) await SmsVerification.signOut();
      await widget.onVerified(r);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(Session.instance.homeRoute, (_) => false);
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _resend() async {
    if (_bySms) {
      _startTimer();
      await _sendSms();
      return;
    }
    try {
      final r = await api.post('/api/auth/login/resend-device-code', {'challenge': widget.challenge});
      _startTimer();
      if (!mounted) return;
      dpSnack(context, 'A new code is on its way.', success: true);
      showDevCode(context, r);
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.surface,
      body: DPWaveBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DPTopBar(title: 'New device'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DPIconBadge(Icons.phonelink_lock_rounded, size: 64, iconSize: 30),
                      const SizedBox(height: 24),
                      DPHeadline(
                        'Confirm it\'s you',
                        subtitle: _bySms
                            ? (_smsSending
                                ? 'You\'re logging in on a new device. Sending a 6-digit code to ${widget.phone}…'
                                : 'You\'re logging in on a new device. Enter the 6-digit code we texted to ${widget.phone}.')
                            : 'You\'re logging in on a new device. Enter the 6-digit code we sent to ${widget.email}.',
                      ),
                      DPCodeInput(
                        controller: _code,
                        length: 6,
                        obscure: false,
                        autofocus: true,
                        onCompleted: (_) {
                          if (!_loading) _verify();
                        },
                      ),
                      if (_error != null) DPHelper(_error!, color: DP.red, icon: DPIcons.alert),
                      const SizedBox(height: 18),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Didn\'t get it? ', style: DP.caption),
                            _resendIn > 0
                                ? Text('Resend in ${_resendIn}s', style: DP.caption.copyWith(fontWeight: FontWeight.w600))
                                : DPTextLink(label: 'Resend Code', fontSize: 13, onTap: _resend),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      DPButton(
                        label: 'Verify and log in',
                        loading: _loading,
                        onPressed: _code.text.length == 6 && !_loading ? _verify : null,
                      ),
                      const SizedBox(height: 18),
                      DPBanner(
                        _bySms
                            ? 'The SMS can take up to a minute. If you didn\'t try to log in, change your password.'
                            : 'Check your inbox and spam folder. The code expires after 10 minutes. If you didn\'t try to log in, change your password.',
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
      ),
    );
  }
}
