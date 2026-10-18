// lib/presentation/screens/notifications/notifications_screen.dart
// UI only — sample notifications; read / delete change the list on screen.
import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _Item {
  final MockNotification n;
  bool read;
  _Item(this.n) : read = n.read;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_Item> _items = [for (final n in kMockNotifications) _Item(n)];

  (IconData, Color, Color, String) _style(String kind) => switch (kind) {
        'payment' => (DPIcons.checkCircle, DP.green, DP.mint, 'Payment Success'),
        'wallet' => (DPIcons.downLeft, DP.green, DP.mint, 'Wallet Funded'),
        'promo' => (DPIcons.gift, DP.amber, DP.amberBg, 'Promotion'),
        'security' => (DPIcons.shieldCheck, DP.navyIcon, DP.blueTint, 'System'),
        _ => (DPIcons.bell, DP.navyIcon, DP.blueTint, 'General'),
      };

  void _open(_Item it) {
    setState(() => it.read = true);
    final s = _style(it.n.kind);
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
                        Text(it.n.title, style: DP.title),
                        const SizedBox(height: 2),
                        Text(
                          '${s.$4} · ${mockDateTime(DateTime.now().subtract(it.n.ago))}',
                          style: DP.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(it.n.body, style: DP.body.copyWith(height: 1.5)),
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
    if (ok == true && mounted) setState(() => _items.remove(it));
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
              onAction: () => setState(() {
                for (final i in _items) {
                  i.read = true;
                }
              }),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: DPEmptyState(
                        icon: DPIcons.bell,
                        title: 'No notifications yet',
                        message: 'Your notifications will appear here',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => DPAppear(
                        delay: DPMotion.stagger(i),
                        child: _buildItem(_items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_Item it) {
    final s = _style(it.n.kind);
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
                          it.n.title,
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
                    it.n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DP.caption.copyWith(color: DP.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mockTimeAgo(DateTime.now().subtract(it.n.ago)),
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
