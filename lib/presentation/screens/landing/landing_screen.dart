// lib/presentation/screens/landing/landing_screen.dart
// The website's front page (shown on the web instead of the onboarding
// slides). White page, green and blue type:
//   • hero with a soft moving colour backdrop, a gradient headline and a
//     live phone showing the app's photo banners sliding, with floating
//     "payment done" cards around it
//   • a ticker of networks and services
//   • a slideshow of the photo banners
//   • features, the two countries, three steps, security, the app download
//     card (Google Play) and the footer.
// Full width (see DPResponsiveFrame: '/landing' isn't framed).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/ui.dart';
import '../../widgets/photo_banner.dart';
import '../sierra_leone/sl_instant_topup.dart' show mobileMoneyLogo;

/// The Play Store page for the app (override with --dart-define=PLAY_STORE_URL=…).
const String kPlayStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue: 'https://play.google.com/store/apps/details?id=com.dalabapay.official',
);

Future<void> openPlayStore(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(kPlayStoreUrl), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) dpSnack(context, 'Couldn\'t open Google Play.', error: true);
}

// Page colours: white, with blue and green type.
const _blue = Color(0xFF15368A);
const _blueBright = Color(0xFF2563EB);
const _ink = Color(0xFF0E2766); // headings
const _body = Color(0xFF3A5180); // body text (a soft blue)
const _green = Color(0xFF079A68);
const _greenBright = Color(0xFF10B981);
const _line = Color(0xFFE6ECF5);

const _brandGradient = LinearGradient(colors: [_green, _blueBright]);

/// The photo banners used on the dashboards.
List<Widget> _banners() => const [
      PhotoBanner(
        tag: 'Cable TV',
        title: 'Never miss\nyour shows',
        subtitle: 'DStv, GOtv & StarTimes, renewed in seconds.',
        cta: 'Renew now',
        photo: 'assets/images/banner_tv.jpg',
        photoAlignment: Alignment(0.3, 0),
        accent: Color(0xFF5CC8FF),
        chip: 'Instant',
        chipIcon: Icons.play_arrow_rounded,
      ),
      PhotoBanner(
        tag: 'International airtime',
        title: 'Call home,\nwherever home is',
        subtitle: 'Top up phones in Nigeria, Ghana, the UK and more.',
        cta: 'Top up abroad',
        photo: 'assets/images/banner_call.jpg',
        photoAlignment: Alignment(0, -0.45),
        colors: [Color(0xFF032A1F), Color(0xFF07734F)],
        accent: Color(0xFF6EE7B7),
        chip: '150+ countries',
        chipIcon: Icons.public_rounded,
      ),
      PhotoBanner(
        tag: 'Add money',
        title: 'Top up in\nseconds',
        subtitle: 'Dial a code, approve with your PIN. Done.',
        cta: 'Add money',
        mobileMoney: true,
        colors: [Color(0xFF2B1204), Color(0xFFB4530F)],
        accent: Color(0xFFFFB25B),
      ),
      PhotoBanner(
        tag: 'Withdraw',
        title: 'Cash out\nin a minute',
        subtitle: 'Straight to your Orange Money or Afrimoney.',
        cta: 'Withdraw',
        photo: 'assets/images/banner_wow.jpg',
        photoAlignment: Alignment(0, -0.5),
        colors: [Color(0xFF2A0A2E), Color(0xFF7A1F6E)],
        accent: Color(0xFFF0ABFC),
        chip: 'Instant',
        chipIcon: Icons.bolt_rounded,
      ),
    ];

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 900;
    final pad = w >= 600 ? 40.0 : 20.0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(wide: wide, pad: pad),
            const _Ticker(),
            _Section(
              pad: pad,
              eyebrow: 'See it in action',
              title: 'Everything you pay for, beautifully simple',
              child: _Showcase(wide: wide),
            ),
            _Section(
              pad: pad,
              eyebrow: 'Everything in one wallet',
              title: 'Pay, top up and send — in seconds',
              tint: true,
              child: _Features(wide: w >= 700),
            ),
            _Section(
              pad: pad,
              eyebrow: 'Two countries, one app',
              title: 'Made for Nigeria and Sierra Leone',
              child: _Countries(wide: wide),
            ),
            _Section(
              pad: pad,
              eyebrow: 'How it works',
              title: 'Start in three steps',
              tint: true,
              child: _Steps(wide: wide),
            ),
            _Section(
              pad: pad,
              eyebrow: 'Safe by design',
              title: 'Your money, protected',
              child: _Security(wide: w >= 700),
            ),
            _DownloadBand(pad: pad, wide: wide),
            _Footer(pad: pad),
          ],
        ),
      ),
    );
  }
}

