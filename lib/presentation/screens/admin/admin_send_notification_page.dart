// lib/presentation/screens/admin/admin_send_notification_page.dart
// Send Notification — UI only. Compose a message for all or selected users.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminSendNotificationPage extends StatefulWidget {
  const AdminSendNotificationPage({super.key});

  @override
  State<AdminSendNotificationPage> createState() =>
      _AdminSendNotificationPageState();
}

class _AdminSendNotificationPageState extends State<AdminSendNotificationPage> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _type = 'Announcement';
  bool _allUsers = true;
  final Set<String> _selected = {};
  bool _sending = false;
  int _sent = 1284;

  static const _types = [
    'Announcement',
    'Promotional',
    'Alert',
    'Transaction',
    'Commission',
    'Referral',
    'Welcome/Onboarding',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  int get _recipients => _allUsers
      ? kAdminUsers.where((u) => u.active).length
      : _selected.length;

  void _pickUsers() {
    var query = '';
    showAdminSheet(
      context,
      title: 'Select Users',
      builder: (ctx, setSheet) {
        final q = query.toLowerCase();
        final users = kAdminUsers
            .where((u) =>
                q.isEmpty ||
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSearch(
              hint: 'Search users...',
              onChanged: (v) => setSheet(() => query = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${_selected.length} selected', style: DP.caption),
                const Spacer(),
                DPTextLink(
                  label: 'Select All',
                  fontSize: 13,
                  onTap: () => setSheet(() {
                    _selected.addAll(users.map((u) => u.id));
                    setState(() {});
                  }),
                ),
                const SizedBox(width: 14),
                DPTextLink(
                  label: 'Clear All',
                  fontSize: 13,
                  color: DP.muted,
                  onTap: () => setSheet(() {
                    _selected.clear();
                    setState(() {});
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (users.isEmpty)
              const DPEmptyState(
                icon: Icons.group_outlined,
                title: 'No matching users',
              )
            else
              for (final u in users)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(u.id),
                  onChanged: (v) => setSheet(() {
                    if (v == true) {
                      _selected.add(u.id);
                    } else {
                      _selected.remove(u.id);
                    }
                    setState(() {});
                  }),
                  secondary: DPAvatar(name: u.name, size: 36),
                  title: Text(u.name, style: DP.bodyStrong),
                  subtitle: Text(u.email, style: DP.caption),
                ),
            const SizedBox(height: 12),
            DPButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
          ],
        );
      },
    );
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      dpSnack(context, 'Please enter a title', error: true);
      return;
    }
    if (_message.text.trim().isEmpty) {
      dpSnack(context, 'Please enter a message', error: true);
      return;
    }
    if (_recipients == 0) {
      dpSnack(context, 'No users selected', error: true);
      return;
    }
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    final n = _recipients;
    setState(() {
      _sending = false;
      _sent += n;
      _title.clear();
      _message.clear();
    });
    dpSnack(context, 'Notification sent to $n users', success: true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Send Notification',
      breadcrumb: 'Admin / Notifications',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Sent',
                value: '$_sent',
                icon: Icons.send_rounded,
                color: DP.green,
              ),
              const AdminStat(
                label: 'Success Rate',
                value: '98.6%',
                icon: Icons.insights_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const DPSectionHeader('Compose Notification'),
          const DPLabel('Type'),
          DPChipScroller(
            options: _types,
            selected: _type,
            onSelect: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 14),
          const DPLabel('Title'),
          DPField(
            controller: _title,
            hint: 'Enter a clear, descriptive title',
            maxLength: 60,
          ),
          const SizedBox(height: 10),
          const DPLabel('Message'),
          DPField(
            controller: _message,
            hint: 'Write your message...',
            maxLines: 4,
            maxLength: 240,
          ),
          const SizedBox(height: 14),
          const DPLabel('Recipient'),
          DPSegmented(
            options: const ['All Active Users', 'Select Users'],
            index: _allUsers ? 0 : 1,
            onChanged: (i) {
              setState(() => _allUsers = i == 0);
              if (i == 1) _pickUsers();
            },
          ),
          if (!_allUsers) ...[
            const SizedBox(height: 10),
            DPSelectField(
              value: _selected.isEmpty
                  ? null
                  : '${_selected.length} user${_selected.length == 1 ? '' : 's'} selected',
              hint: 'Select users to receive this notification',
              leading: const Icon(Icons.group_outlined,
                  size: 20, color: DP.navyIcon),
              onTap: _pickUsers,
            ),
          ],
          const SizedBox(height: 18),
          Text('Preview', style: DP.section),
          const SizedBox(height: 10),
          DPCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DPLogoMark(size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title.text.isEmpty
                                  ? 'Notification title'
                                  : _title.text,
                              style: DP.bodyStrong,
                            ),
                          ),
                          StatusPill(_type),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _message.text.isEmpty
                            ? 'Your message will appear here.'
                            : _message.text,
                        style: DP.caption.copyWith(color: DP.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: DPBottomAction(
        child: DPButton(
          label: _sending
              ? 'Sending notification...'
              : 'Send to $_recipients user${_recipients == 1 ? '' : 's'}',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _send,
        ),
      ),
    );
  }
}
