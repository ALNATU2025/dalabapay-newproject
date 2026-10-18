// Smoke test: the app starts on the splash screen without errors.
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/main.dart';

void main() {
  test('every route has a screen', () {
    for (final r in ['/', '/login', '/register', '/dashboard', '/admin']) {
      expect(DalabapayApp.routes.containsKey(r), isTrue, reason: r);
    }
  });
}
