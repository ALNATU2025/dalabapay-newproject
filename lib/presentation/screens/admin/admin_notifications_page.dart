// lib/presentation/screens/admin/admin_notifications_page.dart
// Admin Alerts — UI only. Activity feed with severity and filters.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  String _filter = 'All';
  static const _filters = [
    'All',
    'New Users',
    'Wallet',
    'Duplicates',
    'Suspicious',
    'Status Change',
  ];

  String _typeFor(String f) => switch (f) {
        'New Users' => 'new_user',
        'Wallet' => 'wallet',
        'Duplicates' => 'duplicate',
        'Suspicious' => 'suspicious',
        'Status Change' => 'status',
        _ => '',
      };

  (IconData, Color) _style(AdminAlert a) => switch (a.type) {
        'new_user' => (Icons.person_add_alt_1_rounded, DP.navyIcon),
        'wallet' => (DPIcons.wallet, DP.green),
        'duplicate' => (Icons.copy_all_rounded, DP.amber),
        'suspicious' => (Icons.gpp_maybe_outlined, DP.red),
        _ => (Icons.update_rounded, DP.navyIcon),
      };

  void _open(AdminAlert a) {
    setState(() => a.read = true);
    final s = _style(a);
    showAdminSheet(
      context,
      title: a.title,
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DPIconBadge(s.$1,
                  color: s.$2, background: s.$2.withValues(alpha: 0.12)),
              const SizedBox(width: 12),
              Expanded(child: Text(a.body, style: DP.body)),
            ],
          ),
          const SizedBox(height: 14),
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                DPSummaryRow('Severity', a.severity.toUpperCase(),
                    valueColor: StatusPill.colorFor(a.severity)),
                DPSummaryRow('Type', a.type.replaceAll('_', ' ')),
                DPSummaryRow('Time', adminAgo(a.minutesAgo)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DPButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _typeFor(_filter);
    final items =
        kAdminAlerts.where((a) => t.isEmpty || a.type == t).toList();
    final unread = kAdminAlerts.where((a) => !a.read).length;
    return AdminScaffold(
      title: 'Admin Alerts',
      breadcrumb: 'Admin / Alerts',
      actions: [
        if (unread > 0)
          DPTextLink(
            label: 'Mark all read',
            fontSize: 13,
            onTap: () => setState(() {
              for (final a in kAdminAlerts) {
                a.read = true;
              }
            }),
          ),
        const SizedBox(width: 8),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          DPChipScroller(
            options: _filters,
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const DPEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: 'New activities will appear here',
            )
          else
            for (final a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DPCard(
                  color: a.read ? DP.surface : DP.blueTint.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(14),
                  onTap: () => _open(a),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DPIconBadge(
                        _style(a).$1,
                        size: 40,
                        iconSize: 19,
                        color: _style(a).$2,
                        background: _style(a).$2.withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(a.title, style: DP.bodyStrong),
                                ),
                                if (a.severity != 'info')
                                  StatusPill(a.severity.toUpperCase()),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              a.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DP.caption.copyWith(color: DP.inkSoft),
                            ),
                            const SizedBox(height: 5),
                            Text(adminAgo(a.minutesAgo),
                                style: DP.caption.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
