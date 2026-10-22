// lib/presentation/screens/dashboard/dashboard_screen.dart
// Home: balance card, essential services, promo banners, recent
// transactions (GET /api/me/home), Services tab and bottom menu.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
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
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;
  String? _loadError;
  String? _maintenance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await api.get('/api/me/home'));
      final u = data['user'];
      if (u is Map) Session.instance.setUser(u.cast<String, dynamic>());
      Session.instance.unread.value = toInt(data['unreadNotifications']);
      if (!mounted) return;
      setState(() {
        _recent = asList(data['recentTransactions']);
        _maintenance = data['maintenance']?.toString();
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = errorMessage(e);
      });
    }
  }

  /// Opens a page and refreshes the home data when it closes.
  Future<Object?> _go(String route, {Object? arguments}) async {
    final r = await Navigator.pushNamed(context, route, arguments: arguments);
    if (mounted) _load();
    return r;
  }

  bool get _sl => Session.instance.isSierraLeone;

  static const List<DPService> _slBillGroup = [
    DPService('EDSA', DPIcons.bolt, '/sl/electricity', DPAssets.svcElectricity, DP.green),
    DPService('Airtime', DPIcons.smartphone, '/sl/airtime', DPAssets.svcAirtime, DP.navyIcon),
    DPService('Data', DPIcons.wifi, '/sl/data', DPAssets.svcData, DP.navyIcon),
  ];
  static const List<DPService> _slTvGroup = [
    DPService('DSTV', DPIcons.tv, '/sl/cable', DPAssets.dstv, DP.navyIcon),
    DPService('GOtv', DPIcons.tv, '/sl/cable', DPAssets.gotv, DP.green),
    DPService('StarTimes', DPIcons.tv, '/sl/cable', DPAssets.startimes, DP.amber),
  ];

  List<DPService> get _billGroup => _sl ? _slBillGroup : _payBillGroup;
  List<DPService> get _tvGroup => _sl ? _slTvGroup : _payTvGroup;

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
        _go('/wallet');
        return;
      case '/wallet:send':
        _go('/send-money');
        return;
      default:
        _go(route);
    }
  }

  /// Transactions and Profile are pushed pages with their own bottom menu.
  /// When they close they say which tab to show next.
  Future<void> _pushTab(String route) async {
    final result = await _go(route);
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
        _go('/send-money');
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
                        child: ClipOval(
                          child: DPAvatar(
                              name: Session.instance.user?.fullName ?? '',
                              size: 44),
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
                    onTap: () => _go('/notifications'),
                    badge: Session.instance.unread.value > 0
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
            'Hello, ${Session.instance.user?.firstName ?? 'there'}!',
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
    final user = Session.instance.user;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DPLayout.gutter(context)),
      child: DPBalanceCard(
        balance: user?.balance ?? 0,
        earnings: user?.commissionBalance ?? 0,
        visible: _isBalanceVisible,
        onToggleVisible: () =>
            setState(() => _isBalanceVisible = !_isBalanceVisible),
        onEarnings: () => _go('/commission'),
        actions: [
          DPQuickAction(DPIcons.plus, 'Add Money', () => _go('/wallet')),
          DPQuickAction(DPIcons.upRight, 'Send', () => _go('/send-money')),
          DPQuickAction(
            DPIcons.receipt,
            'Pay Bills',
            () => _showServiceGroup(
              'Pay Bill',
              _sl ? 'EDSA, airtime and data' : 'Electricity, airtime and data',
              _billGroup,
            ),
          ),
          DPQuickAction(DPIcons.history, 'History', () => _onNavTap(1)),
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
                  _sl ? 'EDSA, airtime and data' : 'Electricity, airtime and data',
                  _billGroup,
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
                  _tvGroup,
                ),
              ),
              if (_sl)
                DPServiceTile(
                  icon: DPIcons.bolt,
                  label: 'EDSA Electricity',
                  image: DPAssets.svcElectricity,
                  color: DP.green,
                  onTap: () => _openServiceRoute('/sl/electricity'),
                )
              else
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

  Widget _buildNotices() {
    final user = Session.instance.user;
    final notices = <Widget>[
      if (_maintenance != null && _maintenance!.isNotEmpty)
        DPBanner(_maintenance!, tone: DPTone.warning, icon: DPIcons.info),
      if (user != null && !user.isApproved)
        const DPBanner(
          'Your account is waiting for approval. You can look around, but payments are paused until it\'s approved.',
          tone: DPTone.warning,
          icon: DPIcons.info,
        ),
      if (user != null && !user.pinSet)
        GestureDetector(
          onTap: () => _go('/pin-setup'),
          child: const DPBanner(
            'Create your payment PIN to start paying. Tap here.',
            tone: DPTone.info,
            icon: DPIcons.lock,
          ),
        ),
    ];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          for (final n in notices) ...[n, const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final list = _recent.take(5).toList();
    Widget content;
    if (_loading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            DPSkeleton(height: 44),
            SizedBox(height: 12),
            DPSkeleton(height: 44),
          ],
        ),
      );
    } else if (_loadError != null && list.isEmpty) {
      content = DPEmptyState(
        icon: DPIcons.alert,
        title: 'Couldn\'t load your activity',
        message: _loadError,
        actionLabel: 'Try again',
        onAction: _load,
      );
    } else if (list.isEmpty) {
      content = DPEmptyState(
        icon: DPIcons.receipt,
        title: 'No transactions yet',
        message: 'Add money to your wallet to start paying bills.',
        actionLabel: 'Add Money',
        animated: true,
        onAction: () => _go('/wallet'),
      );
    } else {
      content = Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, color: DP.borderSoft),
            TransactionRow(tx: list[i]),
          ],
        ],
      );
    }
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
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final user = Session.instance.user;
    final items = <(IconData, String, String?)>[
      (Icons.apps_rounded, 'All Services', null),
      if (user?.isAdmin ?? false)
        (Icons.admin_panel_settings_outlined, 'Admin Console', '/admin'),
      (DPIcons.shieldCheck, 'Transaction Validation', '/transaction-validation'),
      (Icons.gavel_rounded, 'My Disputes', '/user-disputes'),
      (DPIcons.referral, 'Refer & Earn', '/referral'),
      // BVN/NIN checks are Nigerian.
      if (!_sl) (DPIcons.badge, 'Verify Identity (KYC)', '/kyc'),
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
            child: Row(
              children: [
                DPAvatar(name: user?.fullName ?? '', size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                        _go(route);
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
                  onTap: () async {
                    await Session.instance.logout();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Version 1.0.0', style: DP.caption),
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
    return ListenableBuilder(
      listenable: Listenable.merge([Session.instance, Session.instance.unread]),
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
                    recentTransactions: _recent,
                    onSelect: _openServiceRoute,
                  )
                : Column(
                    key: const ValueKey('home'),
                    children: [
                      _buildAppBar(),
                      Expanded(
                        child: RefreshIndicator(
                          color: DP.green,
                          onRefresh: _load,
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
                                _buildNotices(),
                                DPAppear(
                                  delay: const Duration(milliseconds: 120),
                                  child: _buildServicesGrid(),
                                ),
                                const SizedBox(height: 20),
                                DPAppear(
                                  delay: const Duration(milliseconds: 260),
                                  child: _HomeBanners(
                                    banners: _sl
                                        ? [
                                            _HomeBannerData(
                                              title: 'EDSA Units\nin Seconds',
                                              subtitle: 'Buy prepaid electricity and get your token instantly.',
                                              image: DPAssets.bannerBills,
                                              icon: DPIcons.bolt,
                                              onTap: () => _openServiceRoute('/sl/electricity'),
                                            ),
                                            _HomeBannerData(
                                              title: 'Never Miss\nYour Shows',
                                              subtitle: 'Renew DStv, GOtv & StarTimes in Leones.',
                                              image: DPAssets.bannerCable,
                                              icon: DPIcons.tv,
                                              onTap: () => _openServiceRoute('/sl/cable'),
                                            ),
                                            _HomeBannerData(
                                              title: 'Refer a Friend',
                                              subtitle: 'Invite friends in Sierra Leone to Dalabapay.',
                                              image: DPAssets.bannerRefer,
                                              icon: DPIcons.gift,
                                              onTap: () => _go('/referral'),
                                            ),
                                          ]
                                        : [
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
                                            _go('/referral'),
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
        onCenter: () => _go('/send-money'),
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
