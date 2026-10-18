// lib/presentation/screens/admin/admin_dashboard_screen.dart
// Admin console home — UI only. Stats, charts, recent transactions and a
// grid of every admin tool.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class _Tool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  const _Tool(this.title, this.subtitle, this.icon, this.color, this.route);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _period = 'Today';

  static const _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  static const _tools = [
    _Tool('Manage Users', 'View, edit, fund, approve', Icons.group_outlined, DP.green, '/admin/users'),
    _Tool('Transactions', 'All payments & export', Icons.receipt_long_outlined, DP.navyIcon, '/admin/transactions'),
    _Tool('Status Update', 'Change transaction status', Icons.update_rounded, DP.navyIcon, '/admin/status'),
    _Tool('Refund System', 'Disputes & refunds', Icons.currency_exchange_rounded, DP.red, '/admin/refunds'),
    _Tool('Fund Wallet', 'Credit a user wallet', Icons.account_balance_wallet_outlined, DP.green, '/admin/fund-wallet'),
    _Tool('Self Fund', 'Top up admin wallet', Icons.attach_money_rounded, DP.amber, '/admin/self-fund'),
    _Tool('Verify Payments', 'Check & credit transfers', Icons.verified_outlined, Color(0xFF0D9488), '/admin/verify'),
    _Tool('Send Notification', 'Message users', Icons.campaign_outlined, DP.navyIcon, '/admin/send-notification'),
    _Tool('Admin Alerts', 'Activity & warnings', Icons.notifications_active_outlined, DP.amber, '/admin/alerts'),
    _Tool('Admin Control', 'Roles & permissions', Icons.admin_panel_settings_outlined, DP.navyIcon, '/admin/control'),
    _Tool('VTpass Settings', 'Provider & services', Icons.api_rounded, DP.amber, '/admin/vtpass'),
    _Tool('Service Commission', 'Rates & revenue', Icons.trending_up_rounded, DP.green, '/admin/commission'),
    _Tool('Transaction Limits', 'Caps & maintenance', Icons.speed_rounded, DP.amber, '/admin/limits'),
  ];

  double get _factor => switch (_period) {
        'This Week' => 6.4,
        'This Month' => 27,
        'This Year' => 310,
        _ => 1,
      };

  @override
  Widget build(BuildContext context) {
    final revenue = kRevenue7d.last * _factor;
    final txns = (148 * _factor).round();
    final pending = kAdminTxns.where((t) => t.status == 'Pending').length;
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
          onTap: () => Navigator.pushNamed(context, '/admin/alerts'),
          badge: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: DP.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: () => Future.delayed(const Duration(milliseconds: 600)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            DPAppear(child: _welcome()),
            const SizedBox(height: 16),
            DPChipScroller(
              options: _periods,
              selected: _period,
              onSelect: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 14),
            AdminStatGrid(
              stats: [
                AdminStat(
                  label: 'Total Revenue',
                  value: DP.naira(revenue, decimals: false),
                  icon: Icons.payments_outlined,
                  color: DP.green,
                  sub: '+12.4%',
                ),
                AdminStat(
                  label: 'Total Users',
                  value: '${kAdminUsers.length * 124 + 8}',
                  icon: Icons.group_outlined,
                  sub: '+8',
                ),
                AdminStat(
                  label: 'Transactions',
                  value: '$txns',
                  icon: Icons.receipt_long_outlined,
                  color: DP.navyInk,
                  sub: '+5.1%',
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
              'Revenue Trend (Last 7 Days)',
              AdminBarChart(
                values: kRevenue7d,
                format: (v) => DP.naira(v, decimals: false),
              ),
            ),
            const SizedBox(height: 12),
            _chartCard(
              'User Growth (Last 7 Days)',
              AdminBarChart(
                values: kUsers7d.map((e) => e.toDouble()).toList(),
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
              onAction: () =>
                  Navigator.pushNamed(context, '/admin/transactions'),
            ),
            AdminListCard(
              children: [
                for (final t in kAdminTxns.take(5))
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
                          DP.naira(t.amount),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: DP.navyGradient,
        borderRadius: BorderRadius.circular(DP.rXl),
      ),
      child: Row(
        children: [
          const DPAvatar(name: 'Adaeze Okafor', size: 48),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Adaeze',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
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
            child: const Text(
              'SUPER ADMIN',
              style: TextStyle(
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
      itemCount: _tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 76,
      ),
      itemBuilder: (_, i) {
        final t = _tools[i];
        return DPAppear(
          delay: DPMotion.stagger(i),
          child: DPCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => Navigator.pushNamed(context, t.route),
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
