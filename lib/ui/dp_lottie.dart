// lib/ui/dp_lottie.dart
// Lottie animations in the Dalabapay colours (assets/animations/).
//
// Every animation has a [fallback]: it shows if the file can't be loaded
// and whenever the system asks for reduced motion, so no screen ever
// depends on an animation. To use an animation from LottieFiles instead,
// replace the JSON file with the same name.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'dp_motion.dart';

class DPLottie extends StatelessWidget {
  /// File name in assets/animations/ without ".json".
  final String name;
  final double? width;
  final double? height;
  final bool repeat;
  final Widget fallback;
  final String? semanticLabel;

  const DPLottie(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.repeat = true,
    this.fallback = const SizedBox.shrink(),
    this.semanticLabel,
  });

  /// Green tick that pops and draws itself (payment success). Plays once.
  static const String success = 'success';

  /// Confetti burst over a successful payment. Plays once.
  static const String celebrate = 'celebrate';

  /// Three bouncing brand dots. Loops.
  static const String loading = 'loading';

  /// Floating receipt card for empty lists. Loops.
  static const String empty = 'empty';

  @override
  Widget build(BuildContext context) {
    if (DPMotion.reduced(context)) return fallback;
    final anim = Lottie.asset(
      'assets/animations/$name.json',
      width: width,
      height: height,
      repeat: repeat,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => fallback,
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: anim)
        : Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: anim));
  }
}
