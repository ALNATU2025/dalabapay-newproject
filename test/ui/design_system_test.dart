// Design-system gallery: renders the shared widgets in light and dark so
// CI can publish screenshots (artifact "ui-screenshots") and catch layout
// errors such as overflows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/core/format.dart';
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

Widget _home() {
  return Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, Amaka!', style: DP.title),
              Text('Good morning', style: DP.caption),
              DPSpace.h16,
              DPBalanceCard(
                balance: 124850.5,
                earnings: 2310,
                visible: true,
                onToggleVisible: () {},
                onEarnings: () {},
                actions: [
                  DPQuickAction(DPIcons.plus, 'Add Money', () {}),
                  DPQuickAction(DPIcons.upRight, 'Send', () {}),
                  DPQuickAction(DPIcons.receipt, 'Pay Bills', () {}),
                  DPQuickAction(DPIcons.history, 'History', () {}),
                ],
              ),
              DPSpace.h20,
              DPSectionHeader('Essential Services', actionLabel: 'More', onAction: () {}),
              DPServiceGrid(columns: 3, tiles: [
                DPServiceTile(icon: DPIcons.receipt, label: 'Pay Bill', color: DP.green, onTap: () {}),
                DPServiceTile(icon: DPIcons.tv, label: 'Pay TV', color: DP.navyIcon, onTap: () {}),
                DPServiceTile(icon: DPIcons.globe, label: 'International Airtime', color: DP.navyIcon, onTap: () {}),
              ]),
              DPSpace.h20,
              DPSectionHeader('Transaction History', actionLabel: 'See All', onAction: () {}),
              DPCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  TransactionRow(tx: _rows[0]),
                  Divider(height: 1, color: DP.borderSoft),
                  TransactionRow(tx: _rows[1]),
                ]),
              ),
            ],
          ),
        ),
      ),
      DPBottomNav(index: 0, items: kDPTabs, onTap: (_) {}, onCenter: () {}),
    ],
  );
}

Widget _history() {
  return ListView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    children: [
      for (var i = 0; i < _rows.length; i++) ...[
        if (i == 0 || !sameDay(parseDate(_rows[i]['createdAt']), parseDate(_rows[i - 1]['createdAt'])))
          TransactionDayHeader(parseDate(_rows[i]['createdAt']))
        else
          Divider(height: 1, color: DP.borderSoft),
        TransactionRow(tx: _rows[i], detailed: true),
      ],
    ],
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
    testWidgets('home${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'home', _home(), dark: dark);
    });
    testWidgets('history${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'history', _history(), dark: dark);
    });
  }

  testWidgets('tablet frame', (tester) async {
    tester.view.physicalSize = const Size(1024, 768) * 1.5;
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    DP.isDark = false;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', scaffoldBackgroundColor: DP.bg),
      builder: (context, child) => DPResponsiveFrame(child: child!),
      home: Scaffold(backgroundColor: DP.bg, body: SafeArea(child: _home())),
    ));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/tablet.png'));
  });

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
