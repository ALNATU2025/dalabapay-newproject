// lib/presentation/widgets/pin_sheet.dart
// Asks for the 6-digit payment PIN in a bottom sheet (for actions that
// aren't payments, such as showing card details).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/ui.dart';

/// Returns the PIN, or null if the sheet was closed.
Future<String?> askPin(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DP.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
    ),
    builder: (ctx) => _PinSheet(title: title, message: message, confirmLabel: confirmLabel),
  );
}

class _PinSheet extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  const _PinSheet({required this.title, required this.message, required this.confirmLabel});

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _done() {
    final pin = _pin.text.trim();
    if (pin.length != 6) {
      dpSnack(context, 'Enter your 6-digit PIN', error: true);
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 8),
              Text(widget.title, style: DP.title),
              if (widget.message != null) ...[
                const SizedBox(height: 6),
                Text(widget.message!, style: DP.caption),
              ],
              const SizedBox(height: 18),
              const DPLabel('Payment PIN'),
              DPField(
                controller: _pin,
                hint: '••••••',
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onSubmitted: (_) => _done(),
              ),
              const SizedBox(height: 18),
              DPButton(label: widget.confirmLabel, icon: DPIcons.lock, onPressed: _done),
            ],
          ),
        ),
      ),
    );
  }
}
