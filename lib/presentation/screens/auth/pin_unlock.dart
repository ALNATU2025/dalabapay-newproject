// lib/presentation/screens/auth/pin_unlock.dart
// Shared logic for the PIN unlock screens: checks the PIN with
// POST /api/auth/pin/verify using the saved login.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';

mixin PinUnlock<T extends StatefulWidget> on State<T> {
  String pin = '';
  String error = '';
  bool checking = false;

  /// Called after the PIN is accepted.
  void onUnlocked();

  void addDigit(String d) {
    if (checking || pin.length >= 6) return;
    setState(() {
      error = '';
      pin += d;
    });
    if (pin.length == 6) _check();
  }

  void removeDigit() {
    if (checking || pin.isEmpty) return;
    setState(() => pin = pin.substring(0, pin.length - 1));
  }

  Future<void> _check() async {
    setState(() => checking = true);
    try {
      await api.post('/api/auth/pin/verify', {'pin': pin});
      if (!mounted) return;
      setState(() => checking = false);
      onUnlocked();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        checking = false;
        pin = '';
        error = errorMessage(e);
      });
    }
  }

  Future<void> logOut() async {
    await Session.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}
