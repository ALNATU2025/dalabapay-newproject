// Ask Hawa (admin AI assistant): a conversation, and the "not set up" state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/admin/admin_hawa_page.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  const convo = [
    HawaMessage('assistant', "Hi, I'm Hawa 👋 Ask me anything about Dalabapay.", local: true),
    HawaMessage('user', 'Why did DP-ELEC-20931 fail?'),
    HawaMessage(
      'assistant',
      'That electricity payment for **Foday Sesay** failed because VTpass said the **meter number is invalid**.\n'
          '- Amount: ₦5,000 (Ikeja Electric, prepaid)\n'
          '- Refunded to his wallet at 4:02pm today\n'
          'Ask him to check the meter number and try again.',
      tools: ['search_transactions', 'get_transaction'],
    ),
    HawaMessage('user', 'Any bank top-ups to confirm?'),
    HawaMessage('assistant', 'Yes: **Aminata Kamara** sent **₦25,000** to the Kuda account at 9:42pm and is waiting. Check the Kuda app, then tap Confirm.',
        tools: ['pending_bank_funding', 'approvals_summary'],
        actions: [
          {'type': 'admin_request', 'method': 'POST', 'path': '/api/admin/funding/bank/x/confirm', 'label': 'Confirm ₦25,000.00 top-up', 'summary': 'Credit…'},
          {'type': 'admin_request', 'method': 'POST', 'path': '/api/admin/funding/bank/x/cancel', 'label': 'Cancel top-up', 'summary': 'Cancel…', 'danger': true},
        ]),
  ];

  for (final dark in [false, true]) {
    testWidgets('Hawa conversation${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'admin_hawa', () => const AdminHawaPage(initialMessages: convo, configured: true),
          size: const Size(390, 1000), dark: dark);
      expect(find.text('Ask Hawa'), findsOneWidget);
      expect(find.text('Transaction details'), findsOneWidget);
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('Confirm ₦25,000.00 top-up'), findsOneWidget);
      expect(find.text('Cancel top-up'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.textContaining('meter number is invalid', findRichText: true), findsOneWidget);
    });
  }

  testWidgets('Hawa reads out an alert from a notification', (tester) async {
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: const RouteSettings(arguments: {'speak': 'Payment failed. Foday Sesay\'s electricity payment failed.'}),
        builder: (_) => const AdminHawaPage(configured: true),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('What should I do?'), findsOneWidget);
  });

  testWidgets('Hawa not set up yet, with suggestions', (tester) async {
    await snap(tester, 'admin_hawa_setup', () => const AdminHawaPage(configured: false), size: const Size(390, 900));
    expect(find.textContaining('ANTHROPIC_API_KEY'), findsOneWidget);
    expect(find.text('Who is waiting for approval?'), findsOneWidget);
  });
}
