// The "new device" code screen shown when logging in on another phone.
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/auth/device_verify_screen.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  testWidgets('new device: enter the emailed code', (tester) async {
    await snap(
      tester,
      'device_verify',
      () => DeviceVerifyScreen(challenge: 'x' * 40, email: 'fo••••@gmail.com', onVerified: (_) async {}),
    );
    expect(find.text('Confirm it\'s you'), findsOneWidget);
    expect(find.textContaining('fo••••@gmail.com'), findsOneWidget);
    expect(find.text('Verify and log in'), findsOneWidget);
  });
}
