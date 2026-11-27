// lib/presentation/screens/sierra_leone/sl_welcome_popup.dart
// The "Kushe!" welcome pop-up Sierra Leone customers see once after logging
// in: a photo, the greeting, "Pay bills and earn rewards instantly", and a
// button straight to bills. Returns true when "Pay bills now" is tapped.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

const _gold = Color(0xFFF5C451);
const _goldDeep = Color(0xFFE09A1E);
const _ink = Color(0xFF071A33);

Future<bool?> showSlWelcome(BuildContext context, {String firstName = ''}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, __, ___) => SlWelcomePopup(firstName: firstName),
    transitionBuilder: (_, anim, __, child) {
      final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * anim.value, sigmaY: 6 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curve), child: child),
        ),
      );
    },
  );
}

class SlWelcomePopup extends StatelessWidget {
  final String firstName;
  const SlWelcomePopup({super.key, this.firstName = ''});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = (size.width - 40).clamp(260.0, 380.0);
    final name = firstName.trim();
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 40, offset: const Offset(0, 18)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _hero(width, name),
                      _bottom(context),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    key: const ValueKey('sl-welcome-close'),
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.6),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The photo, fading into the greeting.
  Widget _hero(double width, String name) {
    return SizedBox(
      height: width * 0.98,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/sl_welcome.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
            errorBuilder: (_, __, ___) => Container(color: DP.navyDeep),
          ),
          // Soft fade so the text reads on any part of the photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.42, 0.78, 1.0],
                colors: [Color(0x33000000), Color(0x00000000), Color(0xCC071A33), _ink],
              ),
            ),
          ),
          // Brand pill, top left.
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DPFlag('SL', width: 18),
                  SizedBox(width: 6),
                  Text('Dalabapay', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.2)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gold, _goldDeep]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'WELCOME',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 1.6),
                  ),
                ),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFFFE6A8)]).createShader(r),
                  child: Text(
                    name.isEmpty ? 'Kushe!' : 'Kushe, $name!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 40, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                ),
                const SizedBox(height: 6),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(color: Colors.white, fontSize: 18, height: 1.3, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(text: 'Pay bills and earn '),
                      TextSpan(text: 'rewards', style: TextStyle(color: _gold)),
                      TextSpan(text: ' instantly.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    Widget service(IconData icon, String label) => Expanded(
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Icon(icon, color: _gold, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ink, Color(0xFF0B2A4F)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              service(DPIcons.bolt, 'EDSA'),
              service(DPIcons.phone, 'Airtime'),
              service(DPIcons.wifi, 'Data'),
              service(DPIcons.tv, 'TV'),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('sl-welcome-go'),
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gold, _goldDeep]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _goldDeep.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pay bills now', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: _ink, size: 20),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Maybe later', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
