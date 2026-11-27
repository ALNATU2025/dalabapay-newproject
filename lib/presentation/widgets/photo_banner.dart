// lib/presentation/widgets/photo_banner.dart
// Premium promo banner: a photo on the right that melts into a rich colour
// panel on the left (tag, headline, line of text, call to action), a
// floating glass chip on the photo and a soft light sweep every few
// seconds. With [mobileMoney] the photo is replaced by floating Orange Money
// and Afrimoney cards.
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../screens/sierra_leone/sl_instant_topup.dart' show mobileMoneyLogo;

/// The light sweep and floating logos repeat forever, which widget tests
/// can't wait out: they stay still under `flutter test`.
final bool _animate = kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

class PhotoBanner extends StatefulWidget {
  final String tag;
  final String title;
  final String subtitle;
  final String? cta; // null: no button (an information banner)
  final String? photo; // asset path
  final Alignment photoAlignment;
  final List<Color> colors; // panel gradient, dark → less dark
  final Color accent; // tag, highlight and button
  final String? chip;
  final IconData? chipIcon;
  final bool mobileMoney;
  final VoidCallback? onTap;
  final double height;

  const PhotoBanner({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
    this.cta = 'Get started',
    this.photo,
    this.photoAlignment = Alignment.center,
    this.colors = const [Color(0xFF071A33), Color(0xFF123C73)],
    this.accent = const Color(0xFFF5C451),
    this.chip,
    this.chipIcon,
    this.mobileMoney = false,
    this.onTap,
    this.height = 172,
  });

  @override
  State<PhotoBanner> createState() => _PhotoBannerState();
}

class _PhotoBannerState extends State<PhotoBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  @override
  void initState() {
    super.initState();
    if (_animate) _shine.repeat();
  }

  bool _down = false;

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final base = w.colors.first;
    return Semantics(
      button: w.onTap != null,
      label: '${w.title.replaceAll('\n', ' ')}. ${w.subtitle}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: w.onTap,
        child: AnimatedScale(
          scale: _down ? 0.975 : 1,
          duration: const Duration(milliseconds: 140),
          child: Container(
            height: w.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: base.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: LayoutBuilder(
                builder: (context, c) {
                  final photoW = c.maxWidth * 0.56;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: w.colors),
                        ),
                      ),
                      // Faint rings, top right, for depth.
                      Positioned(right: -40, top: -50, child: _ring(170, w.accent)),
                      Positioned(right: 40, bottom: -70, child: _ring(140, Colors.white)),
                      if (w.photo != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: photoW,
                          child: ShaderMask(
                            // The photo melts into the panel on its left edge.
                            shaderCallback: (r) => const LinearGradient(
                              colors: [Colors.transparent, Colors.black, Colors.black],
                              stops: [0.0, 0.38, 1.0],
                            ).createShader(r),
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              w.photo!,
                              fit: BoxFit.cover,
                              alignment: w.photoAlignment,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      if (w.mobileMoney)
                        Positioned(right: 10, top: 0, bottom: 0, width: photoW - 10, child: _logos()),
                      if (w.chip != null)
                        Positioned(right: 12, top: 12, child: _glassChip(w.chip!, w.chipIcon)),
                      // Copy.
                      Positioned(
                        left: 18,
                        top: 16,
                        bottom: 14,
                        width: c.maxWidth * 0.56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: w.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: w.accent.withValues(alpha: 0.55)),
                              ),
                              child: Text(
                                w.tag.toUpperCase(),
                                style: TextStyle(color: w.accent, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.3),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              w.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.12, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              w.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            if (w.cta != null)
                            Container(
                              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                              decoration: BoxDecoration(color: w.accent, borderRadius: BorderRadius.circular(30)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(w.cta!, style: TextStyle(color: base, fontSize: 12, fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 15, color: base),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Light sweep.
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _shine,
                          builder: (_, __) {
                            final t = _shine.value * 1.6 - 0.3; // mostly off-screen: a sweep, then a pause
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1 + t * 2 - 0.4, -1),
                                  end: Alignment(-1 + t * 2 + 0.4, 1),
                                  colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0)],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.12), width: 14)),
      );

  Widget _glassChip(String text, IconData? icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: widget.accent), const SizedBox(width: 4)],
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  /// Two floating cards with the Orange Money and Afrimoney logos.
  Widget _logos() {
    Widget card(String id, double angle, Offset offset) => Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: mobileMoneyLogo(id, height: 38) ?? const SizedBox.shrink(),
            ),
          ),
        );
    return AnimatedBuilder(
      animation: _shine,
      builder: (_, __) {
        final bob = math.sin(_shine.value * 2 * math.pi) * 3; // gentle float
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [widget.accent.withValues(alpha: 0.35), widget.accent.withValues(alpha: 0)]),
              ),
            ),
            card('m17', -0.10, Offset(-4, -24 + bob)),
            card('m18', 0.08, Offset(8, 26 - bob)),
          ],
        );
      },
    );
  }
}
