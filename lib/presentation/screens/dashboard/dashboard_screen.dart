// lib/presentation/screens/dashboard/dashboard_screen.dart
// Home — UI only. Balance card, essential services, promo banners, recent
// transactions, Services tab and bottom menu, all from sample data.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/transaction_widgets.dart';
import '../bills/pay_bills_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isBalanceVisible = true;
  final int _unreadNotificationCount = 2;

  static const TextStyle _balanceStyle = TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const List<DPService> _payBillGroup = [
    DPService('Electricity', DPIcons.bolt, '/electricity', DPAssets.svcElectricity, DP.green),
    DPService('Airtime', DPIcons.smartphone, '/airtime', DPAssets.svcAirtime, DP.navyIcon),
    DPService('Data', DPIcons.wifi, '/data', DPAssets.svcData, DP.navyIcon),
  ];
  static const List<DPService> _payTvGroup = [
    DPService('DSTV', DPIcons.tv, '/cable', DPAssets.dstv, DP.navyIcon),
    DPService('GOtv', DPIcons.tv, '/cable', DPAssets.gotv, DP.green),
    DPService('StarTimes', DPIcons.tv, '/cable', DPAssets.startimes, DP.amber),
  ];

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ==================== NAVIGATION ====================

  void _openServiceRoute(String route) {
    HapticFeedback.lightImpact();
    switch (route) {
      case '/services':
        _onNavTap(2);
        return;
      case '/bills':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillsScreen(
              onSelect: (r) {
                Navigator.pop(context);
                _openServiceRoute(r);
              },
            ),
          ),
        );
        return;
      case '/wallet:add':
        Navigator.pushNamed(context, '/wallet');
        return;
      case '/wallet:send':
        Navigator.pushNamed(context, '/send-money');
        return;
      default:
        Navigator.pushNamed(context, route);
    }
  }

  /// Transactions and Profile are pushed pages with their own bottom menu.
  /// When they close they say which tab to show next.
  Future<void> _pushTab(String route) async {
    final result = await Navigator.pushNamed(context, route);
    if (!mounted) return;
    switch (result) {
      case 'transactions':
        _onNavTap(1);
        break;
      case 'services':
        setState(() => _selectedIndex = 2);
        break;
      case 'profile':
        _onNavTap(3);
        break;
      case 'send':
        Navigator.pushNamed(context, '/send-money');
        setState(() => _selectedIndex = 0);
        break;
      default:
        setState(() => _selectedIndex = 0);
    }
  }

  void _onNavTap(int i) {
    HapticFeedback.lightImpact();
    switch (i) {
      case 0:
      case 2:
        if (_selectedIndex != i) setState(() => _selectedIndex = i);
        break;
      case 1:
        setState(() => _selectedIndex = 1);
        _pushTab('/transactions');
        break;
      case 3:
        setState(() => _selectedIndex = 3);
        _pushTab('/settings');
        break;
    }
  }

  void _showServiceGroup(String title, String subtitle, List<DPService> group) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 8),
              Text(title, style: DP.title),
              const SizedBox(height: 4),
              Text(subtitle, style: DP.caption),
              const SizedBox(height: 18),
              DPServiceGrid(
                columns: 3,
                tiles: [
                  for (final s in group)
                    DPServiceTile(
                      icon: s.icon,
                      label: s.name,
                      image: s.image,
                      color: s.color,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openServiceRoute(s.route);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SECTIONS ====================

  /// App bar: menu avatar · centred logo · notifications, then the greeting.
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: 'Open menu',
                    child: GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DP.blueTint,
                        ),
                        child: const ClipOval(
                          child: DPAvatar(name: MockUser.fullName, size: 44),
                        ),
                      ),
                    ),
                  ),
                ),
                // Centre logo: assets/images/app_barlogo.png
                // (shows the drawn wordmark until the file is added).
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Image.asset(
                    'assets/images/app_barlogo.png',
                    height: 34,
                    fit: BoxFit.contain,
                    semanticLabel: 'Dalabapay',
                    errorBuilder: (_, __, ___) =>
                        const DPWordmark(height: 28),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: DPIconSquare(
                    icon: DPIcons.bell,
                    size: 44,
                    color: DP.navyInk,
                    background: Colors.transparent,
                    semanticLabel: 'Notifications',
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                    badge: _unreadNotificationCount > 0
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: DP.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: DP.surface, width: 1.5),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hello, ${MockUser.firstName}!',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: DP.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(_greeting(), style: DP.caption.copyWith(fontSize: 13)),
        ],
      ),
    );
  }


  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: DP.navyGradient,
        borderRadius: BorderRadius.circular(DP.rXl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3315368A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Wallet Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              InkResponse(
                radius: 20,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isBalanceVisible = !_isBalanceVisible);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _isBalanceVisible ? DPIcons.eye : DPIcons.eyeOff,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Align(
                key: ValueKey('bal_$_isBalanceVisible'),
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _isBalanceVisible
                      ? DPCountUp(
                          value: MockUser.walletBalance,
                          format: (v) => DP.naira(v),
                          style: _balanceStyle,
                        )
                      : const Text('₦ ••••••', style: _balanceStyle),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/commission'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(DPIcons.sparkle, size: 14, color: Color(0xFF7FE3BC)),
                const SizedBox(width: 5),
                Text(
                  'Earnings ${_isBalanceVisible ? DP.naira(MockUser.commissionBalance) : '₦ ••••'}',
                  style: const TextStyle(
                    color: Color(0xFF7FE3BC),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  DPIcons.chevronRight,
                  size: 16,
                  color: Color(0xFF7FE3BC),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DPButton(
                  label: 'Add Money',
                  leadingIcon: DPIcons.plus,
                  height: 46,
                  background: DP.greenBright,
                  onPressed: () => Navigator.pushNamed(context, '/wallet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DPButton(
                  label: 'Send Money',
                  height: 46,
                  background: DP.blue,
                  onPressed: () => Navigator.pushNamed(context, '/send-money'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPSectionHeader(
            'Essential Services',
            actionLabel: 'More',
            onAction: () => _onNavTap(2),
          ),
          DPServiceGrid(
            columns: 3,
            tiles: [
              DPServiceTile(
                icon: DPIcons.receipt,
                label: 'Pay Bill',
                image: DPAssets.svcBills,
                color: DP.green,
                onTap: () => _showServiceGroup(
                  'Pay Bill',
                  'Electricity, airtime and data',
                  _payBillGroup,
                ),
              ),
              DPServiceTile(
                icon: DPIcons.tv,
                label: 'Pay TV',
                image: DPAssets.svcTv,
                color: DP.navyIcon,
                onTap: () => _showServiceGroup(
                  'Pay TV',
                  'DSTV, GOtv and StarTimes',
                  _payTvGroup,
                ),
              ),
              DPServiceTile(
                icon: DPIcons.globe,
                label: 'International Airtime',
                image: DPAssets.svcInternational,
                color: DP.navyIcon,
                onTap: () => _openServiceRoute('/international-airtime'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final list = kMockTransactions.take(5).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPSectionHeader(
            'Transaction History',
            actionLabel: 'See All',
            onAction: () => _onNavTap(1),
          ),
          DPCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: DP.borderSoft),
                  TransactionRow(tx: list[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final items = <(IconData, String, String?)>[
      (Icons.apps_rounded, 'All Services', null),
      (Icons.admin_panel_settings_outlined, 'Admin Console', '/admin'),
      (DPIcons.shieldCheck, 'Transaction Validation', '/transaction-validation'),
      (Icons.gavel_rounded, 'My Disputes', '/user-disputes'),
      (DPIcons.referral, 'Refer & Earn', '/referral'),
      (DPIcons.badge, 'Verify Identity (KYC)', '/kyc'),
      (DPIcons.settings, 'App Settings', '/settings'),
      (DPIcons.help, 'Help & Support', '/help'),
    ];
    return Drawer(
      backgroundColor: DP.surface,
      width: 280,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            color: DP.navy,
            child: const Row(
              children: [
                DPAvatar(name: MockUser.fullName, size: 48),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MockUser.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        MockUser.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12),
              children: [
                for (var i = 0; i < items.length; i++)
                  _drawerTile(
                    items[i].$1,
                    items[i].$2,
                    selected: i == 0,
                    onTap: () {
                      Navigator.pop(context);
                      final route = items[i].$3;
                      if (route == null) {
                        _onNavTap(2);
                      } else if (route == '/settings') {
                        _onNavTap(3);
                      } else {
                        Navigator.pushNamed(context, route);
                      }
                    },
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(color: DP.border),
                ),
                _drawerTile(
                  DPIcons.logout,
                  'Logout',
                  color: DP.red,
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Version 1.6.0 (UI preview)', style: DP.caption),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title, {
    bool selected = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? (selected ? DP.navyInk : DP.inkSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? DP.blueTint : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected
              ? BorderSide(color: DP.navyInk, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: c, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: DP.bg,
      drawer: _buildDrawer(),
      body: SafeArea(
        bottom: false,
        child: PopScope(
          canPop: _selectedIndex != 2,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _selectedIndex == 2) {
              setState(() => _selectedIndex = 0);
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) =>
                FadeTransition(opacity: a, child: child),
            child: _selectedIndex == 2
                ? ServicesView(
                    key: const ValueKey('services'),
                    recentTransactions: kMockTransactions,
                    onSelect: _openServiceRoute,
                  )
                : Column(
                    key: const ValueKey('home'),
                    children: [
                      _buildAppBar(),
                      Expanded(
                        child: RefreshIndicator(
                          color: DP.green,
                          onRefresh: () =>
                              Future.delayed(const Duration(milliseconds: 600)),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 6, bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DPAppear(
                                  scaleFrom: 0.97,
                                  child: _buildBalanceCard(),
                                ),
                                const SizedBox(height: 20),
                                DPAppear(
                                  delay: const Duration(milliseconds: 120),
                                  child: _buildServicesGrid(),
                                ),
                                const SizedBox(height: 20),
                                DPAppear(
                                  delay: const Duration(milliseconds: 260),
                                  child: _HomeBanners(
                                    banners: [
                                      _HomeBannerData(
                                        title: 'International\nAirtime',
                                        subtitle:
                                            'Top up loved ones\' phones abroad in seconds.',
                                        image: DPAssets.bannerInternational,
                                        icon: DPIcons.globe,
                                        onTap: () => _openServiceRoute(
                                          '/international-airtime',
                                        ),
                                      ),
                                      _HomeBannerData(
                                        title: 'Never Miss\nYour Shows',
                                        subtitle:
                                            'Renew DSTV, GOtv & StarTimes instantly.',
                                        image: DPAssets.bannerCable,
                                        icon: DPIcons.tv,
                                        onTap: () =>
                                            _openServiceRoute('/cable'),
                                      ),
                                      _HomeBannerData(
                                        title: 'Refer a Friend',
                                        subtitle:
                                            'Invite friends and you both earn ₦200.',
                                        image: DPAssets.bannerRefer,
                                        icon: DPIcons.gift,
                                        onTap: () =>
                                            Navigator.pushNamed(context, '/referral'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                DPAppear(
                                  delay: const Duration(milliseconds: 360),
                                  child: _buildRecentTransactions(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: DPBottomNav(
        index: _selectedIndex,
        items: kDPTabs,
        onTap: _onNavTap,
        onCenter: () => Navigator.pushNamed(context, '/send-money'),
      ),
    );
  }
}

class _HomeBannerData {
  final String title;
  final String subtitle;
  final String image;
  final IconData icon;
  final VoidCallback onTap;
  const _HomeBannerData({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.icon,
    required this.onTap,
  });
}

/// Auto-sliding promo banners with page dots.
class _HomeBanners extends StatefulWidget {
  final List<_HomeBannerData> banners;
  const _HomeBanners({required this.banners});

  @override
  State<_HomeBanners> createState() => _HomeBannersState();
}

class _HomeBannersState extends State<_HomeBanners> {
  final PageController _page = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_page.hasClients || widget.banners.length < 2) return;
      final next = (_index + 1) % widget.banners.length;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: _page,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final b = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: DPPromoBanner(
                  title: b.title,
                  subtitle: b.subtitle,
                  image: b.image,
                  icon: b.icon,
                  onTap: b.onTap,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (i) {
            final on = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: on ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: on ? DP.green : DP.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
