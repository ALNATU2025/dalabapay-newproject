// lib/core/constants/colors.dart
// Mapped onto the redesign palette (lib/ui/dp_tokens.dart).
import 'package:flutter/material.dart';

import '../../ui/dp_tokens.dart';

class AppColors {
  static const Color primary = DP.green;
  static Color get primaryLight => DP.mint;
  static const Color secondary = DP.navy;
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static Color get grey => DP.muted;
  static Color get lightGrey => DP.borderSoft;
  static Color get darkGrey => DP.inkSoft;
  static const Color success = DP.green;
  static const Color error = DP.red;
  static const Color warning = DP.amber;
  static const Color info = DP.navyIcon;

  static Color get textPrimary => DP.ink;
  static Color get textSecondary => DP.muted;
  static Color get border => DP.border;
  static Color get background => DP.bg;

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DP.green, DP.greenDeep],
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A10255A),
    blurRadius: 18,
    offset: Offset(0, 6),
  );
}
