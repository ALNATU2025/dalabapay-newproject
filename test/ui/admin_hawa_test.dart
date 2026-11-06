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
    HawaMessage('user', 'How many accounts are waiting for approval?'),
    HawaMessage('assistant', 'There are **7 new accounts** waiting: 4 in Nigeria and 3 in Sierra Leone.',
        tools: ['approvals_summary', 'accounts_to_approve']),
  ];

  for (final dark in [false, true]) {
    testWidgets('Hawa conversation${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'admin_hawa', () => const AdminHawaPage(initialMessages: convo, configured: true),
          size: const Size(390, 1000), dark: dark);
      expect(find.text('Ask Hawa'), findsOneWidget);
      expect(find.text('Transaction details'), findsOneWidget);
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.textContaining('meter number is invalid', findRichText: true), findsOneWidget);
    });
  }

  testWidgets('Hawa not set up yet, with suggestions', (tester) async {
    await snap(tester, 'admin_hawa_setup', () => const AdminHawaPage(configured: false), size: const Size(390, 900));
    expect(find.textContaining('ANTHROPIC_API_KEY'), findsOneWidget);
    expect(find.text('Who is waiting for approval?'), findsOneWidget);
  });
}
