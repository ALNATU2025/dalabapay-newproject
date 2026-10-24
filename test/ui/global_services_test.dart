// Dollar card face and the money formats used by the transfer and card
// screens (screenshots go to the ui-screenshots branch like the others).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/cards/cards_screen.dart';
import 'package:dalabapay/presentation/screens/payout/payout_screen.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

Widget _cards() => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DollarCardView(card: {
          'status': 'active',
          'brand': 'Visa',
          'last4': '3585',
          'balanceUsd': 1250.5,
          'validMonthYear': '12/2029',
        }),
        const SizedBox(height: 16),
        const DollarCardView(card: {'status': 'frozen', 'brand': 'Mastercard', 'last4': '0042', 'balanceUsd': 12}),
        const SizedBox(height: 16),
        DPCard(
          child: Column(
            children: [
              for (final c in const [
                ['GH', 'Ghana', 'GHS · Bank · Mobile money'],
                ['SL', 'Sierra Leone', 'SLE · Mobile money'],
                ['KE', 'Kenya', 'KES · Bank · Mobile money'],
              ])
                DPListRow(leading: countryFlag(c[0]), title: c[1], subtitle: c[2]),
            ],
          ),
        ),
      ],
    );

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  for (final dark in [false, true]) {
    testWidgets('dollar cards${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'dollar_cards', _cards, dark: dark);
      expect(find.text('\$1,250.50'), findsOneWidget);
      expect(find.text('Frozen'), findsOneWidget);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('payment banners${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'payment_banners', _banners, dark: dark);
      expect(find.text('Send money globally.'), findsOneWidget);
    });
  }

  testWidgets('receipt with provider and logo', (tester) async {
    DP.currency = 'SLE';
    try {
      await snap(tester, 'receipt_sl', _receipt);
      expect(find.text('Thank you for using Dalabapay'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);
    } finally {
      DP.currency = 'NGN';
    }
  });

  test('money in other currencies', () {
    expect(usd(1250.5), '\$1,250.50');
    expect(moneyCode(1250, 'GHS'), 'GHS 1,250.00');
    expect(moneyCode(25, 'SLE'), 'Le 25.00');
    expect(moneyCode(1500, 'NGN'), '₦1,500.00');
  });
}

// Payment-screen banners and the receipt with the provider badge.
Widget _banners() => ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        DPServiceBanner(
          title: 'Pay, renew or activate your subscription in seconds.',
          subtitle: 'DStv, GOtv and StarTimes — paid in Leones.',
          icon: DPIcons.tv,
          image: DPAssets.svcTv,
          tag: 'Cable TV',
        ),
        SizedBox(height: 16),
        DPServiceBanner(
          title: 'Send money globally.',
          subtitle: 'Banks and mobile money in 22 countries.',
          icon: DPIcons.globe,
          style: DPBannerStyle.ocean,
          tag: 'Send money',
        ),
        SizedBox(height: 16),
        DPServiceBanner(
          title: 'Buy EDSA units and get your token instantly.',
          subtitle: 'Prepaid electricity, any time of day.',
          icon: DPIcons.bolt,
          style: DPBannerStyle.green,
        ),
      ],
    );

Widget _receipt() => DPSuccessPanel(
      serviceLabel: 'Orange Airtime',
      amount: 25,
      rows: const [DPReviewRow('Phone number', '076123456'), DPReviewRow('Reference', 'DP202610241200AB12')],
      onDone: () {},
      onShare: () {},
      provider: const Text('Orange', style: TextStyle(color: Color(0xFFFF7900), fontWeight: FontWeight.w900)),
    );

