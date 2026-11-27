// The website's front page, on a desktop and a phone-sized window.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/landing/landing_screen.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

const _photos = [
  'assets/images/banner_tv.jpg',
  'assets/images/banner_call.jpg',
  'assets/images/banner_wow.jpg',
  'assets/images/sl_welcome.jpg',
  'assets/images/orange_money.png',
  'assets/images/afrimoney.png',
];

/// Decodes the photos for real so the screenshots show them.
Future<void> _preload(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  final ctx = tester.element(find.byType(SizedBox));
  await tester.runAsync(() async {
    for (final p in _photos) {
      await precacheImage(AssetImage(p), ctx);
    }
  });
}

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  testWidgets('landing page (desktop)', (tester) async {
    await _preload(tester);
    await snap(tester, 'landing_desktop', () => const LandingScreen(), size: const Size(1366, 900));
    expect(find.text('Create free account'), findsOneWidget);
    expect(find.text('Google Play'), findsWidgets);
    expect(find.textContaining('Pay bills, add money'), findsOneWidget);
  });

  testWidgets('landing page (phone)', (tester) async {
    await _preload(tester);
    await snap(tester, 'landing_phone', () => const LandingScreen());
    expect(find.text('Create free account'), findsOneWidget);
    expect(find.byType(PlayStoreBadge), findsWidgets);
  });

  testWidgets('landing page (whole page)', (tester) async {
    await _preload(tester);
    await snap(tester, 'landing_desktop_full', () => const LandingScreen(), size: const Size(1366, 5200));
    await snap(tester, 'landing_phone_full', () => const LandingScreen(), size: const Size(390, 7600));
    expect(find.text('Get the Dalabapay app'), findsOneWidget);
  });
}
