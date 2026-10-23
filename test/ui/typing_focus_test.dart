// Typing into the login and sign-up fields must keep the keyboard on the
// same field after every letter (no rebuild may replace the field).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/core/theme/theme_controller.dart';
import 'package:dalabapay/presentation/screens/auth/login_screen.dart';
import 'package:dalabapay/presentation/screens/auth/register_screen.dart';
import 'package:dalabapay/ui/ui.dart';

Future<void> _typeLetterByLetter(WidgetTester tester, Widget screen, String text) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => ThemeRefresher(child: DPResponsiveFrame(child: child!)),
    home: screen,
  ));
  await tester.pump(const Duration(seconds: 1));

  final field = find.byType(EditableText).first;
  await tester.tap(field);
  await tester.pump();
  // The keyboard opens: the screen gets shorter.
  tester.view.viewInsets = const FakeViewPadding(bottom: 900);
  await tester.pump(const Duration(milliseconds: 300));

  final state = tester.state<EditableTextState>(field);
  expect(state.widget.focusNode.hasFocus, isTrue, reason: 'focused after opening the keyboard');

  var typed = '';
  for (final ch in text.split('')) {
    typed += ch;
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: typed,
      selection: TextSelection.collapsed(offset: typed.length),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final now = tester.state<EditableTextState>(find.byType(EditableText).first);
    expect(identical(now, state), isTrue, reason: 'field was rebuilt after "$typed"');
    expect(now.widget.focusNode.hasFocus, isTrue, reason: 'focus lost after "$typed"');
    expect(now.textEditingValue.text, typed);
  }
}

void main() {
  testWidgets('login: typing keeps focus', (tester) async {
    await _typeLetterByLetter(tester, const LoginScreen(), 'alusine@gmail.com');
  });

  testWidgets('sign-up: typing keeps focus', (tester) async {
    await _typeLetterByLetter(tester, const RegisterScreen(), 'Fatmata Kamara');
  });
}
