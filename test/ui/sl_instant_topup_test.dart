// Sierra Leone instant Add Money (Monime): choose Orange Money / Afrimoney.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/sierra_leone/sl_instant_topup.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  const info = {
    'available': true,
    'providers': [
      {'id': 'm17', 'name': 'Orange Money'},
      {'id': 'm18', 'name': 'Afrimoney'},
    ],
    'minAmount': 10,
    'maxAmount': 100000,
    'feePercent': 0,
  };

  testWidgets('instant top-up form', (tester) async {
    await snap(
      tester,
      'sl_instant_topup',
      () => Scaffold(
        backgroundColor: DP.bg,
        body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: SlInstantTopup(info: info)),
      ),
      size: const Size(390, 820),
    );
    expect(find.text('Orange Money'), findsOneWidget);
    expect(find.text('Afrimoney'), findsOneWidget);
    expect(find.text('Get payment code'), findsOneWidget);
    await tester.tap(find.text('Afrimoney'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
