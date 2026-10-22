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

/// A small drawn flag (doesn't depend on the device having emoji fonts).
/// Nigeria: green-white-green vertical. Sierra Leone: green-white-blue
/// horizontal.
class DPFlag extends StatelessWidget {
  final String country;
  final double width;
  const DPFlag(this.country, {super.key, this.width = 26});

  @override
  Widget build(BuildContext context) {
    final h = width * 2 / 3;
    const ngGreen = Color(0xFF008751);
    const slGreen = Color(0xFF1EB53A);
    const slBlue = Color(0xFF0072C6);
    final stripes = country == 'SL'
        ? Column(children: [
            Expanded(child: Container(color: slGreen)),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: slBlue)),
          ])
        : Row(children: [
            Expanded(child: Container(color: ngGreen)),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: ngGreen)),
          ]);
    // Keeps its own size inside stretching slots (e.g. a field's prefix).
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Semantics(
      label: country == 'SL' ? 'Sierra Leone flag' : 'Nigeria flag',
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x22000000), width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: stripes,
      ),
      ),
    );
  }
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
                DPFlag(c.code, width: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DP.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(c.currencyName, style: DP.caption.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                // The tick only takes room when selected.
                AnimatedSize(
                  duration: DPMotion.fast,
                  child: on
                      ? const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(DPIcons.checkCircle, color: DP.green, size: 18),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
