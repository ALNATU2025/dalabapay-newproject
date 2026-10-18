// lib/presentation/screens/admin/admin_user_history_page.dart
// User History — UI only. Balance movement, transactions and admin activity.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminUserHistoryPage extends StatefulWidget {
  final AdminUser user;
  const AdminUserHistoryPage({super.key, required this.user});

  @override
  State<AdminUserHistoryPage> createState() => _AdminUserHistoryPageState();
}

class _AdminUserHistoryPageState extends State<AdminUserHistoryPage> {
  int _tab = 0;

  static const _activity = [
    ('APPROVED', 'Account approved by Adaeze Okafor', 4320),
    ('CREDIT', 'Bonus / Goodwill · ₦500.00', 2880),
    ('EDITED', 'Phone number updated', 1440),
    ('ACTIVATED', 'Account re-activated', 600),
  ];

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final txns = kAdminTxns
        .where((t) => t.userEmail == u.email)
        .toList(growable: false);
    final shown = txns.isEmpty ? kAdminTxns.take(4).toList() : txns;
    final credits =
        shown.where((t) => t.credit).fold<double>(0, (a, t) => a + t.amount);
    final debits =
        shown.where((t) => !t.credit).fold<double>(0, (a, t) => a + t.amount);

    return AdminScaffold(
      title: 'User History',
      breadcrumb: 'Admin / Users / ${u.name}',
      body: ListView(
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
                        DP.naira(u.balance),
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
          if (_tab == 0)
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
                for (final a in _activity)
                  DPListRow(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    leading: const DPIconBadge.blue(
                      Icons.admin_panel_settings_outlined,
                      size: 40,
                      iconSize: 19,
                    ),
                    title: a.$2,
                    subtitle: adminAgo(a.$3),
                    trailing: StatusPill(a.$1),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
