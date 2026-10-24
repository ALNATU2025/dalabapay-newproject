// lib/presentation/screens/payout/payout_onboarding.dart
// First-time introduction to sending money to banks and mobile money.
// Shown once (flag "payout_onboarded"); "Get started" returns true.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../ui/ui.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  final List<Color> colors;
  final List<String> points;
  const _Slide(this.icon, this.title, this.body, this.colors, this.points);
}

const _slides = [
  _Slide(
    DPIcons.globe,
    'Send money across Africa',
    'Pay family, friends and businesses in Sierra Leone, Ghana, Nigeria, Guinea and more — straight from your Leone wallet.',
    [Color(0xFF15368A), Color(0xFF2563EB)],
    ['Pick the country', 'You see the total in Leones', 'They receive their own currency'],
  ),
  _Slide(
    DPIcons.smartphone,
    'Mobile money in seconds',
    'Send to Orange Money and other mobile money wallets. Most transfers arrive within a minute.',
    [Color(0xFFF08A4B), Color(0xFFC2416B)],
    ['Choose the mobile money provider', 'Enter the wallet number', 'We confirm the name when we can'],
  ),
  _Slide(
    DPIcons.bank,
    'Straight to bank accounts',
    'Send to bank accounts in every supported country. Choose the bank and type the account number.',
    [Color(0xFF026C45), Color(0xFF35C08E)],
    ['Choose the bank', 'Enter the account number', 'Check the name, then pay'],
  ),
  _Slide(
    DPIcons.shieldCheck,
    'Safe every time',
    'Every transfer needs your PIN. You see the fees and the rate before you pay, and failed transfers are refunded automatically.',
    [Color(0xFF0B4F6C), Color(0xFF20B2AA)],
    ['PIN on every transfer', 'Fees and rate shown up front', 'Automatic refunds if it fails'],
  ),
];

class PayoutOnboarding extends StatefulWidget {
  const PayoutOnboarding({super.key});

  static const flag = 'payout_onboarded';

  /// Shows the introduction the first time. True when the person goes on.
  static Future<bool> showIfNeeded(BuildContext context) async {
    if (await api.readFlag(flag)) return true;
    if (!context.mounted) return false;
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PayoutOnboarding()),
    );
    return r == true;
  }

  @override
  State<PayoutOnboarding> createState() => _PayoutOnboardingState();
}

class _PayoutOnboardingState extends State<PayoutOnboarding> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await api.setFlag(PayoutOnboarding.flag);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_i == _slides.length - 1) {
      _finish();
    } else {
      _page.nextPage(duration: DPMotion.base, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  const DPWordmark(height: 26),
                  const Spacer(),
                  if (!last) DPTextLink(label: 'Skip', color: DP.muted, onTap: _finish),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i], active: i == _i),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: DPMotion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _i ? DP.green : DP.border,
                      borderRadius: BorderRadius.circular(DP.rPill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: DPButton(label: last ? 'Get started' : 'Next', icon: DPIcons.forward, onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool active;
  const _SlideView({required this.slide, required this.active});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          // Illustration: layered gradient circles with the icon.
          AnimatedScale(
            scale: active ? 1 : 0.85,
            duration: DPMotion.base,
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: slide.colors.last.withValues(alpha: 0.10)),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: slide.colors.last.withValues(alpha: 0.18)),
                  ),
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: slide.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: DP.glow(slide.colors.first),
                    ),
                    child: Icon(slide.icon, color: Colors.white, size: 52),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(slide.title, textAlign: TextAlign.center, style: DP.display.copyWith(fontSize: 26)),
          const SizedBox(height: 10),
          Text(slide.body, textAlign: TextAlign.center, style: DP.body.copyWith(color: DP.muted, height: 1.45)),
          const SizedBox(height: 22),
          for (var k = 0; k < slide.points.length; k++)
            DPAppear(
              delay: DPMotion.stagger(k, stepMs: 90),
              offsetY: 10,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: DP.mint, shape: BoxShape.circle),
                      child: Text('${k + 1}', style: const TextStyle(color: DP.green, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(slide.points[k], style: DP.bodyStrong)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
