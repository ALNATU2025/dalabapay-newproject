// lib/presentation/screens/settings/settings_screen.dart
// Profile + Security. Details come from the session (GET /api/me); the
// notifications switch saves to PATCH /api/me/preferences.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../ui/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _securityView = false;
  bool _savingPush = false;

  AppUser? get _user => Session.instance.user;
  bool get _kycVerified => _user?.kycStatus == 'verified';

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
    Session.instance.refreshQuietly();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  String get _kycLabel => switch (_user?.kycStatus) {
        'verified' => 'Verified',
        'pending' => 'Pending',
        'rejected' => 'Rejected',
        _ => 'Not started',
      };

  Color get _kycColor => switch (_user?.kycStatus) {
        'verified' => DP.green,
        'rejected' => DP.red,
        _ => DP.amber,
      };

  Future<void> _setPush(bool v) async {
    setState(() => _savingPush = true);
    try {
      final u = await api.patch('/api/me/preferences', {'pushEnabled': v});
      if (u is Map) Session.instance.setUser(u.cast<String, dynamic>());
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _savingPush = false);
    }
  }

  Widget _divider() => Divider(height: 1, color: DP.borderSoft);

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? status,
    Color? statusColor,
    VoidCallback? onTap,
  }) {
    return DPMenuRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null) _statusChip(status, statusColor ?? DP.green),
          Icon(DPIcons.chevronRight, color: DP.muted, size: 22),
        ],
      ),
    );
  }

  void _showDoc(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const DPSheetHandle(),
            const SizedBox(height: 8),
            Text(title, style: DP.title),
            const SizedBox(height: 12),
            Text(
              'Placeholder text. Add your real $title here.\n\n'
              '1. Introduction\nDalabapay ("we", "us") provides wallet and bill payment services.\n\n'
              '2. Your information\nWe collect the details you give us to run your account.\n\n'
              '3. Contact\nReach us from Help & Support in the app.',
              style: DP.body.copyWith(color: DP.inkSoft, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 12),
              const DPLogoMark(size: 48),
              const SizedBox(height: 8),
              Text('Dalabapay', style: DP.title),
              const SizedBox(height: 4),
              Text('Smart Life Fast Pay', style: DP.caption),
              const SizedBox(height: 16),
              DPMenuRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.pop(ctx);
                  _showDoc('Privacy Policy');
                },
              ),
              DPMenuRow(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () {
                  Navigator.pop(ctx);
                  _showDoc('Terms & Conditions');
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Dalabapay · Version 1.0.0',
                style: DP.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPersonalInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 8),
              Text('Personal information', style: DP.title),
              const SizedBox(height: 16),
              DPCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    DPSummaryRow('Full name', _user?.fullName ?? ''),
                    DPSummaryRow('Email', _user?.email ?? ''),
                    DPSummaryRow('Phone', _user?.phone ?? ''),
                    DPSummaryRow('Referral code', _user?.referralCode ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To change your name, email or phone number, contact support from Help.',
                style: DP.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await dpDialog(
      context,
      title: 'Log out?',
      message: 'You\'ll need your password or PIN to get back in.',
      confirmLabel: 'Log Out',
      cancelLabel: 'Cancel',
      tone: DPTone.error,
      icon: DPIcons.logout,
      destructive: true,
    );
    if (ok == true && mounted) {
      await Session.instance.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_securityView,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _securityView) setState(() => _securityView = false);
      },
      child: Scaffold(
        backgroundColor: DP.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DPTopBar(
                title: _securityView ? 'Security' : 'Profile',
                onBack: _securityView
                    ? () => setState(() => _securityView = false)
                    : null,
                trailing: _securityView
                    ? null
                    : DPIconSquare(
                        icon: DPIcons.settings,
                        size: 40,
                        color: DP.navyInk,
                        background: Colors.transparent,
                        semanticLabel: 'Security settings',
                        onTap: () => setState(() => _securityView = true),
                      ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: _securityView
                      ? KeyedSubtree(
                          key: const ValueKey('security'),
                          child: _buildSecurity(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('profile'),
                          child: _buildProfile(),
                        ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: DPBottomNav(
          index: 3,
          items: kDPTabs,
          onCenter: () => Navigator.pushNamed(context, '/send-money'),
          onTap: (i) {
            if (i == 3) {
              if (_securityView) setState(() => _securityView = false);
              return;
            }
            Navigator.of(context).maybePop(
              const ['home', 'transactions', 'services', 'profile'][i],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSecurity() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        DPCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              _tile(
                icon: DPIcons.key,
                title: 'Change Password',
                onTap: () => Navigator.pushNamed(context, '/change-password'),
              ),
              _divider(),
              _tile(
                icon: DPIcons.lock,
                title: 'Change Payment PIN',
                onTap: () => Navigator.pushNamed(context, '/change-pin'),
              ),
              _divider(),
              DPMenuRow(
                icon: DPIcons.bell,
                title: 'Push Notifications',
                subtitle: 'Payment alerts on this phone',
                trailing: Switch(
                  value: _user?.pushEnabled ?? true,
                  onChanged: _savingPush ? null : _setPush,
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _showDoc('Privacy Policy'),
              ),
              _divider(),
              _tile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () => _showDoc('Terms & Conditions'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DPBanner(
          'Never share your password or payment PIN — Dalabapay staff will never ask for them.',
          tone: DPTone.info,
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        DPAppear(child: _buildProfileHeader()),
        const SizedBox(height: 20),
        _buildAppearance(),
        const SizedBox(height: 16),
        DPCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              _tile(
                icon: DPIcons.user,
                title: 'Personal Information',
                onTap: _showPersonalInfo,
              ),
              _divider(),
              _tile(
                icon: DPIcons.shieldCheck,
                title: 'KYC Verification',
                status: _kycLabel,
                statusColor: _kycColor,
                onTap: () => Navigator.pushNamed(context, '/kyc'),
              ),
              _divider(),
              _tile(
                icon: DPIcons.lock,
                title: 'Security',
                onTap: () => setState(() => _securityView = true),
              ),
              _divider(),
              _tile(
                icon: DPIcons.sparkle,
                title: 'Earnings',
                onTap: () => Navigator.pushNamed(context, '/commission'),
              ),
              _divider(),
              _tile(
                icon: DPIcons.referral,
                title: 'Refer a Friend',
                onTap: () => Navigator.pushNamed(context, '/referral'),
              ),
              _divider(),
              _tile(
                icon: DPIcons.bell,
                title: 'Notifications',
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
              if (_user?.isAdmin ?? false) ...[
                _divider(),
                _tile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Console',
                  status: (_user?.role ?? 'admin').toUpperCase(),
                  statusColor: DP.navyInk,
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
              ],
              _divider(),
              _tile(
                icon: DPIcons.help,
                title: 'Help & Support',
                onTap: () => Navigator.pushNamed(context, '/help'),
              ),
              _divider(),
              _tile(
                icon: DPIcons.info,
                title: 'About Dalabapay',
                onTap: _showAbout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DPOutlineButton(
          label: 'Log Out',
          color: DP.red,
          icon: DPIcons.logout,
          onPressed: _confirmLogout,
        ),
      ],
    );
  }

  /// Theme picker: Normal (light), Dark, or follow the phone (System).
  Widget _buildAppearance() {
    const modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    final current = ThemeController.instance.value;
    return DPCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DPIconBadge.blue(
                DP.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 36,
                iconSize: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance', style: DP.bodyStrong),
                    Text(
                      current == ThemeMode.system
                          ? 'Following your phone (${DP.isDark ? 'dark' : 'normal'})'
                          : '${ThemeController.label(current)} theme',
                      style: DP.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DPSegmented(
            options: [for (final m in modes) ThemeController.label(m)],
            index: modes.indexOf(current),
            onChanged: (i) {
              ThemeController.instance.setMode(modes[i]);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: DP.blueTint,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: DPAvatar(name: _user?.fullName ?? '', size: 72),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _user?.fullName ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DP.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(_user?.phone ?? '', style: DP.caption),
              const SizedBox(height: 2),
              Text(
                _user?.email ?? '',
                style: DP.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (_kycVerified)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: DP.green),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: DP.green,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                _statusChip(_kycLabel == 'Not started' ? 'Not verified' : _kycLabel, _kycColor),
            ],
          ),
        ),
      ],
    );
  }
}
