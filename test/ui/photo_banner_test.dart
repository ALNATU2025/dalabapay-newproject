// Premium photo banners (dashboard, Add Money, Withdraw).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/widgets/photo_banner.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

const _photos = [
  'assets/images/banner_tv.jpg',
  'assets/images/banner_call.jpg',
  'assets/images/banner_wow.jpg',
  'assets/images/orange_money.png',
  'assets/images/afrimoney.png',
];

Widget _gallery() => ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        PhotoBanner(
          tag: 'Add money',
          title: 'Top up in\nseconds',
          subtitle: 'Dial a code, approve with your Orange Money or Afrimoney PIN. Done.',
          cta: 'Add money',
          mobileMoney: true,
          colors: [Color(0xFF2B1204), Color(0xFFB4530F)],
          accent: Color(0xFFFFB25B),
        ),
        SizedBox(height: 16),
        PhotoBanner(
          tag: 'Cable TV',
          title: 'Never miss\nyour shows',
          subtitle: 'DStv, GOtv & StarTimes, paid in Leones.',
          cta: 'Renew now',
          photo: 'assets/images/banner_tv.jpg',
          photoAlignment: Alignment(0.3, 0),
          accent: Color(0xFF5CC8FF),
          chip: 'Instant',
          chipIcon: Icons.play_arrow_rounded,
        ),
        SizedBox(height: 16),
        PhotoBanner(
          tag: 'International airtime',
          title: 'Call home,\nwherever home is',
          subtitle: 'Send airtime to family in Nigeria, Ghana, the UK and more.',
          cta: 'Top up abroad',
          photo: 'assets/images/banner_call.jpg',
          photoAlignment: Alignment(0, -0.45),
          colors: [Color(0xFF032A1F), Color(0xFF07734F)],
          accent: Color(0xFF6EE7B7),
          chip: '150+ countries',
          chipIcon: Icons.public_rounded,
        ),
        SizedBox(height: 16),
        PhotoBanner(
          tag: 'Withdraw',
          title: 'Your money,\non your phone',
          subtitle: 'Cash out to Orange Money or Afrimoney, usually in under a minute.',
          cta: null,
          photo: 'assets/images/banner_wow.jpg',
          photoAlignment: Alignment(0, -0.5),
          colors: [Color(0xFF2A0A2E), Color(0xFF7A1F6E)],
          accent: Color(0xFFF0ABFC),
          chip: 'Instant',
          chipIcon: Icons.bolt_rounded,
          height: 150,
        ),
      ],
    );

void main() {
  setUpAll(loadTestFonts);

  testWidgets('photo banners', (tester) async {
    // Decode the photos for real before the screenshot.
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _gallery())));
    final ctx = tester.element(find.byType(ListView));
    await tester.runAsync(() async {
      for (final p in _photos) {
        await precacheImage(AssetImage(p), ctx);
      }
    });
    await snap(tester, 'photo_banners', () => Scaffold(backgroundColor: DP.bg, body: _gallery()), size: const Size(390, 844));
    expect(find.text('Never miss\nyour shows'), findsOneWidget);
    expect(find.text('Renew now'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(5)); // 3 photos + 2 logos
  });
}
