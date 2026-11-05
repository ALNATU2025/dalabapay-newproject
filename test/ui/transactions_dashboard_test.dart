// Transaction Records dashboard on the Transactions page, in Naira and in
// Leones, with data and empty.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/widgets/transactions_dashboard.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

Map<String, dynamic> _summary(String currency, {bool empty = false}) {
  final k = currency == 'SLE' ? 0.05 : 1.0;
  final series = [
    for (var i = 0; i < 30; i++)
      {
        'date': DateTime.utc(2026, 10, 7 + i).toIso8601String().substring(0, 10),
        'in': empty ? 0 : ((i % 6 == 0) ? 25000 * k : 0),
        'out': empty ? 0 : ((i * 3700 % 11000) + 800) * k,
      }
  ];
  return {
    'period': '30d',
    'unit': 'day',
    'currency': currency,
    'to': '2026-11-05T20:00:00Z',
    'moneyIn': empty ? 0 : 125000 * k,
    'moneyOut': empty ? 0 : 98450 * k,
    'net': empty ? 0 : 26550 * k,
    'commissionEarned': empty ? 0 : 1240.5 * k,
    'previous': {'moneyIn': empty ? 0 : 100000 * k, 'moneyOut': empty ? 0 : 109389 * k},
    'counts': {'total': empty ? 0 : 42, 'success': empty ? 0 : 38, 'pending': empty ? 0 : 1, 'failed': empty ? 0 : 3},
    'categories': empty
        ? []
        : [
            {'key': 'transfers', 'label': 'Transfers', 'amount': 40000 * k, 'count': 4, 'share': 40.6},
            {'key': 'cable', 'label': 'Cable TV', 'amount': 24000 * k, 'count': 2, 'share': 24.4},
            {'key': 'electricity', 'label': 'Electricity', 'amount': 18000 * k, 'count': 3, 'share': 18.3},
            {'key': 'data', 'label': 'Data', 'amount': 10450 * k, 'count': 12, 'share': 10.6},
            {'key': 'airtime', 'label': 'Airtime', 'amount': 6000 * k, 'count': 17, 'share': 6.1},
          ],
    'series': series,
  };
}

Widget _page(Map<String, dynamic> data) => Scaffold(
      backgroundColor: DP.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: TransactionsDashboard(initialData: data),
      ),
    );

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  for (final dark in [false, true]) {
    testWidgets('dashboard: Nigeria${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'txn_dashboard_ng', () => _page(_summary('NGN')), size: const Size(390, 1500), dark: dark);
      expect(find.text('Transaction Records'), findsOneWidget);
      expect(find.text('₦125,000.00'), findsOneWidget);
      expect(find.text('₦98,450.00'), findsOneWidget);
      expect(find.text('+₦26,550.00'), findsOneWidget);
      expect(find.text('Cable TV · 2 payments'), findsOneWidget);
      expect(find.text('▼ 10%'), findsOneWidget); // spent less than before
      expect(find.text('38'), findsOneWidget);
    });
  }

  testWidgets('dashboard: Sierra Leone', (tester) async {
    await snap(tester, 'txn_dashboard_sl', () => _page(_summary('SLE')), size: const Size(390, 1500));
    expect(find.text('Le 6,250.00'), findsOneWidget);
    expect(find.text('Le 4,922.50'), findsOneWidget);
  });

  testWidgets('dashboard: nothing yet', (tester) async {
    await snap(tester, 'txn_dashboard_empty', () => _page(_summary('NGN', empty: true)), size: const Size(390, 1100));
    expect(find.text('No spending in the last 30 days'), findsOneWidget);
    expect(find.text('No completed payments yet'), findsOneWidget);
  });
}
