// Design-system gallery: renders the shared widgets in light and dark so
// CI can publish screenshots (artifact "ui-screenshots") and catch layout
// errors such as overflows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/widgets/transaction_widgets.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

// Example rows shaped like the API's transaction JSON (test data only).
final _now = DateTime.now();
final _rows = <Map<String, dynamic>>[
  {
    'type': 'airtime',
    'description': 'MTN Airtime · 08031234567',
    'amount': 1500,
    'status': 'success',
    'createdAt': _now.subtract(const Duration(minutes: 12)).toIso8601String(),
  },
  {
    'type': 'wallet_funding',
    'description': 'Wallet top-up',
    'amount': 20000,
    'status': 'success',
    'isCredit': true,
    'createdAt': _now.subtract(const Duration(hours: 3)).toIso8601String(),
  },
  {
    'type': 'cable',
    'description': 'DStv Compact · 7023456789',
    'amount': 15700,
    'status': 'pending',
    'createdAt': _now.subtract(const Duration(days: 1)).toIso8601String(),
  },
  {
    'type': 'electricity',
    'description': 'Ikeja Electric · 45031234567',
    'amount': 5000,
    'status': 'failed',
    'createdAt': _now.subtract(const Duration(days: 3)).toIso8601String(),
  },
];

Widget _components() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DPSectionHeader('Buttons'),
        DPButton(label: 'Continue', onPressed: () {}),
        DPSpace.h12,
        DPOutlineButton(label: 'Back to home', onPressed: () {}),
        DPSpace.h12,
        const DPButton(label: 'Paying…', onPressed: null, loading: true),
        DPSpace.h24,
        const DPSectionHeader('Fields'),
        const DPLabel('Phone number'),
        const DPField(hint: '0803 123 4567', prefix: Icon(DPIcons.smartphone)),
        DPSpace.h12,
        const DPField(hint: 'Amount', errorText: 'Minimum amount is ₦50'),
        DPSpace.h24,
        const DPSectionHeader('Chips'),
        DPChipRow(
          options: const ['MTN', 'Airtel', 'Glo', '9mobile'],
          selected: 'MTN',
          onSelect: (_) {},
        ),
        DPSpace.h24,
        const DPBanner('Your account is waiting for approval.',
            tone: DPTone.warning, icon: DPIcons.info),
      ],
    ),
  );
}

Widget _lists() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DPSectionHeader('Transaction History'),
        DPCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: DP.borderSoft),
                TransactionRow(tx: _rows[i]),
              ],
            ],
          ),
        ),
        DPSpace.h24,
        const DPSectionHeader('Loading'),
        const DPSkeletonList(rows: 3),
        DPSpace.h24,
        const DPCard(
          child: DPEmptyState(
            icon: DPIcons.receipt,
            title: 'No transactions yet',
            message: 'Add money to your wallet to start paying bills.',
            actionLabel: 'Add Money',
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  for (final dark in [false, true]) {
    testWidgets('components${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'components', _components(), dark: dark);
    });
    testWidgets('lists${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'lists', _lists(), dark: dark);
    });
  }

  testWidgets('wide screens centre the app', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => DPResponsiveFrame(child: child!),
      home: Builder(
        builder: (context) => Text('w=${MediaQuery.sizeOf(context).width}'),
      ),
    ));
    expect(find.text('w=${DPBreakpoints.appMaxWidth}'), findsOneWidget);
  });

  testWidgets('text scale is capped', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
      child: MaterialApp(
        builder: (context, child) => DPResponsiveFrame(child: child!),
        home: Builder(
          builder: (context) =>
              Text('s=${MediaQuery.textScalerOf(context).scale(10)}'),
        ),
      ),
    ));
    expect(find.text('s=${10 * DPResponsiveFrame.maxTextScale}'), findsOneWidget);
  });
}
