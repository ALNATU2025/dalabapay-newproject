// Aminata support chat: the greeting when it opens, and a conversation
// with her buttons.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/help/support_chat_screen.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  testWidgets('Aminata greets by name with suggestions', (tester) async {
    await snap(tester, 'support_chat_hello', () => const SupportChatScreen(available: true, firstName: 'Foday'),
        size: const Size(390, 844));
    expect(find.text('Aminata'), findsOneWidget);
    expect(find.textContaining('Hi Foday', findRichText: true), findsOneWidget);
    expect(find.text('My payment failed'), findsOneWidget);
    expect(find.text('I want to talk to a person'), findsOneWidget);
  });

  const convo = [
    SupportMessage('assistant', "Hi Foday 👋 I'm Aminata, your Dalabapay assistant. How can I help you today?", local: true),
    SupportMessage('user', 'I paid for GOtv but my TV is still not showing'),
    SupportMessage(
      'assistant',
      'I checked your GOtv payment **DP-TV-1001** of ₦4,500 from today at 2:14pm. It was **successful**, so GOtv has received it.\n'
          '- Leave your decoder on for 10–15 minutes\n'
          '- If it still shows an error, tap Submit report and our team will check it with GOtv.',
      actions: [
        {'type': 'report_problem', 'label': 'Submit report', 'transactionId': 'x', 'reference': 'DP-TV-1001', 'reason': 'TV not working'},
        {'type': 'contact_human', 'label': 'Chat with our team on WhatsApp', 'message': 'GOtv not working'},
      ],
    ),
  ];

  for (final dark in [false, true]) {
    testWidgets('Aminata conversation with buttons${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'support_chat', () => const SupportChatScreen(initialMessages: convo, available: true, firstName: 'Foday'),
          size: const Size(390, 900), dark: dark);
      expect(find.text('Submit report'), findsOneWidget);
      expect(find.text('Chat with our team on WhatsApp'), findsOneWidget);
      expect(find.text('My payment failed'), findsNothing); // suggestions only before the first question
    });
  }

  testWidgets('Aminata away: WhatsApp instead', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SupportChatScreen(available: false, firstName: 'Foday')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining("isn't available"), findsOneWidget);
    expect(find.text('Away'), findsOneWidget);
  });
}
