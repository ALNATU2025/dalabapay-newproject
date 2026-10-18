// lib/presentation/screens/auth/change_pin_screen.dart
// UI only — current PIN → new PIN → confirm. "Forgot PIN?" swaps the first
// step for an emailed reset code. Nothing is checked or saved.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'password_widgets.dart';

enum _PinStep { current, resetCode, create, confirm }

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  _PinStep _step = _PinStep.current;
  String _entry = '';
  String _newPin = '';
  String _error = '';
  bool _resetting = false;

  String get _title => switch (_step) {
        _PinStep.current => 'Enter your current PIN.',
        _PinStep.resetCode => 'Enter your reset code.',
        _PinStep.create => 'Choose a new PIN.',
        _PinStep.confirm => 'Confirm your new PIN.',
      };

  String get _subtitle => switch (_step) {
        _PinStep.current => 'For your security, we require your current PIN.',
        _PinStep.resetCode => 'We sent a 6-digit code to your email.',
        _PinStep.create =>
          'Avoid birthdays and repeated numbers like 111111.',
        _PinStep.confirm => 'Enter the same 6 digits again.',
      };

  int get _stepIndex => switch (_step) {
        _PinStep.current || _PinStep.resetCode => 0,
        _PinStep.create => 1,
        _PinStep.confirm => 2,
      };

  void _onDigit(String d) {
    if (_entry.length >= 6) return;
    setState(() {
      _error = '';
      _entry += d;
    });
    if (_entry.length < 6) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        switch (_step) {
          case _PinStep.current:
          case _PinStep.resetCode:
            _step = _PinStep.create;
            break;
          case _PinStep.create:
            _newPin = _entry;
            _step = _PinStep.confirm;
            break;
          case _PinStep.confirm:
            if (_entry != _newPin) {
              _error = 'PINs do not match';
              _entry = '';
              return;
            }
            _done();
            break;
        }
        _entry = '';
      });
    });
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _done() {
    showDoneSheet(
      context,
      title: _resetting ? 'PIN Reset Successful!' : 'PIN Changed Successfully!',
      message: _resetting
          ? 'Your transaction PIN has been reset. You can now use your new PIN.'
          : 'Your transaction PIN has been updated.',
      buttonLabel: 'Done',
      onPressed: () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(title: _resetting ? 'Reset PIN' : 'Change PIN'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(3, (i) {
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _stepIndex ? DP.green : DP.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    Text(_title, style: DP.display),
                    const SizedBox(height: 8),
                    Text(_subtitle, style: DP.body.copyWith(color: DP.muted)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: DPPinDots(
                        length: 6,
                        filled: _entry.length,
                        error: _error.isNotEmpty,
                        obscure: _step != _PinStep.resetCode,
                        value: _step == _PinStep.resetCode ? _entry : null,
                      ),
                    ),
                    if (_error.isNotEmpty)
                      DPHelper(_error, color: DP.red, icon: DPIcons.alert),
                    const SizedBox(height: 8),
                    DPKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
                    const SizedBox(height: 12),
                    if (_step == _PinStep.current)
                      Center(
                        child: DPTextLink(
                          label: 'Forgot PIN?',
                          onTap: () => setState(() {
                            _resetting = true;
                            _entry = '';
                            _step = _PinStep.resetCode;
                          }),
                        ),
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
