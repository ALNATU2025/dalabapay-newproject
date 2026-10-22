// lib/ui/dp_tokens.dart
import 'package:flutter/material.dart';

/// Colour, radius and text tokens taken from the Dalabapay redesign.
class DP {
  DP._();

  /// True while the dark theme is showing. Set by ThemeController; the
  /// surface and text colours below switch with it. Brand colours (greens,
  /// navy, blue, amber, red) and the gradients stay the same in both themes.
  static bool isDark = false;

  /// Swaps a [DPAuto] placeholder for the current theme colour.
  static Color resolve(Color c) {
    if (c == DPAuto.surface) return surface;
    if (c == DPAuto.border) return border;
    if (c == DPAuto.ink) return ink;
    if (c == DPAuto.mint) return mint;
    if (c == DPAuto.blueTint) return blueTint;
    if (c == DPAuto.navyInk) return navyInk;
    return c;
  }

  /// Navy for text/icons that must stay readable on a dark background.
  static Color get navyInk =>
      isDark ? const Color(0xFF9DB8FF) : const Color(0xFF15368A);

  // ── Surfaces ──────────────────────────────────────────────
  static Color get bg => isDark ? const Color(0xFF0B1220) : const Color(0xFFF7F9FC);
  static Color get surface => isDark ? const Color(0xFF141D2F) : const Color(0xFFFFFFFF);
  static Color get border => isDark ? const Color(0xFF26324A) : const Color(0xFFE6ECF3);
  static Color get borderSoft => isDark ? const Color(0xFF1C263A) : const Color(0xFFF0F3F8);

  // ── Text ──────────────────────────────────────────────────
  static Color get ink => isDark ? const Color(0xFFE8EDF7) : const Color(0xFF10255A);
  static Color get inkSoft => isDark ? const Color(0xFFB9C3D8) : const Color(0xFF3E4E74);
  static Color get muted => isDark ? const Color(0xFF8D98AF) : const Color(0xFF7B87A1);
  static Color get faint => isDark ? const Color(0xFF5B6781) : const Color(0xFFB2BBCB);

  // ── Brand ─────────────────────────────────────────────────
  static const Color navy = Color(0xFF15368A);
  static const Color navyDeep = Color(0xFF0E2766);
  static const Color navyRaised = Color(0xFF2450B4);
  static const Color navyIcon = Color(0xFF2563EB);
  static const Color blue = Color(0xFF2779FD);
  static const Color greenBright = Color(0xFF04AB79);
  static Color get blueTint => isDark ? const Color(0xFF1A2B4F) : const Color(0xFFEAF1FF);

  static const Color green = Color(0xFF079A68);
  static const Color greenDeep = Color(0xFF026C45);
  static const Color greenSoft = Color(0xFF35C08E);
  static Color get mint => isDark ? const Color(0xFF10322A) : const Color(0xFFE4F6EE);
  static Color get mintLine => isDark ? const Color(0xFF1E5243) : const Color(0xFFC3EAD8);

  // ── Status ────────────────────────────────────────────────
  static const Color amber = Color(0xFFB7791F);
  static Color get amberBg => isDark ? const Color(0xFF35290F) : const Color(0xFFFFF4E0);
  static Color get amberLine => isDark ? const Color(0xFF4F3D17) : const Color(0xFFF5E1BC);
  static const Color red = Color(0xFFE5484D);
  static Color get redBg => isDark ? const Color(0xFF3B1B1E) : const Color(0xFFFDECEC);
  static Color get redLine => isDark ? const Color(0xFF5C2B2E) : const Color(0xFFF8CFD0);

  // ── Radii ─────────────────────────────────────────────────
  static const double rXs = 6;
  static const double rSm = 10;
  static const double rMd = 12;
  static const double rLg = 14;
  static const double rXl = 18;
  static const double rXxl = 24;
  static const double rPill = 999;

  // ── Spacing ───────────────────────────────────────────────
  static const double gutter = 24;
  static const EdgeInsets page = EdgeInsets.fromLTRB(24, 8, 24, 32);

  // ── Type ──────────────────────────────────────────────────
  // The Inter family comes from the app theme, so these styles only set
  // size, weight and colour.
  static TextStyle get display => TextStyle(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: ink,
  );
  static TextStyle get title => TextStyle(
    fontSize: 19,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: ink,
  );
  static TextStyle get section => TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: ink,
  );
  static TextStyle get body => TextStyle(
    fontSize: 14.5,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: ink,
  );
  static TextStyle get bodyStrong => TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static TextStyle get label => TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: ink,
  );
  static TextStyle get caption => TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: muted,
  );
  static TextStyle get tiny => TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: muted,
  );
  static const TextStyle link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: green,
  );
  static TextStyle get money => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0D10255A), blurRadius: 16, offset: Offset(0, 6)),
  ];

  // ── Elevation ─────────────────────────────────────────────
  // Shadows are tinted navy in light mode and almost black in dark mode so
  // raised surfaces read the same way in both themes.
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: isDark ? const Color(0x33000000) : const Color(0x0A10255A),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: isDark ? const Color(0x4D000000) : const Color(0x1210255A),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: isDark ? const Color(0x66000000) : const Color(0x1A10255A),
          blurRadius: 36,
          offset: const Offset(0, 16),
        ),
      ];

  /// Coloured glow under a brand surface (balance card, primary button).
  static List<BoxShadow> glow(Color c, {double strength = 1}) => [
        BoxShadow(
          color: c.withValues(alpha: (isDark ? 0.35 : 0.28) * strength),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  /// Navy balance card (Home).
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3F99), Color(0xFF15368A), Color(0xFF0E2766)],
  );

  /// Green balance card (My Wallet).
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF079A68), Color(0xFF02804F), Color(0xFF026C45)],
  );

  /// Currency of the signed-in account ("NGN" or "SLE"). Set by Session;
  /// [naira] formats in it, so every screen shows the user's own money.
  static String currency = 'NGN';

  /// "₦" or "Le" for the signed-in account.
  static String get currencySymbol => symbolFor(currency);

  static String symbolFor(String? code) => code == 'SLE' ? 'Le' : '₦';

  /// The signed-in user's money with thousands separators:
  /// 124850 → ₦124,850.00 (Nigeria) or Le 124,850.00 (Sierra Leone).
  static String naira(num? value, {bool decimals = true}) =>
      moneyIn(value, currency, decimals: decimals);

  /// Money in a given currency ("NGN"/"SLE") — for lists that can mix
  /// countries, such as the admin console.
  static String moneyIn(num? value, String? code, {bool decimals = true}) {
    final v = (value ?? 0).toDouble();
    final neg = v < 0;
    final fixed = v.abs().toStringAsFixed(decimals ? 2 : 0);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    final s = parts.length > 1 ? '$whole.${parts[1]}' : whole;
    final sign = neg ? '-' : '';
    return code == 'SLE' ? '${sign}Le $s' : '$sign₦$s';
  }
}

