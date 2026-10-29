// lib/presentation/screens/landing/landing_screen.dart
// The website's front page (shown on the web instead of the onboarding
// slides): what Dalabapay does, the two countries, how it works, and the
// buttons to create an account, log in or get the app on Google Play.
// Full width (see DPResponsiveFrame: '/landing' isn't framed).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/ui.dart';

/// The Play Store page for the app (override with --dart-define=PLAY_STORE_URL=…).
const String kPlayStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue: 'https://play.google.com/store/apps/details?id=com.dalabapay.newproject',
);

Future<void> openPlayStore(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(kPlayStoreUrl), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) dpSnack(context, 'Couldn\'t open Google Play.', error: true);
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _navy = Color(0xFF15368A);
  static const _navyDeep = Color(0xFF0E2766);
  static const _green = Color(0xFF079A68);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 900;
    final pad = w >= 600 ? 40.0 : 20.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(wide: wide, pad: pad),
            _Section(
              pad: pad,
              eyebrow: 'Everything in one wallet',
              title: 'Pay, top up and send — in seconds',
              child: _Features(wide: w >= 700),
            ),
            _Section(
              pad: pad,
              eyebrow: 'Two countries, one app',
              title: 'Made for Nigeria and Sierra Leone',
              background: Colors.white,
              child: _Countries(wide: wide),
            ),
            _Section(
              pad: pad,
              eyebrow: 'How it works',
              title: 'Start in three steps',
              child: _Steps(wide: wide),
            ),
            _Security(pad: pad, wide: wide),
            _DownloadBand(pad: pad, wide: wide),
            _Footer(pad: pad),
          ],
        ),
      ),
    );
  }
}

// ── Hero ────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final bool wide;
  final double pad;
  const _Hero({required this.wide, required this.pad});

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DP.rPill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              DPFlag('NG', width: 18),
              SizedBox(width: 6),
              DPFlag('SL', width: 18),
              SizedBox(width: 8),
              Text('Nigeria · Sierra Leone', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Pay bills, add money\nand send money — fast.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 50 : 34,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Airtime, data, electricity and TV in seconds. Your own account number for adding money. '
            'Send money to banks and mobile money across Africa. Use the website or the app — same account.',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: wide ? 18 : 16, height: 1.5),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _PillButton(
              label: 'Create free account',
              icon: DPIcons.forward,
              background: LandingScreen._green,
              onTap: () => Navigator.pushNamed(context, '/register'),
            ),
            _PillButton(
              label: 'Log in',
              outlined: true,
              onTap: () => Navigator.pushNamed(context, '/login'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlayStoreBadge(),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Prefer the app?\nGet it on your Android phone.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );

    final art = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 440 : 300, maxHeight: wide ? 520 : 340),
      child: DPImage(
        DPAssets.onboarding1,
        fit: BoxFit.contain,
        fallback: const Icon(DPIcons.wallet, color: Colors.white, size: 120),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LandingScreen._navyDeep, LandingScreen._navy, Color(0xFF2450B4)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 18, pad, wide ? 70 : 44),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    children: [
                      const DPWordmark(height: 30, light: true),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 520) ...[
                        const SizedBox(width: 6),
                        _PillButton(
                          label: 'Sign up',
                          small: true,
                          background: Colors.white,
                          foreground: LandingScreen._navy,
                          onTap: () => Navigator.pushNamed(context, '/register'),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: wide ? 60 : 34),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [Expanded(flex: 6, child: text), const SizedBox(width: 30), Expanded(flex: 5, child: Center(child: art))],
                    )
                  else ...[
                    text,
                    const SizedBox(height: 30),
                    art,
                  ],
                ],
              ),
            ),
          ),
        ),
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
  final Color? background;
  const _Section({required this.pad, required this.eyebrow, required this.title, required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Container(
      width: double.infinity,
      color: background,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: wide ? 72 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Text(eyebrow.toUpperCase(),
                  style: const TextStyle(color: LandingScreen._green, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFF10255A), fontSize: wide ? 34 : 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15),
              ),
              SizedBox(height: wide ? 40 : 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  final bool wide;
  const _Features({required this.wide});

  static const _items = [
    (DPAssets.svcAirtime, 'Airtime & data', 'MTN, Airtel, Glo, 9mobile, Orange, Africell and more — delivered instantly.'),
    (DPAssets.svcElectricity, 'Electricity', 'Prepaid and postpaid meters. Your token arrives in seconds.'),
    (DPAssets.svcTv, 'Cable TV', 'Renew or change DStv, GOtv and StarTimes without leaving home.'),
    (DPAssets.svcAddMoney, 'Add money', 'Your own account number. Transfer from any bank and your wallet is credited automatically.'),
    (DPAssets.svcSendMoney, 'Send money', 'Banks and mobile money across Africa, with the fee and rate shown before you pay.'),
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
          for (final f in _items)
            SizedBox(
              width: cardW,
              child: _Card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(16)),
                      child: DPImage(f.$1, fallback: const Icon(DPIcons.wallet, color: LandingScreen._navy)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2, style: const TextStyle(color: Color(0xFF10255A), fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(f.$3, style: const TextStyle(color: Color(0xFF5B6B8C), fontSize: 14, height: 1.45)),
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
    final ng = _CountryCard(
      flag: 'NG',
      name: 'Nigeria',
      currency: 'Naira (₦)',
      points: const ['Airtime, data, electricity, TV, education', 'Own account number to add money', 'Instant receipts you can download'],
    );
    final sl = _CountryCard(
      flag: 'SL',
      name: 'Sierra Leone',
      currency: 'Leones (Le)',
      points: const ['Orange, Africell and Qcell airtime & data', 'EDSA tokens and TV subscriptions', 'Send money to Nigeria and across Africa'],
    );
    return wide
        ? IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: ng), const SizedBox(width: 18), Expanded(child: sl)]),
          )
        : Column(children: [ng, const SizedBox(height: 18), sl]);
  }
}

