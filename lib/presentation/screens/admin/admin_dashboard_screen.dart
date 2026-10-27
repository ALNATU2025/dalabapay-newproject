// lib/presentation/screens/admin/admin_dashboard_screen.dart
// Admin console home: GET /api/admin/dashboard (stats, 7-day charts,
// recent transactions) and the tools this staff role may use.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class _Tool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String permission;
  const _Tool(this.title, this.subtitle, this.icon, this.color, this.route,
      this.permission);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _period = 'Today';

  /// Figures are per country (different currencies).
  String _country = 'NG';
  String _m(num v) => DP.moneyIn(v, str(_data['currency'], 'NGN'), decimals: false);
  Map<String, dynamic> _data = {};
  int _unreadAlerts = 0;
  bool _loading = true;
  Object? _error;

  static const _periods = ['Today', 'This Week', 'This Month', 'This Year'];
  static const _periodValues = {
    'Today': 'today',
    'This Week': 'week',
    'This Month': 'month',
    'This Year': 'year',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = asMap(await api.get('/api/admin/dashboard',
          query: {'period': _periodValues[_period], 'country': _country}));
      int unread = _unreadAlerts;
      if (adminCan('alerts:read')) {
        try {
          unread = toInt(asMap(await api.get('/api/admin/alerts',
              query: {'limit': 1}))['unread']);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _data = d;
        _unreadAlerts = unread;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) _load();
  }

  String _change(dynamic v) {
    final n = toDouble(v);
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}%';
  }

  static const _tools = [
    _Tool('KYC Review', 'Approve accounts & tier upgrades', Icons.verified_user_outlined, DP.green, '/admin/kyc', 'users:read'),
    _Tool('Manage Users', 'View, edit, fund, approve', Icons.group_outlined, DP.green, '/admin/users', 'users:read'),
    _Tool('Transactions', 'All payments & export', Icons.receipt_long_outlined, DP.navyIcon, '/admin/transactions', 'transactions:read'),
    _Tool('Bank Top-ups', 'Confirm customer transfers', Icons.account_balance_outlined, DP.green, '/admin/bank-topups', 'transactions:read'),
    _Tool('Status Update', 'Change transaction status', Icons.update_rounded, DP.navyIcon, '/admin/status', 'transactions:status'),
    _Tool('Refund System', 'Disputes & refunds', Icons.currency_exchange_rounded, DP.red, '/admin/refunds', 'disputes:manage'),
    _Tool('Fund Wallet', 'Credit a user wallet', Icons.account_balance_wallet_outlined, DP.green, '/admin/fund-wallet', 'wallet:fund'),
    _Tool('Self Fund', 'Top up admin wallet', Icons.attach_money_rounded, DP.amber, '/admin/self-fund', 'wallet:self-fund'),
    _Tool('Verify Payments', 'Check & credit transfers', Icons.verified_outlined, Color(0xFF0D9488), '/admin/verify', 'payments:verify'),
    _Tool('Send Notification', 'Message users', Icons.campaign_outlined, DP.navyIcon, '/admin/send-notification', 'notifications:send'),
    _Tool('Admin Alerts', 'Activity & warnings', Icons.notifications_active_outlined, DP.amber, '/admin/alerts', 'alerts:read'),
    _Tool('Admin Control', 'Roles & permissions', Icons.admin_panel_settings_outlined, DP.navyIcon, '/admin/control', 'roles:manage'),
    _Tool('Provider Settings', 'Bill provider & services', Icons.api_rounded, DP.amber, '/admin/vtpass', 'settings:read'),
    _Tool('Service Commission', 'Rates & revenue', Icons.trending_up_rounded, DP.green, '/admin/commission', 'commission:read'),
    _Tool('Transaction Limits', 'Caps & maintenance', Icons.speed_rounded, DP.amber, '/admin/limits', 'limits:read'),
    _Tool('Sierra Leone', 'Payment accounts & bonuses', Icons.flag_outlined, DP.green, '/admin/sl-funding', 'settings:read'),
    _Tool('Transfers & Cards', 'Cashwyre pricing', Icons.credit_card_rounded, DP.navyIcon, '/admin/cashwyre', 'settings:read'),
  ];

  List<_Tool> get _allowedTools =>
      _tools.where((t) => adminCan(t.permission)).toList();

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
    if (user == null || !user.isAdmin) {
      return AdminScaffold(
        title: 'Admin Dashboard',
        breadcrumb: 'Admin / Dashboard',
        body: const DPEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Staff only',
          message: 'Your account doesn\'t have access to the admin console.',
        ),
      );
    }
    if (_loading) {
      return const AdminScaffold(
        title: 'Admin Dashboard',
        breadcrumb: 'Admin / Dashboard',
        body: DPLoading(),
      );
    }
    if (_error != null && _data.isEmpty) {
      return AdminScaffold(
        title: 'Admin Dashboard',
        breadcrumb: 'Admin / Dashboard',
        body: DPLoadError(error: _error, onRetry: _load),
      );
    }
    final revenue = toDouble(_data['revenue']);
    final txns = toInt(_data['transactions']);
    final pending = toInt(_data['pending']);
    final volume7d = asList(_data['volume7d']).map((d) => toDouble(d['value'])).toList();
    final users7d = asList(_data['users7d']).map((d) => toDouble(d['value'])).toList();
    final recent = asList(_data['recentTransactions']).map(AdminTxn.fromJson).toList();
    return AdminScaffold(
      title: 'Admin Dashboard',
      breadcrumb: 'Admin / Dashboard',
      actions: [
        DPIconSquare(
          icon: DPIcons.bell,
          size: 40,
          color: DP.navyInk,
          background: Colors.transparent,
          semanticLabel: 'Admin alerts',
          onTap: () => _open('/admin/alerts'),
          badge: _unreadAlerts > 0
              ? Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: DP.red,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
      ],
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            DPAppear(child: _welcome()),
            const SizedBox(height: 16),
            DPSegmented(
              options: const ['Nigeria (₦)', 'Sierra Leone (Le)'],
              index: _country == 'SL' ? 1 : 0,
              onChanged: (i) {
                setState(() => _country = i == 1 ? 'SL' : 'NG');
                _load();
              },
            ),
            const SizedBox(height: 12),
            DPChipScroller(
              options: _periods,
              selected: _period,
              onSelect: (p) {
                setState(() => _period = p);
                _load();
              },
            ),
            const SizedBox(height: 14),
            AdminStatGrid(
              stats: [
                AdminStat(
                  label: 'Revenue',
                  value: _m(revenue),
                  icon: Icons.payments_outlined,
                  color: DP.green,
                  sub: _change(_data['revenueChange']),
                ),
                AdminStat(
                  label: 'Total Users',
                  value: '${toInt(_data['totalUsers'])}',
                  icon: Icons.group_outlined,
                  sub: '+${toInt(_data['newUsers'])}',
                ),
                AdminStat(
                  label: 'Sales Volume',
                  value: _m(toDouble(_data['volume'])),
                  icon: Icons.receipt_long_outlined,
                  color: DP.navyInk,
                  sub: '$txns txns · ${_change(_data['volumeChange'])}',
                ),
                AdminStat(
                  label: 'Pending',
                  value: '$pending',
                  icon: DPIcons.pending,
                  color: DP.amber,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _chartCard(
              'Sales Volume (Last 7 Days)',
              AdminBarChart(
                values: volume7d.isEmpty ? List.filled(7, 0.0) : volume7d,
                format: _m,
              ),
            ),
            const SizedBox(height: 12),
            _chartCard(
              'User Growth (Last 7 Days)',
              AdminBarChart(
                values: users7d.isEmpty ? List.filled(7, 0.0) : users7d,
                format: (v) => '${v.toInt()} new users',
                color: DP.navyIcon,
              ),
            ),
            const SizedBox(height: 22),
            const DPSectionHeader('Admin Tools'),
            _toolsGrid(),
            const SizedBox(height: 22),
            DPSectionHeader(
              'Recent Transactions',
              actionLabel: 'See All',
              onAction: adminCan('transactions:read')
                  ? () => _open('/admin/transactions')
                  : null,
            ),
            if (recent.isEmpty)
              const DPCard(
                child: DPEmptyState(
                  icon: DPIcons.receipt,
                  title: 'No transactions yet',
                ),
              ),
            if (recent.isNotEmpty)
            AdminListCard(
              children: [
                for (final t in recent.take(8))
                  DPListRow(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    leading: DPIconBadge(
                      t.credit ? DPIcons.downLeft : DPIcons.upRight,
                      size: 40,
                      iconSize: 19,
                      color: t.credit ? DP.green : DP.navyIcon,
                      background: t.credit ? DP.mint : DP.blueTint,
                    ),
                    title: '${t.userName} · ${t.service}',
                    subtitle: '${adminAgo(t.minutesAgo)} · ${t.ref}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          t.money(t.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DP.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        StatusPill(t.status),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    final user = Session.instance.user;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: DP.navyGradient,
        borderRadius: BorderRadius.circular(DP.rXl),
      ),
      child: Row(
        children: [
          DPAvatar(name: user?.fullName ?? '', size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?.firstName ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Here\'s what\'s happening on Dalabapay.',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              roleLabel(user?.role ?? '').toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7FE3BC),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return DPCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DP.bodyStrong),
          const SizedBox(height: 14),
          chart,
        ],
      ),
    );
  }

  Widget _toolsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allowedTools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 76,
      ),
      itemBuilder: (_, i) {
        final t = _allowedTools[i];
        return DPAppear(
          delay: DPMotion.stagger(i),
          child: DPCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => _open(t.route),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(t.icon, size: 20, color: t.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DP.bodyStrong.copyWith(fontSize: 13.5),
                      ),
                      Text(
                        t.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DP.caption.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
