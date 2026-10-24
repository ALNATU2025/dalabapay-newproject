// lib/presentation/screens/settings/settings_screen.dart
// Profile + Security. Details come from the session (GET /api/me); the
// notifications switch saves to PATCH /api/me/preferences.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/quick_login.dart';
import '../../widgets/pin_sheet.dart';
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
    _loadBiometric();
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

  bool _uploadingPhoto = false;
  bool _bioSupported = false;
  bool _bioOn = false;

  Future<void> _loadBiometric() async {
    final supported = await QuickLogin.biometricsSupported;
    final on = await QuickLogin.biometricEnabled;
    if (mounted) setState(() {
      _bioSupported = supported;
      _bioOn = on;
    });
  }

  Future<void> _setBiometric(bool on) async {
    if (!on) {
      await QuickLogin.disableBiometric();
      if (mounted) setState(() => _bioOn = false);
      return;
    }
    final pin = await askPin(context, title: 'Turn on fingerprint sign-in', message: 'Enter your payment PIN to confirm.');
    if (pin == null || !mounted) return;
    try {
      final ok = await QuickLogin.enableBiometric(pin);
      if (!mounted) return;
      setState(() => _bioOn = ok);
      dpSnack(context, ok ? 'Fingerprint sign-in is on' : 'Fingerprint check was cancelled', success: ok, error: !ok);
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  /// Take or choose a profile photo (or remove it).
  Future<void> _changePhoto() async {
    final has = _user?.avatar != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 8),
              Text('Profile photo', style: DP.title),
              const SizedBox(height: 8),
              DPMenuRow(icon: DPIcons.camera, title: 'Take a photo', onTap: () => Navigator.pop(ctx, 'camera')),
              DPMenuRow(icon: DPIcons.download, title: 'Choose from gallery', onTap: () => Navigator.pop(ctx, 'gallery')),
              if (has) DPMenuRow(icon: DPIcons.close, title: 'Remove photo', color: DP.red, onTap: () => Navigator.pop(ctx, 'remove')),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      if (choice == 'remove') {
        await api.delete('/api/me/avatar');
      } else {
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 75,
          preferredCameraDevice: CameraDevice.front,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (bytes.length > 290 * 1024) {
          if (mounted) dpSnack(context, 'That photo is too large. Please choose another.', error: true);
          return;
        }
        await api.put('/api/me/avatar', {'image': base64Encode(bytes)});
      }
      final me = await api.get('/api/me');
      if (me is Map) Session.instance.setUser(me.cast<String, dynamic>());
      if (mounted) {
        setState(() {});
        dpSnack(context, choice == 'remove' ? 'Photo removed' : 'Profile photo updated', success: true);
      }
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
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
      final quick = await QuickLogin.available;
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, quick ? '/quick-login' : '/login', (_) => false);
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
              if (_bioSupported) ...[
                DPMenuRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Fingerprint / Face sign-in',
                  subtitle: 'Sign back in without your PIN',
                  trailing: Switch(value: _bioOn, onChanged: _setBiometric),
                ),
                _divider(),
              ],
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
    const onNavy = Color(0xB3FFFFFF);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: DP.navyGradient,
        borderRadius: BorderRadius.circular(DP.rXxl),
        boxShadow: DP.glow(DP.navy, strength: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            child: GestureDetector(
              onTap: _changePhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: DPAvatar(name: _user?.fullName ?? '', bytes: _user?.avatarBytes, size: 64),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: DP.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: _uploadingPhoto
                          ? const Padding(padding: EdgeInsets.all(5), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(DPIcons.camera, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.fullName ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(_user?.phone ?? '', style: const TextStyle(color: onNavy, fontSize: 13)),
                const SizedBox(height: 1),
                Text(
                  _user?.email ?? '',
                  style: const TextStyle(color: onNavy, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(DP.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _kycVerified ? Icons.verified_rounded : DPIcons.badge,
                        size: 14,
                        color: _kycVerified ? const Color(0xFF7FE3BC) : const Color(0xFFFFD58A),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _kycVerified
                            ? 'Verified'
                            : (_kycLabel == 'Not started' ? 'Not verified' : _kycLabel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
}
