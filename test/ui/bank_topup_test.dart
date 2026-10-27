// Nigeria "Add money" by transfer: the confirm page (account to pay,
// "I have sent it" / "Cancel", the do-not-close warning) and its end states.
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/wallet/bank_topup_screen.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

Map<String, dynamic> _topUp(String stage) => {
      'id': '65f000000000000000000001',
      'reference': 'BT202610270130AB12',
      'amount': 50000,
      'status': stage == 'confirmed' ? 'success' : stage == 'cancelled' ? 'failed' : 'pending',
      'stage': stage,
      'account': {'accountNumber': '3002991121', 'accountName': 'Dalabapay Digital Service', 'bankName': 'Kuda Bank'},
      'createdAt': '2026-10-27T00:30:00Z',
    };

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  for (final dark in [false, true]) {
    testWidgets('bank top-up: pay${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'bank_topup_pay', () => BankTopUpScreen(topUp: _topUp('awaiting')), dark: dark);
      expect(find.text('3002991121'), findsOneWidget);
      expect(find.text('Dalabapay Digital Service'), findsOneWidget);
      expect(find.text('Send exactly ₦50,000.00'), findsOneWidget);
      expect(find.text('I have sent it'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Do not close this page until your transaction is confirmed.'), findsOneWidget);
    });
  }

  testWidgets('bank top-up: confirmed', (tester) async {
    await snap(tester, 'bank_topup_done', () => BankTopUpScreen(topUp: _topUp('confirmed')));
    expect(find.text('Wallet funded'), findsOneWidget);
    expect(find.text('I have sent it'), findsNothing);
  });

  testWidgets('bank top-up: cancelled', (tester) async {
    await snap(tester, 'bank_topup_cancelled', () => BankTopUpScreen(topUp: _topUp('cancelled')));
    expect(find.text('Top-up cancelled'), findsOneWidget);
  });
}
