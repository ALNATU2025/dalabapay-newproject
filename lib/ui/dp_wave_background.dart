// lib/ui/dp_wave_background.dart
// The splash screen's brand waves — green corner top-right, green + navy
// waves along the bottom — as a reusable background for the entry screens
// (login, onboarding, sign-up, forgot / reset password, OTP).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dp_tokens.dart';
import 'dp_widgets.dart';

class DPWaveBackground extends StatelessWidget {
  final Widget child;

  /// Hide the footer waves (e.g. when the keyboard is open they'd squeeze
  /// the form). Handled automatically; set false to never show them.
  final bool showBottom;

  const DPWaveBackground({
    super.key,
    required this.child,
    this.showBottom = true,
  });

  /// Height of the footer waves for a screen of height [h].
  static double bottomHeight(double h) => math.min(h * 0.13, 120.0);

  /// Height of the top-right corner wave for a screen of height [h].
  static double topHeight(double h) => math.min(h * 0.15, 130.0);

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    return ColoredBox(
      color: DP.surface,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final top = topHeight(h);
          final bottom = bottomHeight(h);
          final footer = showBottom && !keyboardOpen;
          // The list of children never changes shape, and each has a key:
          // hiding the footer while the keyboard is open must not make
          // Flutter rebuild the form underneath (that took the focus away
          // from the field being typed in after every letter).
          return Stack(
            children: [
              Positioned(
                key: const ValueKey('dp-wave-top'),
                top: 0,
                right: 0,
                width: w * 0.62,
                child: DPWaves(top: true, height: top),
              ),
              Positioned(
                key: const ValueKey('dp-wave-footer'),
                left: 0,
                right: 0,
                bottom: 0,
                child: Visibility(
                  visible: footer,
                  maintainState: true,
                  child: DPWaves(height: bottom),
                ),
              ),
              // Content sits above the footer waves so nothing hides behind.
              Positioned.fill(
                key: const ValueKey('dp-wave-content'),
                bottom: footer ? bottom * 0.72 : 0,
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}
