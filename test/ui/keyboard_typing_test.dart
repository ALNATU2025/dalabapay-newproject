// Typing in a field on the entry screens (login, sign-up…) must not lose
// focus when the keyboard is open. The wave background used to rebuild the
// form after every letter, closing the keyboard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/ui/ui.dart';

class _Form extends StatefulWidget {
  const _Form();
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    // Like the real screens: rebuild on every keystroke.
    controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => DPWaveBackground(
        child: Center(child: DPField(controller: controller, hint: 'Email')),
      );
}

void main() {
  testWidgets('field keeps focus and state while typing with the keyboard open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Form())));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final before = tester.state<EditableTextState>(find.byType(EditableText));

    // The keyboard appears.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    for (final text in ['a', 'al', 'ali']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    final after = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(before, after), isTrue, reason: 'the field was rebuilt from scratch');
    expect(after.widget.focusNode.hasFocus, isTrue);
    expect(find.text('ali'), findsOneWidget);
  });
}
