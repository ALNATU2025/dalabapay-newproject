// lib/presentation/screens/admin/admin_user_history_page.dart
// User History: GET /api/admin/users/:id/history — balance movement,
// transactions and the admin activity log for this user.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminUserHistoryPage extends StatefulWidget {
  final AdminUser user;
  const AdminUserHistoryPage({super.key, required this.user});

  @override
  State<AdminUserHistoryPage> createState() => _AdminUserHistoryPageState();
}

class _AdminUserHistoryPageState extends State<AdminUserHistoryPage> {
  int _tab = 0;

  static String _actionLabel(String a) => switch (a) {
        'user.approve' => 'APPROVED',
        'user.update' => 'EDITED',
        'wallet.credit' => 'CREDIT',
        'wallet.debit' => 'DEBIT',
        'wallet.self_fund' => 'SELF FUND',
        'pin.unlock' => 'PIN UNLOCK',
        'pin.reset' => 'PIN RESET',
        'role.change' => 'ROLE',
        'transaction.status' => 'STATUS',
        'transaction.refund' => 'REFUND',
        'transaction.requery' => 'REQUERY',
        'payment.manual' => 'MANUAL CREDIT',
        'payment.verify' => 'VERIFIED',
        'limits.user' => 'LIMITS',
        _ => a.split('.').last.toUpperCase(),
      };

  static String _actionText(Map<String, dynamic> a) {
    final d = asMap(a['details']);
    final by = str(asMap(a['actor'])['fullName'], 'an admin');
    final what = switch (str(a['action'])) {
      'wallet.credit' || 'wallet.debit' =>
        '${d['reason'] ?? ''} · ${DP.naira(toDouble(d['amount']))}',
      'transaction.status' => 'Status ${d['from']} → ${d['to']}',
      'role.change' => 'Role ${roleLabel(str(d['from']))} → ${roleLabel(str(d['to']))}',
      'transaction.refund' => 'Refunded ${DP.naira(toDouble(d['amount']))}',
      'payment.manual' => 'Manual credit ${DP.naira(toDouble(d['amount']))}',
      'user.update' => 'Profile updated',
      _ => _actionLabel(str(a['action'])).toLowerCase(),
    };
    return '$what · by $by';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return AdminScaffold(
      title: 'User History',
      breadcrumb: 'Admin / Users / ${u.name}',
      body: AsyncView<Map<String, dynamic>>(
        load: () async =>
            asMap(await api.get('/api/admin/users/${u.id}/history')),
        builder: (context, d, reload) => _body(u, d, reload),
      ),
    );
  }

  Widget _body(AdminUser u, Map<String, dynamic> d, Future<void> Function() reload) {
    final shown = asList(d['transactions']).map(AdminTxn.fromJson).toList();
    final activity = asList(d['activity']);
    final credits = toDouble(d['credits']);
    final debits = toDouble(d['debits']);
    final balance = toDouble(asMap(d['user'])['balance']);
    return RefreshIndicator(
      color: DP.green,
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: DP.greenGradient,
              borderRadius: BorderRadius.circular(DP.rXl),
            ),
            child: Row(
              children: [
                DPAvatar(name: u.name, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Current Wallet Balance',
                        style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                      ),
                      Text(
                        DP.naira(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Credits',
                value: DP.naira(credits, decimals: false),
                icon: DPIcons.downLeft,
                color: DP.green,
              ),
              AdminStat(
                label: 'Debits',
                value: DP.naira(debits, decimals: false),
                icon: DPIcons.upRight,
                color: DP.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          DPSegmented(
            options: const ['Transactions', 'Admin Activity'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 14),
          if (_tab == 0 && shown.isEmpty)
            const DPEmptyState(icon: DPIcons.receipt, title: 'No transactions yet')
          else if (_tab == 1 && activity.isEmpty)
            const DPEmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'No admin activity on this account',
            )
          else if (_tab == 0)
            AdminListCard(
              children: [
                for (final t in shown)
                  DPListRow(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    leading: DPIconBadge(
                      t.credit ? DPIcons.downLeft : DPIcons.upRight,
                      size: 40,
                      iconSize: 19,
                      color: t.credit ? DP.green : DP.red,
                      background: t.credit ? DP.mint : DP.redBg,
                    ),
                    title: t.description,
                    subtitle: '${t.ref} · ${adminAgo(t.minutesAgo)}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${t.credit ? '+' : '-'}${DP.naira(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.credit ? DP.green : DP.red,
                          ),
                        ),
                        const SizedBox(height: 3),
                        StatusPill(t.status),
                      ],
                    ),
                  ),
              ],
            )
          else
            AdminListCard(
              children: [
                for (final a in activity)
                  DPListRow(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    subtitleMaxLines: 2,
                    leading: const DPIconBadge.blue(
                      Icons.admin_panel_settings_outlined,
                      size: 40,
                      iconSize: 19,
                    ),
                    title: _actionText(a),
                    subtitle: agoOf(parseDate(a['createdAt'])),
                    trailing: StatusPill(_actionLabel(str(a['action']))),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
