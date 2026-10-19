// lib/presentation/screens/onboarding/onboarding_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../ui/ui.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // Slide images live in assets/images/ (listed in pubspec.yaml).
  // Slide 1 follows the design. Slides 2 and 3 keep the design's layout but
  // describe features the app really has (the design's POS and Mastercard
  // slides advertise services with no backend yet).
  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      image: 'assets/images/onboarding_1.png',
      icon: DPIcons.wallet,
      eyebrow: '',
      title: 'Manage Your\nWallet & Pay Bills',
      description:
          'Top up your wallet, pay bills, buy airtime, data and more — all in one place.',
    ),
    OnboardingData(
      image: 'assets/images/onboarding_2.png',
      icon: DPIcons.bolt,
      eyebrow: '',
      title: 'Instant Payments,\n24/7',
      description:
          'No queue, no stress. Airtime, data, TV and electricity delivered in seconds — any time of day.',
    ),
    OnboardingData(
      image: 'assets/images/onboarding_3.png',
      icon: DPIcons.sparkle,
      eyebrow: '',
      title: 'Earn As\nYou Pay',
      description:
          'Get commission on eligible payments and rewards when friends join with your code.',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final d in _onboardingData) {
      precacheImage(AssetImage(d.image), context, onError: (e, _) {
        debugPrint('Could not precache ${d.image}: $e');
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    api.setFlag('onboarded');
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _goToNextPage() {
    if (_selectedIndex < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _selectedIndex == _onboardingData.length - 1;
    return Scaffold(
      backgroundColor: DP.surface,
      body: DPWaveBackground(child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return OnboardingContent(data: _onboardingData[index]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedDot(isActive: _selectedIndex == index),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DPButton(
                label: isLast ? 'Get Started' : 'Next',
                icon: DPIcons.forward,
                onPressed: _goToNextPage,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: isLast ? 0 : 1,
              duration: DPMotion.fast,
              child: TextButton(
                onPressed: isLast ? null : _finishOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: DP.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      )),
    );
  }
}

// Onboarding Data Model
class OnboardingData {
  final String image;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  OnboardingData({
    required this.image,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}

// Onboarding Content Widget
class OnboardingContent extends StatelessWidget {
  final OnboardingData data;

  const OnboardingContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DPAppear(
              scaleFrom: 0.92,
              child: SizedBox(
                width: double.infinity,
                height: c.maxHeight * 0.58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft brand glow behind the illustration.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.62,
                            colors: [
                              DP.green.withValues(alpha: DP.isDark ? 0.18 : 0.12),
                              DP.green.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DPFloat(
                        child: Image.asset(
                  data.image,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) {
                    // Shows why the picture didn't load (debug builds only).
                    debugPrint('Onboarding image failed: ${data.image}\n$error');
                    return _IllustrationPlaceholder(
                      icon: data.icon,
                      debugMessage: kDebugMode
                          ? 'Could not load ${data.image}\n$error'
                          : null,
                    );
                  },
                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            DPAppear(
              delay: const Duration(milliseconds: 120),
              child: Text(
                data.title,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: DP.ink,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DPAppear(
              delay: const Duration(milliseconds: 200),
              child: Text(
                data.description,
                style: DP.body.copyWith(color: DP.muted, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown until the illustration file is added: soft circles with an icon.
class _IllustrationPlaceholder extends StatelessWidget {
  final IconData icon;
  final String? debugMessage;
  const _IllustrationPlaceholder({required this.icon, this.debugMessage});

  @override
  Widget build(BuildContext context) {
    final circle = Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: DP.mint,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            color: DP.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 60, color: DP.green),
        ),
      );
    if (debugMessage == null) return Center(child: circle);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: FittedBox(child: circle)),
          const SizedBox(height: 8),
          Text(
            debugMessage!,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: DP.red),
          ),
        ],
      ),
    );
  }
}

// Animated Dot Widget
class AnimatedDot extends StatelessWidget {
  final bool isActive;

  const AnimatedDot({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? DP.green : DP.border,
        borderRadius: BorderRadius.circular(DP.rPill),
      ),
    );
  }
}
