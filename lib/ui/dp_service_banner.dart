// lib/ui/dp_service_banner.dart
// The banner at the top of every payment screen ("Pay, renew or activate
// your subscription in seconds"): brand gradient, a floating illustration
// and a soft light sweep. Animations stop when the phone asks for reduced
// motion.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dp_logo.dart';
import 'dp_motion.dart';
import 'dp_tokens.dart';

enum DPBannerStyle { navy, green, sunset, ocean }

class DPServiceBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  /// Optional illustration (assets/images/…); falls back to [icon].
  final String? image;
  final DPBannerStyle style;

  /// Small label above the title, e.g. "Cable TV".
  final String? tag;

  const DPServiceBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.image,
    this.style = DPBannerStyle.navy,
    this.tag,
  });

  static const _gradients = {
    DPBannerStyle.navy: [Color(0xFF15368A), Color(0xFF1F4FC1), Color(0xFF2563EB)],
    DPBannerStyle.green: [Color(0xFF026C45), Color(0xFF079A68), Color(0xFF35C08E)],
    DPBannerStyle.sunset: [Color(0xFF7A2E8E), Color(0xFFC2416B), Color(0xFFF08A4B)],
    DPBannerStyle.ocean: [Color(0xFF0B4F6C), Color(0xFF0E7C86), Color(0xFF20B2AA)],
  };

  @override
  State<DPServiceBanner> createState() => _DPServiceBannerState();
}

class _DPServiceBannerState extends State<DPServiceBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DPServiceBanner._gradients[widget.style]!;
    final art = widget.image == null
        ? Icon(widget.icon, color: Colors.white, size: 44)
        : DPImage(widget.image!, width: 86, height: 86, fallback: Icon(widget.icon, color: Colors.white, size: 44));
    return DPAppear(
      offsetY: 12,
      child: Semantics(
        container: true,
        label: '${widget.title}. ${widget.subtitle}',
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 128),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              borderRadius: BorderRadius.circular(DP.rXl),
              boxShadow: DP.glow(colors.first, strength: 0.7),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DP.rXl),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final t = _c.value;
                  return Stack(
                    children: [
                      // Decorative rings
                      Positioned(
                        right: -40,
                        top: -40,
                        child: _Ring(size: 170, opacity: 0.10),
                      ),
                      Positioned(
                        right: 30,
                        bottom: -60,
                        child: _Ring(size: 120, opacity: 0.08),
                      ),
                      // Light sweep
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Transform.translate(
                            offset: Offset((t * 2 - 0.5) * 420, 0),
                            child: Transform.rotate(
                              angle: 0.35,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                width: 70,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.13),
                                    Colors.white.withValues(alpha: 0),
                                  ]),
                                ),
                              ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child!,
                      // Floating illustration
                      Positioned(
                        right: 14,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(0, math.sin(t * 2 * math.pi) * 5),
                            child: Container(
                              width: 92,
                              height: 92,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                              ),
                              child: art,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 120, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.tag != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(DP.rPill),
                          ),
                          child: Text(
                            widget.tag!.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                          ),
                        ),
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double size;
  final double opacity;
  const _Ring({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 18),
        ),
      );
}
