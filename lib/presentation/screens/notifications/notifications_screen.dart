// lib/presentation/screens/notifications/notifications_screen.dart
// Notifications: GET /api/notifications, mark read, mark all read and
// delete.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _Item {
  final String id;
  final String title;
  final String body;
  final String kind;
  final DateTime date;
  bool read;
  _Item(Map<String, dynamic> j)
      : id = str(j['id']),
        title = str(j['title']),
        body = str(j['body']),
        kind = str(j['kind']),
        date = parseDate(j['createdAt']),
        read = j['read'] == true;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_Item> _items = [];
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
      final r = asMap(await api.get('/api/notifications',
          query: {'page': more ? _page + 1 : 1, 'limit': 30}));
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(itemsOf(r).map(_Item.new));
        _page = more ? _page + 1 : 1;
        _hasMore = r['hasMore'] == true;
        _loading = false;
        _error = null;
      });
      Session.instance.unread.value = toInt(r['unread']);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _syncUnread() =>
      Session.instance.unread.value = _items.where((i) => !i.read).length;

  Future<void> _markAllRead() async {
    setState(() {
      for (final i in _items) {
        i.read = true;
      }
    });
    _syncUnread();
    await runWithFeedback(context, () => api.post('/api/notifications/read-all'));
  }

  (IconData, Color, Color, String) _style(String kind) => switch (kind) {
        'payment' => (DPIcons.checkCircle, DP.green, DP.mint, 'Payment Success'),
        'wallet' => (DPIcons.downLeft, DP.green, DP.mint, 'Wallet Funded'),
        'promo' => (DPIcons.gift, DP.amber, DP.amberBg, 'Promotion'),
        'commission' => (DPIcons.sparkle, DP.green, DP.mint, 'Earnings'),
        'referral' => (DPIcons.referral, DP.green, DP.mint, 'Referral'),
        'security' => (DPIcons.shieldCheck, DP.navyIcon, DP.blueTint, 'System'),
        _ => (DPIcons.bell, DP.navyIcon, DP.blueTint, 'General'),
      };

  void _open(_Item it) {
    if (!it.read) {
      setState(() => it.read = true);
      _syncUnread();
      api.patch('/api/notifications/${it.id}/read').catchError((_) => null);
    }
    final s = _style(it.kind);
    showModalBottomSheet(
      context: context,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  DPIconBadge(s.$1, color: s.$2, background: s.$3, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title, style: DP.title),
                        const SizedBox(height: 2),
                        Text(
                          '${s.$4} · ${dateTimeLabel(it.date)}',
                          style: DP.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(it.body, style: DP.body.copyWith(height: 1.5)),
              const SizedBox(height: 24),
              DPButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(_Item it) async {
    final ok = await dpDialog(
      context,
      title: 'Delete Notification',
      message:
          'Are you sure you want to delete this notification? This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      tone: DPTone.error,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final index = _items.indexOf(it);
    setState(() => _items.remove(it));
    _syncUnread();
    try {
      await api.delete('/api/notifications/${it.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(index.clamp(0, _items.length).toInt(), it));
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((i) => !i.read).length;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Notifications',
              actionLabel: unread > 0 ? 'Mark all read' : null,
              onAction: _markAllRead,
            ),
            Expanded(
              child: _loading
                  ? const SingleChildScrollView(child: DPLoading.list(rows: 6))
                  : _error != null && _items.isEmpty
                  ? DPLoadError(error: _error, onRetry: _load)
                  : _items.isEmpty
                  ? const Center(
                      child: DPEmptyState(
                        icon: DPIcons.bell,
                        title: 'No notifications yet',
                        message: 'Your notifications will appear here',
                      ),
                    )
                  : RefreshIndicator(
                      color: DP.green,
                      onRefresh: _load,
                      child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => i >= _items.length
                          ? Center(
                              child: DPTextLink(
                                label: 'Load more',
                                onTap: () => _load(more: true),
                              ),
                            )
                          : DPAppear(
                              delay: DPMotion.stagger(i),
                              child: _buildItem(_items[i]),
                            ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_Item it) {
    final s = _style(it.kind);
    return Dismissible(
      key: ObjectKey(it),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete(it);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: DP.redBg,
          borderRadius: BorderRadius.circular(DP.rLg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: DP.red),
      ),
      child: DPCard(
        color: it.read ? DP.surface : DP.blueTint.withValues(alpha: 0.5),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        onTap: () => _open(it),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DPIconBadge(s.$1, color: s.$2, background: s.$3, size: 42, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          it.title,
                          style: DP.bodyStrong.copyWith(
                            fontWeight:
                                it.read ? FontWeight.w600 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!it.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DP.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    it.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DP.caption.copyWith(color: DP.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeAgo(it.date),
                    style: DP.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
