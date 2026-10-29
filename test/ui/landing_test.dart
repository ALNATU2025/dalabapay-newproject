// The website's front page, on a desktop and a phone-sized window.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/landing/landing_screen.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  testWidgets('landing page (desktop)', (tester) async {
    await snap(tester, 'landing_desktop', () => const LandingScreen(), size: const Size(1366, 900));
    expect(find.text('Create free account'), findsOneWidget);
    expect(find.text('Google Play'), findsWidgets);
    expect(find.textContaining('Pay bills, add money'), findsOneWidget);
  });

  testWidgets('landing page (phone)', (tester) async {
    await snap(tester, 'landing_phone', () => const LandingScreen());
    expect(find.text('Create free account'), findsOneWidget);
    expect(find.byType(PlayStoreBadge), findsWidgets);
  });
}
