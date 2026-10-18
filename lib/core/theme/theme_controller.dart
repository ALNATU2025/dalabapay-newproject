// lib/core/theme/theme_controller.dart
// Light / Dark / System theme switch (UI only — the choice lasts until the
// app is closed; save it with shared_preferences later if you want).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/dp_tokens.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  /// Whether the app is showing dark colours right now.
  bool get isDark => DP.isDark;

  void setMode(ThemeMode mode) {
    value = mode;
    apply();
  }

  /// Works out light/dark from the mode (and the phone's setting for
  /// "System"), updates the colour tokens and the status bar, then tells
  /// listeners to rebuild.
  void apply() {
    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final dark = switch (value) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformDark,
    };
    final changed = DP.isDark != dark;
    DP.isDark = dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: DP.surface,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
    );
    if (changed) notifyListeners();
  }

  static String label(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Normal',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
}

/// Rebuilds every widget below it when the theme changes, including
/// `const` widgets that Flutter would otherwise skip, so all colours switch
/// at once without losing the current screen.
class ThemeRefresher extends StatefulWidget {
  final Widget child;
  const ThemeRefresher({super.key, required this.child});

  @override
  State<ThemeRefresher> createState() => _ThemeRefresherState();
}

class _ThemeRefresherState extends State<ThemeRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeController.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (ThemeController.instance.value == ThemeMode.system) {
      ThemeController.instance.apply();
    }
  }

  void _refresh() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (!mounted) return;
    (context as Element).visitChildren(mark);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