// ── Motion helper ───────────────────────────────────────────

/// Gives its builder a value that loops 0 → 1 forever (still in tests).
class _Loop extends StatefulWidget {
  final Duration period;
  final Widget Function(BuildContext context, double t) builder;
  const _Loop({required this.period, required this.builder});

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (kLoopAnimations) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
}

/// Text painted with the green → blue brand gradient.
class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign align;
  const _GradientText(this.text, {required this.style, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(colors: [_green, _blueBright, _blue]).createShader(r),
        child: Text(text, textAlign: align, style: style.copyWith(color: Colors.white)),
      );
}

// ── Hero ────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final bool wide;
  final double pad;
  const _Hero({required this.wide, required this.pad});

  @override
  Widget build(BuildContext context) {
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = wide ? TextAlign.start : TextAlign.center;
    final text = Column(
      crossAxisAlignment: align,
      children: [
        DPAppear(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(DP.rPill),
              border: Border.all(color: const Color(0xFFD6E4FF)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DPFlag('NG', width: 18),
                SizedBox(width: 6),
                DPFlag('SL', width: 18),
                SizedBox(width: 8),
                Text('Nigeria · Sierra Leone', style: TextStyle(color: _blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        DPAppear(
          delay: const Duration(milliseconds: 80),
          child: _GradientText(
            'Pay bills, add money\nand send money — fast.',
            align: textAlign,
            style: TextStyle(fontSize: wide ? 56 : 36, height: 1.06, fontWeight: FontWeight.w900, letterSpacing: -1.4),
          ),
        ),
        const SizedBox(height: 18),
        DPAppear(
          delay: const Duration(milliseconds: 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Airtime, data, electricity and TV in seconds. Add money instantly with your bank, Orange Money or Afrimoney. '
              'Send money to banks and mobile money. Use the website or the app — same account.',
              textAlign: textAlign,
              style: TextStyle(color: _body, fontSize: wide ? 18 : 16, height: 1.55),
            ),
          ),
        ),
        const SizedBox(height: 30),
        DPAppear(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            children: [
              _PillButton(
                label: 'Create free account',
                icon: DPIcons.forward,
                gradient: _brandGradient,
                onTap: () => Navigator.pushNamed(context, '/register'),
              ),
              _PillButton(
                label: 'Log in',
                outlined: true,
                onTap: () => Navigator.pushNamed(context, '/login'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        DPAppear(
          delay: const Duration(milliseconds: 320),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PlayStoreBadge(),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  'Prefer the app?\nGet it on your Android phone.',
                  style: TextStyle(color: _body.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Stack(
      children: [
        // Soft moving colour blobs behind everything.
        const Positioned.fill(child: _Aurora()),
        SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 18, pad, wide ? 70 : 44),
                child: Column(
                  children: [
                    const _TopBar(),
                    SizedBox(height: wide ? 56 : 34),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 6, child: text),
                          const SizedBox(width: 30),
                          const Expanded(flex: 5, child: Center(child: _PhoneShowcase(scale: 1))),
                        ],
                      )
                    else ...[
                      text,
                      const SizedBox(height: 40),
                      const _PhoneShowcase(scale: 0.86),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DPWordmark(height: 30, light: false),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: TextButton.styleFrom(foregroundColor: _blue),
          child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (MediaQuery.sizeOf(context).width >= 520) ...[
          const SizedBox(width: 6),
          _PillButton(
            label: 'Sign up',
            small: true,
            gradient: _brandGradient,
            onTap: () => Navigator.pushNamed(context, '/register'),
          ),
        ],
      ],
    );
  }
}

/// Blurred green and blue light, drifting slowly.
class _Aurora extends StatelessWidget {
  const _Aurora();

  @override
  Widget build(BuildContext context) {
    Widget blob(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0)]),
          ),
        );
    return IgnorePointer(
      child: ClipRect(
        child: _Loop(
          period: const Duration(seconds: 18),
          builder: (context, t) {
            final a = t * 2 * math.pi;
            return LayoutBuilder(builder: (context, c) {
              return Stack(
                children: [
                  Positioned(left: -120 + math.sin(a) * 40, top: -140 + math.cos(a) * 30, child: blob(_greenBright, 520)),
                  Positioned(right: -160 + math.cos(a) * 50, top: 40 + math.sin(a) * 40, child: blob(_blueBright, 600)),
                  Positioned(left: c.maxWidth * 0.35 + math.sin(a + 1.5) * 60, bottom: -220, child: blob(_green, 460)),
                  // A faint dot grid for texture.
                  Positioned.fill(child: CustomPaint(painter: _DotsPainter())),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _blue.withValues(alpha: 0.05);
    for (var x = 12.0; x < size.width; x += 26) {
      for (var y = 12.0; y < size.height; y += 26) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A phone running the app: balance, the photo banners sliding, services;
/// with "done" cards floating around it.
class _PhoneShowcase extends StatelessWidget {
  final double scale;
  const _PhoneShowcase({required this.scale});

  @override
  Widget build(BuildContext context) {
    const phoneW = 300.0;
    const phoneH = 600.0;
    return SizedBox(
      width: 470 * scale,
      height: 640 * scale,
      child: FittedBox(
        child: SizedBox(
          width: 470,
          height: 640,
          child: _Loop(
            period: const Duration(seconds: 6),
            builder: (context, t) {
              final bob = math.sin(t * 2 * math.pi);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Glow under the phone.
                  Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [_greenBright.withValues(alpha: 0.28), _blueBright.withValues(alpha: 0.10), Colors.transparent]),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, bob * 6),
                    child: Transform.rotate(angle: -0.035, child: const _Phone(width: phoneW, height: phoneH)),
                  ),
                  Positioned(
                    left: 0,
                    top: 110 + bob * 10,
                    child: const _FloatCard(
                      icon: Icons.bolt_rounded,
                      iconColor: Color(0xFFF59E0B),
                      title: 'EDSA token ready',
                      subtitle: '4521 8890 1123 · 20 kWh',
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 270 - bob * 10,
                    child: _FloatCard(
                      leading: mobileMoneyLogo('m18', height: 22),
                      title: 'Le 100 received',
                      subtitle: 'From Afrimoney · just now',
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 70 + bob * 8,
                    child: const _FloatCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: _green,
                      title: 'DStv renewed',
                      subtitle: 'Compact · 1 month',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  final double width;
  final double height;
  const _Phone({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(46),
        boxShadow: [
          BoxShadow(color: _blue.withValues(alpha: 0.30), blurRadius: 60, offset: const Offset(0, 30)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(37),
        child: ColoredBox(
          color: const Color(0xFFF6F8FC),
          child: Column(
            children: [
              // Status bar with the camera notch.
              SizedBox(
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: 90, height: 22, decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(12))),
                    const Positioned(left: 22, child: Text('9:41', style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w800))),
                    const Positioned(right: 20, child: Icon(Icons.battery_full_rounded, size: 16, color: _ink)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kushe, Fatmata!', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
                          Text('Good morning', style: TextStyle(color: _body, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _brandGradient),
                      child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Balance card.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF15368A), Color(0xFF0E2766)]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5)),
                    const SizedBox(height: 4),
                    const Text('Le 1,250.50', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final a in const [(Icons.add_rounded, 'Add'), (Icons.north_east_rounded, 'Send'), (Icons.south_west_rounded, 'Withdraw'), (Icons.history_rounded, 'History')])
                          Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(a.$1, size: 17, color: _blue),
                              ),
                              const SizedBox(height: 4),
                              Text(a.$2, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // The photo banners, sliding.
              const SizedBox(height: 136, child: _MiniSlides()),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    for (final s in const [
                      (DPAssets.svcAirtime, 'Airtime'),
                      (DPAssets.svcData, 'Data'),
                      (DPAssets.svcElectricity, 'EDSA'),
                      (DPAssets.svcTv, 'TV'),
                    ])
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
                              child: DPImage(s.$1, fallback: const Icon(DPIcons.wallet, color: _blue, size: 18)),
                            ),
                            const SizedBox(height: 4),
                            Text(s.$2, style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashboard banners inside the phone, sliding every few seconds.
class _MiniSlides extends StatefulWidget {
  const _MiniSlides();

  @override
  State<_MiniSlides> createState() => _MiniSlidesState();
}

class _MiniSlidesState extends State<_MiniSlides> {
  final _page = PageController(viewportFraction: 0.92);
  Timer? _timer;
  final _items = _banners();

  @override
  void initState() {
    super.initState();
    if (kLoopAnimations) {
      _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (!mounted || !_page.hasClients) return;
        final next = ((_page.page ?? 0).round() + 1) % _items.length;
        _page.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _page,
      itemCount: _items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // Banners are designed ~340 wide: scale them down to fit.
        child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: 340, height: 172, child: _items[i])),
      ),
    );
  }
}

class _FloatCard extends StatelessWidget {
  final IconData? icon;
  final Color iconColor;
  final Widget? leading;
  final String title;
  final String subtitle;
  const _FloatCard({this.icon, this.iconColor = _green, this.leading, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.16), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading ??
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: _body, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ticker ──────────────────────────────────────────────────

/// Networks and services, scrolling past forever.
class _Ticker extends StatelessWidget {
  const _Ticker();

  static const _items = [
    'MTN', 'Airtel', 'Glo', '9mobile', 'Orange', 'Africell', 'Qcell', 'DStv', 'GOtv', 'StarTimes', 'EDSA', //
    'Ikeja Electric', 'Eko Electric', 'Abuja Electric', 'Orange Money', 'Afrimoney', 'Banks',
  ];
  static const _itemW = 150.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    const span = (_itemW + _gap) * 17; // one full set
    Widget chip(String s) {
      final logo = s == 'Orange Money' || s == 'Afrimoney' ? mobileMoneyLogo(s, height: 24) : null;
      return Container(
        width: _itemW,
        height: 46,
        margin: const EdgeInsets.only(right: _gap),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x0D15368A), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: logo ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _brandGradient)),
                const SizedBox(width: 8),
                Text(s, style: const TextStyle(color: _blue, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        border: Border.symmetric(horizontal: BorderSide(color: _line)),
      ),
      child: Column(
        children: [
          const Text('PAY FOR ALL THE NAMES YOU USE',
              style: TextStyle(color: _green, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ShaderMask(
              // Fade at both ends.
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.08, 0.92, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: ClipRect(
                child: _Loop(
                  period: const Duration(seconds: 40),
                  builder: (context, t) => OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    child: Transform.translate(
                      offset: Offset(-span * t, 0),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < 3; k++) ..._items.map(chip)]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sections ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final double pad;
  final String eyebrow;
  final String title;
  final Widget child;
  final bool tint;
  const _Section({required this.pad, required this.eyebrow, required this.title, required this.child, this.tint = false});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: tint
            ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFF5F9FF), Colors.white])
            : null,
        color: tint ? null : Colors.white,
      ),
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: wide ? 76 : 50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFE9F8F1), borderRadius: BorderRadius.circular(DP.rPill)),
                child: Text(eyebrow.toUpperCase(),
                    style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink, fontSize: wide ? 38 : 27, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.12),
              ),
              const SizedBox(height: 14),
              Container(width: 64, height: 4, decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: wide ? 44 : 30),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo banners as a big slideshow (two at a time on wide screens).
class _Showcase extends StatefulWidget {
  final bool wide;
  const _Showcase({required this.wide});

  @override
  State<_Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<_Showcase> {
  late PageController _page = PageController(viewportFraction: widget.wide ? 0.5 : 0.92);
  Timer? _timer;
  int _index = 0;
  final _items = _banners();

  @override
  void initState() {
    super.initState();
    if (kLoopAnimations) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_page.hasClients) return;
        final last = widget.wide ? _items.length - 2 : _items.length - 1;
        final next = _index >= last ? 0 : _index + 1;
        _page.animateToPage(next, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _Showcase old) {
    super.didUpdateWidget(old);
    if (old.wide != widget.wide) {
      _page.dispose();
      _page = PageController(viewportFraction: widget.wide ? 0.5 : 0.92);
      _index = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _go(int d) {
    final last = widget.wide ? _items.length - 2 : _items.length - 1;
    final next = (_index + d).clamp(0, last);
    _page.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.wide ? 250.0 : 196.0;
    Widget arrow(IconData i, int d) => Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: _line)),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _go(d),
            child: Padding(padding: const EdgeInsets.all(10), child: Icon(i, color: _blue, size: 20)),
          ),
        );
    return Column(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _page,
            padEnds: !widget.wide,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
              child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: 340, height: 172, child: _items[i])),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.wide) ...[arrow(Icons.arrow_back_rounded, -1), const SizedBox(width: 16)],
            ...List.generate(_items.length, (i) {
              final on = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: on ? _brandGradient : null,
                  color: on ? null : _line,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
            if (widget.wide) ...[const SizedBox(width: 16), arrow(Icons.arrow_forward_rounded, 1)],
          ],
        ),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  final bool wide;
  const _Features({required this.wide});

  static const _items = [
    (DPAssets.svcAirtime, 'Airtime & data', 'MTN, Airtel, Glo, 9mobile, Orange, Africell and more — delivered instantly.'),
    (DPAssets.svcElectricity, 'Electricity', 'Prepaid and postpaid meters, EDSA too. Your token arrives in seconds.'),
    (DPAssets.svcTv, 'Cable TV', 'Renew or change DStv, GOtv and StarTimes without leaving home.'),
    (DPAssets.svcAddMoney, 'Add money', 'Bank transfer to your own account number, or Orange Money and Afrimoney in Sierra Leone.'),
    (DPAssets.svcSendMoney, 'Send & withdraw', 'Send to banks and mobile money, or cash out to your own Orange Money or Afrimoney.'),
    (DPAssets.svcInternational, 'International airtime', 'Top up phones abroad from your wallet.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width >= 1000 ? 3 : (wide ? 2 : 1);
    return LayoutBuilder(builder: (context, c) {
      const gap = 18.0;
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < _items.length; i++)
            SizedBox(
              width: cardW,
              child: _HoverCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: i.isEven ? const [Color(0xFFE9F8F1), Color(0xFFDDF3EA)] : const [Color(0xFFEFF4FF), Color(0xFFE1EAFF)],
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: DPImage(_items[i].$1, fallback: const Icon(DPIcons.wallet, color: _blue)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_items[i].$2, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(_items[i].$3, style: const TextStyle(color: _body, fontSize: 14, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Countries extends StatelessWidget {
  final bool wide;
  const _Countries({required this.wide});

  @override
  Widget build(BuildContext context) {
    const ng = _CountryCard(
      flag: 'NG',
      name: 'Nigeria',
      currency: 'Naira (₦)',
      accent: _green,
      points: ['Airtime, data, electricity, TV, education', 'Own account number to add money', 'Instant receipts you can download'],
    );
    const sl = _CountryCard(
      flag: 'SL',
      name: 'Sierra Leone',
      currency: 'Leones (Le)',
      accent: _blueBright,
      points: ['Orange, Africell and Qcell airtime & data', 'EDSA tokens and TV subscriptions', 'Add money and withdraw with Orange Money and Afrimoney'],
    );
    return wide
        ? const IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: ng), SizedBox(width: 18), Expanded(child: sl)]),
          )
        : const Column(children: [ng, SizedBox(height: 18), sl]);
  }
}

class _CountryCard extends StatelessWidget {
  final String flag;
  final String name;
  final String currency;
  final Color accent;
  final List<String> points;
  const _CountryCard({required this.flag, required this.name, required this.currency, required this.accent, required this.points});

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      topAccent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DPFlag(flag, width: 34),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: const TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(DP.rPill)),
                child: Text(currency, style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p, style: const TextStyle(color: _body, fontSize: 15, height: 1.35))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  final bool wide;
  const _Steps({required this.wide});

  static const _steps = [
    ('1', 'Create your account', 'Sign up with your phone number and email in a minute.'),
    ('2', 'Add money', 'Bank transfer, or Orange Money and Afrimoney in Sierra Leone.'),
    ('3', 'Pay and send', 'Buy airtime, pay bills or send money — with a receipt every time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final s in _steps)
        _HoverCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Text(s.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              const SizedBox(height: 16),
              Text(s.$2, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(s.$3, style: const TextStyle(color: _body, fontSize: 14, height: 1.45)),
            ],
          ),
        ),
    ];
    if (!wide) {
      return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 18),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _Security extends StatelessWidget {
  final bool wide;
  const _Security({required this.wide});

  static const _points = [
    (Icons.lock_rounded, 'PIN on every payment', 'Nothing leaves your wallet without your PIN.'),
    (Icons.phonelink_lock_rounded, 'New-device alerts', 'We tell you the moment someone signs in.'),
    (Icons.receipt_long_rounded, 'Receipts for everything', 'Every payment, saved and shareable.'),
    (Icons.support_agent_rounded, 'Real people for support', 'Chat with us any time you need help.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width >= 1000 ? 4 : (wide ? 2 : 1);
    return LayoutBuilder(builder: (context, c) {
      const gap = 18.0;
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < _points.length; i++)
            SizedBox(
              width: cardW,
              child: _HoverCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (i.isEven ? _green : _blueBright).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_points[i].$1, color: i.isEven ? _green : _blueBright, size: 23),
                    ),
                    const SizedBox(height: 14),
                    Text(_points[i].$2, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(_points[i].$3, style: const TextStyle(color: _body, fontSize: 13.5, height: 1.45)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _DownloadBand extends StatelessWidget {
  final double pad;
  final bool wide;
  const _DownloadBand({required this.pad, required this.wide});

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _GradientText(
          'Get the Dalabapay app',
          align: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(fontSize: wide ? 38 : 28, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1),
        ),
        const SizedBox(height: 12),
        Text(
          'Fingerprint login, instant notifications and receipts on your phone. Your website account works in the app.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: const TextStyle(color: _body, fontSize: 16, height: 1.55),
        ),
        const SizedBox(height: 24),
        const PlayStoreBadge(large: true),
      ],
    );
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Image.asset(
            'assets/images/sl_welcome.jpg',
            width: wide ? 340 : double.infinity,
            height: wide ? 340 : 260,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
            errorBuilder: (_, __, ___) => const SizedBox(width: 340, height: 340),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DP.rPill)),
              child: const Text('Kushe! 👋', style: TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          // A gradient border around a white card.
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: _brandGradient,
              borderRadius: BorderRadius.circular(34),
              boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.14), blurRadius: 50, offset: const Offset(0, 24))],
            ),
            child: Container(
              padding: EdgeInsets.all(wide ? 40 : 22),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
              child: wide
                  ? Row(children: [Expanded(child: copy), const SizedBox(width: 36), photo])
                  : Column(children: [photo, const SizedBox(height: 24), copy]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final double pad;
  const _Footer({required this.pad});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _line))),
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 14,
            spacing: 20,
            children: [
              const DPWordmark(height: 24, light: false),
              Wrap(
                spacing: 18,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _blue),
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Log in'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _blue),
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _blue),
                    onPressed: () => Navigator.pushNamed(context, '/help'),
                    child: const Text('Help & support'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _green),
                    onPressed: () => openPlayStore(context),
                    child: const Text('Get the app'),
                  ),
                ],
              ),
              Text('© ${DateTime.now().year} Dalabapay. All rights reserved.', style: const TextStyle(color: _body, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────

/// White card that lifts and glows a little under the mouse.
class _HoverCard extends StatefulWidget {
  final Widget child;
  final Color? topAccent;
  const _HoverCard({required this.child, this.topAccent});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _hover ? const Color(0xFFBFD3F7) : _line),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: _hover ? 0.14 : 0.06),
              blurRadius: _hover ? 36 : 24,
              offset: Offset(0, _hover ? 18 : 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.topAccent != null) Container(height: 4, color: widget.topAccent),
              Padding(padding: const EdgeInsets.all(22), child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;
  final bool small;
  final Gradient? gradient;
  const _PillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.outlined = false,
    this.small = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final h = small ? 40.0 : 54.0;
    final fg = outlined ? _blue : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: outlined ? null : gradient,
        color: outlined ? Colors.white : null,
        borderRadius: BorderRadius.circular(DP.rPill),
        border: outlined ? Border.all(color: _blue.withValues(alpha: 0.35), width: 1.5) : null,
        boxShadow: outlined || small ? null : [BoxShadow(color: _green.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: small ? 18 : 28),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: fg, fontSize: small ? 14 : 16, fontWeight: FontWeight.w800)),
                  if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: fg, size: 18)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Get it on Google Play" button. Put Google's official badge at
/// assets/images/google_play_badge.png to use it instead of the drawn one.
class PlayStoreBadge extends StatelessWidget {
  final bool large;
  const PlayStoreBadge({super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final h = large ? 58.0 : 48.0;
    final drawn = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: large ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA6A6A6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: Colors.white, size: large ? 34 : 28),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GET IT ON', style: TextStyle(color: Colors.white, fontSize: large ? 10.5 : 9.5, letterSpacing: 0.6)),
              Text('Google Play', style: TextStyle(color: Colors.white, fontSize: large ? 20 : 17, fontWeight: FontWeight.w600, height: 1.1)),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: 'Get Dalabapay on Google Play',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => openPlayStore(context),
          child: DPImage('assets/images/google_play_badge.png', height: h, fallback: drawn),
        ),
      ),
    );
  }
}