class _CountryCard extends StatelessWidget {
  final String flag;
  final String name;
  final String currency;
  final List<String> points;
  const _CountryCard({required this.flag, required this.name, required this.currency, required this.points});

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFF7F9FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DPFlag(flag, width: 34),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: const TextStyle(color: Color(0xFF10255A), fontSize: 20, fontWeight: FontWeight.w800))),
              Text(currency, style: const TextStyle(color: Color(0xFF5B6B8C), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: LandingScreen._green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p, style: const TextStyle(color: Color(0xFF33456B), fontSize: 15, height: 1.35))),
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
    ('2', 'Add money', 'Transfer to your own account number, or follow the Add Money steps.'),
    ('3', 'Pay and send', 'Buy airtime, pay bills or send money — with a receipt every time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final s in _steps)
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: LandingScreen._navy, shape: BoxShape.circle),
                child: Text(s.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              const SizedBox(height: 14),
              Text(s.$2, style: const TextStyle(color: Color(0xFF10255A), fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(s.$3, style: const TextStyle(color: Color(0xFF5B6B8C), fontSize: 14, height: 1.45)),
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
  final double pad;
  final bool wide;
  const _Security({required this.pad, required this.wide});

  static const _points = [
    (Icons.lock_rounded, 'PIN on every payment'),
    (Icons.phonelink_lock_rounded, 'New-device alerts'),
    (Icons.receipt_long_rounded, 'Receipts for everything'),
    (Icons.support_agent_rounded, 'Real people for support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0E2766),
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const Text('Your money, protected',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 26),
              Wrap(
                spacing: 28,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in _points)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p.$1, color: const Color(0xFF35C08E), size: 22),
                        const SizedBox(width: 10),
                        Text(p.$2, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        Text('Get the Dalabapay app',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: const TextStyle(color: Color(0xFF10255A), fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text(
          'Fingerprint login, instant notifications and receipts on your phone. Your website account works in the app.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: const TextStyle(color: Color(0xFF5B6B8C), fontSize: 16, height: 1.5),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _Card(
            padding: EdgeInsets.all(wide ? 36 : 24),
            child: wide
                ? Row(children: [Expanded(child: copy), const SizedBox(width: 24), const PlayStoreBadge(large: true)])
                : Column(children: [copy, const SizedBox(height: 22), const PlayStoreBadge(large: true)]),
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
      color: Colors.white,
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
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('Log in')),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Create account')),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/help'), child: const Text('Help & support')),
                ],
              ),
              Text('© ${DateTime.now().year} Dalabapay. All rights reserved.',
                  style: const TextStyle(color: Color(0xFF7B87A1), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6ECF5)),
          boxShadow: const [BoxShadow(color: Color(0x0F15368A), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: child,
      );
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;
  final bool small;
  final Color background;
  final Color foreground;
  const _PillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.outlined = false,
    this.small = false,
    this.background = Colors.white,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final h = small ? 40.0 : 52.0;
    return Material(
      color: outlined ? Colors.transparent : background,
      shape: StadiumBorder(side: outlined ? BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5) : BorderSide.none),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 18 : 26),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: foreground, fontSize: small ? 14 : 16, fontWeight: FontWeight.w800)),
                if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: foreground, size: 18)],
              ],
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
