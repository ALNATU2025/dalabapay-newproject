// lib/ui/dp_country.dart
// The two countries the app serves and the picker shown at sign-up.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dp_motion.dart';
import 'dp_tokens.dart';

class DPCountry {
  final String code; // NG | SL
  final String name;
  final String flag;
  final String currency; // NGN | SLE
  final String currencyName;
  final String dialCode;
  final String phoneHint;
  final int phoneLength; // local digits, with the leading 0

  const DPCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.currencyName,
    required this.dialCode,
    required this.phoneHint,
    required this.phoneLength,
  });

  static const nigeria = DPCountry(
    code: 'NG',
    name: 'Nigeria',
    flag: '🇳🇬',
    currency: 'NGN',
    currencyName: 'Naira (₦)',
    dialCode: '+234',
    phoneHint: '0803 456 7890',
    phoneLength: 11,
  );

  static const sierraLeone = DPCountry(
    code: 'SL',
    name: 'Sierra Leone',
    flag: '🇸🇱',
    currency: 'SLE',
    currencyName: 'Leones (Le)',
    dialCode: '+232',
    phoneHint: '076 123 456',
    phoneLength: 9,
  );

  static const all = [nigeria, sierraLeone];

  static DPCountry of(String? code) => code == 'SL' ? sierraLeone : nigeria;

  /// Local form of a typed number ("+232 76 123 456" → "076123456"), or
  /// null when it isn't a valid number for this country.
  String? localPhone(String raw) {
    var d = raw.replaceAll(RegExp(r'[\s\-().+]'), '');
    final cc = dialCode.substring(1);
    if (d.startsWith(cc) && d.length == cc.length + phoneLength - 1) {
      d = '0${d.substring(cc.length)}';
    }
    if (d.length == phoneLength - 1 && !d.startsWith('0')) d = '0$d';
    final ok = code == 'SL'
        ? RegExp(r'^0[2-9]\d{7}$').hasMatch(d)
        : RegExp(r'^0[789][01]\d{8}$').hasMatch(d);
    return ok ? d : null;
  }

  String get phoneError => code == 'SL'
      ? 'Enter a valid Sierra Leone number (e.g. 076 123 456)'
      : 'Enter a valid 11-digit Nigerian number';
}

/// Two cards: Nigeria / Sierra Leone. The choice decides the account's
/// services, dashboard and currency.
class DPCountryPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const DPCountryPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in DPCountry.all) ...[
          if (c != DPCountry.all.first) const SizedBox(width: 12),
          Expanded(child: _card(c)),
        ],
      ],
    );
  }

  Widget _card(DPCountry c) {
    final on = c.code == selected;
    return Semantics(
      button: true,
      selected: on,
      label: '${c.name}, ${c.currencyName}',
      excludeSemantics: true,
      child: DPPressable(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(c.code);
          },
          child: AnimatedContainer(
            duration: DPMotion.fast,
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              color: on ? DP.mint : DP.surface,
              borderRadius: BorderRadius.circular(DP.rLg),
              border: Border.all(color: on ? DP.green : DP.border, width: on ? 1.6 : 1),
              boxShadow: on ? DP.shadowSm : const [],
            ),
            child: Row(
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DP.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(c.currencyName, style: DP.caption.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: DPMotion.fast,
                  opacity: on ? 1 : 0,
                  child: const Icon(DPIcons.checkCircle, color: DP.green, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
