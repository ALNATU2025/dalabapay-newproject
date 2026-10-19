// lib/presentation/screens/admin/admin_notifications_page.dart
// Admin Alerts: activity feed with severity and filters
// (GET /api/admin/alerts, mark read / mark all read).
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
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
    'Disputes',
    'Provider',
  ];

  List<AdminAlert> _items = [];
  int _unread = 0;
  bool _loading = true;
  bool _hasMore = false;
  int _page = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    try {
      final t = _typeFor(_filter);
      final r = asMap(await api.get('/api/admin/alerts', query: {
        if (t.isNotEmpty) 'type': t,
        'page': more ? _page + 1 : 1,
      }));
      if (!mounted) return;
      final list = itemsOf(r).map(AdminAlert.fromJson).toList();
      setState(() {
        _items = more ? [..._items, ...list] : list;
        _page = more ? _page + 1 : 1;
        _hasMore = r['hasMore'] == true;
        _unread = toInt(r['unread']);
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

  String _typeFor(String f) => switch (f) {
        'New Users' => 'new_user',
        'Wallet' => 'wallet',
        'Duplicates' => 'duplicate',
        'Suspicious' => 'suspicious',
        'Status Change' => 'status',
        'Disputes' => 'dispute',
        'Provider' => 'provider',
        _ => '',
      };

  (IconData, Color) _style(AdminAlert a) => switch (a.type) {
        'new_user' => (Icons.person_add_alt_1_rounded, DP.navyIcon),
        'wallet' => (DPIcons.wallet, DP.green),
        'duplicate' => (Icons.copy_all_rounded, DP.amber),
        'suspicious' => (Icons.gpp_maybe_outlined, DP.red),
        'dispute' => (Icons.gavel_rounded, DP.red),
        'provider' => (Icons.api_rounded, DP.amber),
        _ => (Icons.update_rounded, DP.navyIcon),
      };

  void _open(AdminAlert a) {
    if (!a.read) {
      setState(() {
        a.read = true;
        _unread = (_unread - 1).clamp(0, 1 << 30).toInt();
      });
      api.patch('/api/admin/alerts/${a.id}/read').catchError((_) => null);
    }
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
                DPSummaryRow('Time', dateTimeLabel(a.date)),
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
    final items = _items;
    final unread = _unread;
    return AdminScaffold(
      title: 'Admin Alerts',
      breadcrumb: 'Admin / Alerts',
      actions: [
        if (unread > 0)
          DPTextLink(
            label: 'Mark all read',
            fontSize: 13,
            onTap: () async {
              setState(() {
                for (final a in _items) {
                  a.read = true;
                }
                _unread = 0;
              });
              await runWithFeedback(
                  context, () => api.post('/api/admin/alerts/read-all'));
            },
          ),
        const SizedBox(width: 8),
      ],
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: _load,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          DPChipScroller(
            options: _filters,
            selected: _filter,
            onSelect: (f) {
              setState(() => _filter = f);
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (_loading)
            const DPLoading.list(rows: 6, padding: 0)
          else if (_error != null && items.isEmpty)
            DPLoadError(error: _error, onRetry: _load)
          else if (items.isEmpty)
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
                            Text(agoOf(a.date),
                                style: DP.caption.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (_hasMore)
            Center(
              child: DPTextLink(
                label: 'Load more',
                onTap: () => _load(more: true),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