/// Spacing scale (4-point grid). Use these instead of loose numbers so
/// screens line up with each other.
class DPSpace {
  DPSpace._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const SizedBox h4 = SizedBox(height: xxs);
  static const SizedBox h8 = SizedBox(height: xs);
  static const SizedBox h12 = SizedBox(height: sm);
  static const SizedBox h16 = SizedBox(height: md);
  static const SizedBox h20 = SizedBox(height: lg);
  static const SizedBox h24 = SizedBox(height: xl);
  static const SizedBox h32 = SizedBox(height: xxl);
  static const SizedBox w4 = SizedBox(width: xxs);
  static const SizedBox w8 = SizedBox(width: xs);
  static const SizedBox w12 = SizedBox(width: sm);
  static const SizedBox w16 = SizedBox(width: md);
}

/// Icon set for the redesign. Material outlined/rounded glyphs chosen to match
/// the line icons in the design files.
class DPIcons {
  DPIcons._();
  // services
  static const IconData phone = Icons.phone_outlined;
  static const IconData wifi = Icons.wifi_rounded;
  static const IconData bolt = Icons.bolt_outlined;
  static const IconData tv = Icons.live_tv_outlined;
  static const IconData trophy = Icons.emoji_events_outlined;
  static const IconData plane = Icons.flight_outlined;
  static const IconData globe = Icons.public_rounded;
  static const IconData grid = Icons.grid_view_rounded;
  static const IconData router = Icons.router_outlined;
  static const IconData school = Icons.school_outlined;
  static const IconData shield = Icons.shield_outlined;
  static const IconData heart = Icons.volunteer_activism_outlined;
  static const IconData ticket = Icons.confirmation_number_outlined;
  // navigation
  static const IconData home = Icons.home_outlined;
  static const IconData homeFilled = Icons.home_rounded;
  static const IconData activity = Icons.swap_horiz_rounded;
  static const IconData earnings = Icons.auto_awesome_outlined;
  static const IconData user = Icons.person_outline_rounded;
  static const IconData userFilled = Icons.person_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData upRight = Icons.north_east_rounded;
  static const IconData downLeft = Icons.south_west_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData menu = Icons.menu_rounded;
  // actions
  static const IconData plus = Icons.add_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData share = Icons.share_outlined;
  static const IconData search = Icons.search_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData download = Icons.download_rounded;
  static const IconData scan = Icons.qr_code_scanner_rounded;
  static const IconData contact = Icons.perm_contact_calendar_outlined;
  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData logout = Icons.logout_rounded;
  // status
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData sparkle = Icons.auto_awesome_outlined;
  static const IconData sun = Icons.wb_sunny_outlined;
  static const IconData shieldCheck = Icons.verified_user_outlined;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData alert = Icons.error_outline_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_outline_rounded;
  static const IconData pending = Icons.schedule_rounded;
  static const IconData failed = Icons.cancel_outlined;
  // account
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData fingerprint = Icons.fingerprint_rounded;
  static const IconData bell = Icons.notifications_none_rounded;
  static const IconData help = Icons.help_outline_rounded;
  static const IconData mail = Icons.mail_outline_rounded;
  static const IconData bank = Icons.account_balance_outlined;
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData people = Icons.group_outlined;
  static const IconData referral = Icons.group_add_outlined;
  static const IconData badge = Icons.badge_outlined;
  static const IconData receipt = Icons.receipt_long_outlined;
  static const IconData history = Icons.history_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData flag = Icons.flag_outlined;
  static const IconData messageCircle = Icons.chat_bubble_outline_rounded;
  static const IconData gift = Icons.card_giftcard_outlined;
  static const IconData smartphone = Icons.smartphone_rounded;
  static const IconData sms = Icons.sms_outlined;
  static const IconData chart = Icons.bar_chart_rounded;
  static const IconData key = Icons.key_outlined;
  static const IconData admin = Icons.admin_panel_settings_outlined;
}

/// Placeholders for theme colours in `const` default values (Dart needs
/// constants there). Widgets call [DP.resolve] to turn them into the colour
/// for the current light/dark theme.
class DPAuto {
  DPAuto._();
  static const Color surface = Color(0x01000001);
  static const Color border = Color(0x01000002);
  static const Color ink = Color(0x01000003);
  static const Color mint = Color(0x01000004);
  static const Color blueTint = Color(0x01000005);
  static const Color navyInk = Color(0x01000006);
}
