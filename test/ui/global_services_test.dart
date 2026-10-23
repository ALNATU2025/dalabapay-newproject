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

  test('money in other currencies', () {
    expect(usd(1250.5), '\$1,250.50');
    expect(moneyCode(1250, 'GHS'), 'GHS 1,250.00');
    expect(moneyCode(25, 'SLE'), 'Le 25.00');
    expect(moneyCode(1500, 'NGN'), '₦1,500.00');
  });
}
