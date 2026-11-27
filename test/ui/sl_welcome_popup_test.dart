// Sierra Leone "Kushe!" welcome pop-up.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/sierra_leone/sl_welcome_popup.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('welcome pop-up', (tester) async {
    // Decode the photo for real before the screenshot.
    await tester.pumpWidget(const MaterialApp(home: SlWelcomePopup()));
    await tester.runAsync(() => precacheImage(const AssetImage('assets/images/sl_welcome.jpg'), tester.element(find.byType(SlWelcomePopup))));
    await snap(
      tester,
      'sl_welcome_popup',
      () => Scaffold(
        backgroundColor: DP.navyDeep,
        body: const ColoredBox(color: Color(0x8C000000), child: SlWelcomePopup(firstName: 'Alusine')),
      ),
      size: const Size(390, 844),
    );
    expect(find.text('Kushe, Alusine!'), findsOneWidget);
    expect(find.text('Pay bills now'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('returns true for Pay bills now, false for close', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSlWelcome(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Kushe!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sl-welcome-go')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sl-welcome-close')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
