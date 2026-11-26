// Sierra Leone instant Add Money (Monime): choose Orange Money / Afrimoney.
import 'dart:ui' show instantiateImageCodec;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
    // Load the two logos before the screenshot.
    await tester.runAsync(() async {
      for (final a in ['assets/images/orange_money.png', 'assets/images/afrimoney.png']) {
        final data = await rootBundle.load(a);
        await instantiateImageCodec(data.buffer.asUint8List());
      }
    });
    await snap(
      tester,
      'sl_instant_topup',
      () => Scaffold(
        backgroundColor: DP.bg,
        body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: SlInstantTopup(info: info)),
      ),
      size: const Size(390, 820),
    );
    expect(find.byType(Image), findsNWidgets(2)); // Orange Money + Afrimoney logos
    expect(find.text('Get payment code'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.byType(Image).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
