// Helpers for the design-system screenshot tests (test/ui/).
//
// Real fonts are loaded from the Flutter SDK so the screenshots show text
// instead of test boxes. Screenshots are written with --update-goldens and
// uploaded by CI so the design can be reviewed without a device.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/ui/ui.dart';

Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String f) async {
    final bytes = await File('$dir/$f').readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    if (File('$dir/$f').existsSync()) roboto.addFont(read(f));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  if (File('$dir/MaterialIcons-Regular.otf').existsSync()) {
    icons.addFont(read('MaterialIcons-Regular.otf'));
  }
  await icons.load();
}

/// Wraps [child] in an app shell for a phone-sized screenshot.
Widget shell(Widget child, {bool dark = false}) {
  DP.isDark = dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Roboto',
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: DP.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DP.green,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    ),
    home: Scaffold(backgroundColor: DP.bg, body: child),
  );
}

/// Pumps [widget] at phone size, lets animations run, and saves a PNG.
Future<void> snap(
  WidgetTester tester,
  String name,
  Widget widget, {
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(shell(widget, dark: dark));
  // Let entrance animations finish (repeating ones never settle).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('screenshots/$name${dark ? '_dark' : ''}.png'),
  );
}
