// lib/ui/dp_responsive.dart
// Keeps the app readable on every screen size.
//
// Phones use the full width. On tablets, desktop and the web the app is
// centred in a column (phone-like for customer screens, wider for the
// admin console) over a soft brand backdrop, so nothing stretches edge to
// edge. Text scaling from system settings is honoured but capped so very
// large sizes can't break layouts.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dp_tokens.dart';

/// Width breakpoints (logical pixels).
class DPBreakpoints {
  DPBreakpoints._();
  static const double medium = 600; // large phones in landscape, tablets
  static const double expanded = 1024; // desktop, large tablets landscape

  /// Widest the customer screens get.
  static const double appMaxWidth = 560;

  /// Widest the admin console gets.
  static const double adminMaxWidth = 1200;
}

/// Layout helpers for widgets that adapt inside the frame.
class DPLayout {
  DPLayout._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMedium(BuildContext context) =>
      width(context) >= DPBreakpoints.medium;

  static bool isExpanded(BuildContext context) =>
      width(context) >= DPBreakpoints.expanded;

  /// Grid columns for tiles: [phone] on phones, more on wider frames.
  static int columns(BuildContext context, {int phone = 3}) {
    final w = width(context);
    if (w >= DPBreakpoints.expanded) return phone + 3;
    if (w >= DPBreakpoints.medium) return phone + 1;
    if (w < 340) return (phone - 1).clamp(2, phone);
    return phone;
  }

  /// Horizontal page padding that grows a little on wider frames.
  static double gutter(BuildContext context) =>
      width(context) >= DPBreakpoints.medium ? 28 : 20;
}

/// Remembers the name of the screen on top so the frame can give the
/// admin console more room. Add [DPRouteWatcher.instance] to
/// `MaterialApp.navigatorObservers`.
class DPRouteWatcher extends NavigatorObserver {
  DPRouteWatcher._();
  static final DPRouteWatcher instance = DPRouteWatcher._();

  final ValueNotifier<String?> current = ValueNotifier<String?>(null);

  void _show(Route<dynamic>? route) {
    // Dialogs and sheets are routes too; only full pages count.
    if (route is! PageRoute) return;
    final name = route.settings.name;
    // Navigator callbacks can run during a build; update afterwards.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (current.value != name) current.value = name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _show(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _show(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);
}

/// Wraps the whole app (in `MaterialApp.builder`).
class DPResponsiveFrame extends StatelessWidget {
  final Widget child;
  const DPResponsiveFrame({super.key, required this.child});

  /// Largest text scale we allow. System settings above this are capped so
  /// layouts stay intact; everything up to it is honoured.
  static const double maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final textScaler =
        mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: maxTextScale);

    return ValueListenableBuilder<String?>(
      valueListenable: DPRouteWatcher.instance.current,
      builder: (context, route, _) {
        final admin = route != null && route.startsWith('/admin');
        final limit =
            admin ? DPBreakpoints.adminMaxWidth : DPBreakpoints.appMaxWidth;
        final framed = mq.size.width > limit + 48;
        final width = framed ? limit : mq.size.width;

        // The widget tree keeps the same shape whether or not the app is
        // framed, so resizing a window never resets the screens.
        return DecoratedBox(
          decoration: BoxDecoration(
            color: DP.bg,
            gradient: framed
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: DP.isDark
                        ? const [Color(0xFF070D18), Color(0xFF0E1A33)]
                        : const [Color(0xFFEFF3FA), Color(0xFFE3ECFB)],
                  )
                : null,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: DP.bg,
                boxShadow: framed ? DP.shadowLg : const [],
              ),
              child: MediaQuery(
                data: mq.copyWith(
                  textScaler: textScaler,
                  size: Size(width, mq.size.height),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
