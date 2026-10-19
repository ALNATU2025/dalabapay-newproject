// The Lottie files parse, and each one is captured at a few moments so the
// motion can be reviewed in the CI screenshots.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpAll(loadTestFonts);

  for (final name in [
    DPLottie.success,
    DPLottie.celebrate,
    DPLottie.loading,
    DPLottie.empty,
  ]) {
    testWidgets('$name animation', (tester) async {
      final composition = await tester.runAsync(
        () => AssetLottie('assets/animations/$name.json').load(),
      );
      expect(composition, isNotNull);
      expect(composition!.duration, greaterThan(Duration.zero));

      Widget frame(double t) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Lottie(
                  composition: composition,
                  controller: AlwaysStoppedAnimation(t),
                ),
              ),
              Text('${(t * 100).round()}%', style: DP.caption),
            ],
          );

      await snap(
        tester,
        'anim_$name',
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [for (final t in [0.1, 0.25, 0.4, 0.6, 0.8, 1.0]) frame(t)],
          ),
        ),
        size: const Size(520, 420),
      );
    });
  }
}
