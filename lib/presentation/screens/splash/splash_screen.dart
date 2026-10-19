// lib/presentation/screens/splash/splash_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../ui/ui.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fade;
  late Animation<double> _scale;

  static const _splashDuration = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: _splashDuration,
    );
    _fade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _mainController.forward();

    _checkRouteAfterSplash();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  /// Saved login → unlock with PIN; first launch → onboarding; else login.
  Future<void> _checkRouteAfterSplash() async {
    api.warmUp();
    final results = await Future.wait([
      Session.instance.restore(),
      api.readFlag('onboarded'),
      Future.delayed(_splashDuration),
    ]);
    if (!mounted) return;
    final loggedIn = results[0] == true;
    final onboarded = results[1] == true;
    if (loggedIn) {
      Navigator.pushReplacementNamed(
        context,
        Session.instance.user!.pinSet ? '/pin-login' : '/pin-setup',
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>
            onboarded ? const LoginScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Loader from the design: navy dot · green pill · light-green dot,
  /// the pill travelling between them.
  Widget _dots() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        final active = ((_mainController.value * 6).floor() % 3);
        const colors = [DP.navy, DP.green, DP.greenSoft];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final on = i == active;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: on ? 30 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(5),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          // Scale everything from the smaller side so the logo, name and
          // tagline always fit — small phones, tall phones, tablets, web.
          final unit = math.min(w, h * 0.6);
          final logo = (unit * 0.28).clamp(64.0, 140.0);
          final title = (unit * 0.11).clamp(28.0, 52.0);
          final tagline = (unit * 0.045).clamp(14.0, 20.0);
          // Waves never take more than a slice of the screen, so they can't
          // cover the logo on short screens.
          final topWave = math.min(h * 0.18, 160.0);
          final bottomWave = math.min(h * 0.24, 220.0);

          return Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                width: w * 0.75,
                child: DPWaves(top: true, height: topWave),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DPWaves(height: bottomWave),
              ),
              Positioned.fill(
                top: topWave * 0.6,
                bottom: bottomWave * 0.8,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: DP.green.withValues(alpha: 0.18),
                                      blurRadius: logo * 0.6,
                                      spreadRadius: logo * 0.05,
                                    ),
                                  ],
                                ),
                                child: DPLogoMark(size: logo),
                              ),
                              SizedBox(height: logo * 0.18),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Dalaba',
                                        style: TextStyle(color: DP.navyInk),
                                      ),
                                      TextSpan(
                                        text: 'pay',
                                        style: TextStyle(color: DP.green),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: title,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Smart Life Fast Pay',
                                  maxLines: 1,
                                  style: DP.body.copyWith(
                                    color: DP.navyInk,
                                    fontSize: tagline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: logo * 0.32),
                              _dots(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
