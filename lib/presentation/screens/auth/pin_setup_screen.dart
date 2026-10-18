// lib/presentation/screens/auth/pin_setup_screen.dart
// Create + confirm a 6-digit payment PIN (POST /api/auth/pin/set).
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../ui/ui.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const PinSetupScreen({super.key, this.isFirstTime = true});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await api.post('/api/auth/pin/set', {'pin': _pin});
    } on ApiException catch (e) {
      if (e.code != 'PIN_ALREADY_SET') {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorMessage = e.message;
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = errorMessage(e);
        _confirmPin = '';
      });
      return;
    }
    await Session.instance.refreshQuietly();
    if (!mounted) return;
    dpSnack(context, 'Your payment PIN is set.', success: true);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _onPinDigitPressed(String digit) {
    if (_saving) return;
    setState(() {
      _errorMessage = '';
      if (!_isConfirming) {
        if (_pin.length < 6) _pin += digit;
      } else {
        if (_confirmPin.length < 6) _confirmPin += digit;
      }
    });
    if (!_isConfirming && _pin.length == 6) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _isConfirming = true);
      });
    } else if (_isConfirming && _confirmPin.length == 6) {
      if (_confirmPin == _pin) {
        _save();
      } else {
        setState(() {
          _errorMessage = 'PINs do not match. Try again.';
          _confirmPin = '';
        });
      }
    }
  }

  void _onBackspacePressed() {
    setState(() {
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final changing = !widget.isFirstTime;
    final current = _isConfirming ? _confirmPin : _pin;
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
              const SizedBox(height: 26),
              // Step indicator
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: DP.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _isConfirming ? DP.green : DP.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                _isConfirming
                    ? 'Confirm your PIN.'
                    : (changing
                        ? 'Choose a new PIN.'
                        : 'Create your payment PIN.'),
                style: DP.display,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter the same 6 digits again.'
                    : 'You\'ll use these 6 digits to approve payments. Avoid birthdays and repeated numbers.',
                style: DP.body.copyWith(color: DP.muted),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: DPPinDots(
                  length: 6,
                  filled: current.length,
                  error: _errorMessage.isNotEmpty,
                ),
              ),
              if (_errorMessage.isNotEmpty)
                DPHelper(_errorMessage, color: DP.red, icon: DPIcons.alert),
              const SizedBox(height: 16),
              DPKeypad(
                onDigit: _onPinDigitPressed,
                onBackspace: _onBackspacePressed,
              ),
              if (_saving) const LinearProgressIndicator(color: DP.green),
              const SizedBox(height: 8),
              const DPBanner(
                'Never share your PIN. Dalabapay staff will never ask for it.',
              ),
              Center(
                child: DPTextLink(
                  label: Navigator.of(context).canPop() ? 'Not now' : 'Log out',
                  color: DP.muted,
                  onTap: () async {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                      return;
                    }
                    await Session.instance.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
