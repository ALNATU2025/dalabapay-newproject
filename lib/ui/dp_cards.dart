// lib/ui/dp_cards.dart
// Hero cards for Home and Wallet: the balance card with its quick actions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dp_motion.dart';
import 'dp_tokens.dart';

/// One round action on the balance card ("Add Money", "Send"…).
class DPQuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const DPQuickAction(this.icon, this.label, this.onTap);
}

/// Gradient wallet card: balance (hide/show), earnings link and a row of
/// quick actions. Pass [gradient] for the green Wallet variant.
class DPBalanceCard extends StatelessWidget {
  final String label;
  final double balance;
  final double? earnings;
  final bool visible;
  final VoidCallback onToggleVisible;
  final VoidCallback? onEarnings;
  final List<DPQuickAction> actions;
  final Gradient gradient;
  final Color glowColor;

  const DPBalanceCard({
    super.key,
    this.label = 'Wallet Balance',
    required this.balance,
    required this.visible,
    required this.onToggleVisible,
    this.earnings,
    this.onEarnings,
    this.actions = const [],
    this.gradient = DP.navyGradient,
    this.glowColor = DP.navy,
  });

  static const TextStyle _amount = TextStyle(
    color: Colors.white,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(DP.rXxl),
        boxShadow: DP.glow(glowColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DP.rXxl),
        child: CustomPaint(
          painter: _CardRingsPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DP.rPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(DPIcons.shieldCheck, size: 13, color: Color(0xFF7FE3BC)),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: visible ? 'Hide balance' : 'Show balance',
                      child: InkResponse(
                        radius: 22,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onToggleVisible();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: DPMotion.fast,
                            child: Icon(
                              visible ? DPIcons.eye : DPIcons.eyeOff,
                              key: ValueKey(visible),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                            .animate(a),
                        child: child,
                      ),
                    ),
                    child: Align(
                      key: ValueKey('bal_$visible'),
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: visible
                            ? Semantics(
                                label: 'Balance ${DP.naira(balance)}',
                                child: ExcludeSemantics(
                                  child: DPCountUp(
                                    value: balance,
                                    format: (v) => DP.naira(v),
                                    style: _amount,
                                  ),
                                ),
                              )
                            : Semantics(
                                label: 'Balance hidden',
                                child: const ExcludeSemantics(
                                  child: Text('₦ • • • • • •', style: _amount),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (earnings != null) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    button: onEarnings != null,
                    child: GestureDetector(
                      onTap: onEarnings,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7FE3BC).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(DP.rPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(DPIcons.sparkle, size: 13, color: Color(0xFF7FE3BC)),
                            const SizedBox(width: 6),
                            Text(
                              'Earnings ${visible ? DP.naira(earnings) : '₦ ••••'}',
                              style: const TextStyle(
                                color: Color(0xFF9DF0CF),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (onEarnings != null)
                              const Icon(DPIcons.chevronRight, size: 16, color: Color(0xFF9DF0CF)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(DP.rXl),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Row(
                      children: [
                        for (final a in actions)
                          Expanded(child: _QuickActionButton(action: a)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final DPQuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: DPPressable(
        pressedScale: 0.92,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
          borderRadius: BorderRadius.circular(DP.rLg),
          onTap: () {
            HapticFeedback.lightImpact();
            action.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, size: 20, color: DP.navy),
                ),
                const SizedBox(height: 7),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Soft concentric rings in the top-right corner of the balance card.
class _CardRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width + 10, -20);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.07);
    for (final r in [70.0, 110.0, 150.0, 190.0]) {
      canvas.drawCircle(c, r, ring);
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF35C08E).withValues(alpha: 0.28),
          const Color(0x0035C08E),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 1.05), radius: 160));
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 1.05), 160, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
