// lib/presentation/screens/admin/admin_send_notification_page.dart
// Send Notification: compose a message for all active users or selected
// ones (POST /api/admin/broadcasts). It appears in their Notifications.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'admin_models.dart';
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
  int _sent = 0;
  int _broadcasts = 0;
  int _activeUsers = 0;
  List<Map<String, dynamic>> _recent = [];

  static const _typeValues = {
    'Announcement': 'announcement',
    'Promotional': 'promotional',
    'Alert': 'alert',
    'Transaction': 'transaction',
    'Commission': 'commission',
    'Referral': 'referral',
    'Welcome/Onboarding': 'welcome',
    'Custom': 'custom',
  };

  Future<void> _loadStats() async {
    try {
      final r = asMap(await api.get('/api/admin/broadcasts'));
      if (!mounted) return;
      setState(() {
        _sent = toInt(r['sent']);
        _broadcasts = toInt(r['broadcasts']);
        _activeUsers = toInt(r['activeUsers']);
        _recent = asList(r['recent']);
      });
    } catch (_) {}
  }

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
    _loadStats();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  int get _recipients => _allUsers ? _activeUsers : _selected.length;

  void _pickUsers() {
    List<AdminUser> users = [];
    var loading = true;
    Timer? debounce;
    StateSetter? sheetSetter;

    Future<void> search(String q) async {
      try {
        final r = await api.get('/api/admin/users',
            query: {'q': q.trim(), 'filter': 'active', 'limit': 50});
        users = itemsOf(r).map(AdminUser.fromJson).toList();
      } catch (_) {
        users = [];
      }
      loading = false;
      sheetSetter?.call(() {});
    }

    search('');
    showAdminSheet(
      context,
      title: 'Select Users',
      builder: (ctx, setSheet) {
        sheetSetter = setSheet;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSearch(
              hint: 'Search users...',
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 400), () => search(v));
              },
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
            if (loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: DP.green)),
              )
            else if (users.isEmpty)
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
    Map<String, dynamic> r;
    try {
      r = asMap(await api.post('/api/admin/broadcasts', {
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'type': _typeValues[_type],
        'audience': _allUsers ? 'all' : 'selected',
        if (!_allUsers) 'userIds': _selected.toList(),
      }));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    final n = toInt(r['sent']);
    setState(() {
      _sending = false;
      _title.clear();
      _message.clear();
      _selected.clear();
    });
    dpSnack(context, 'Notification sent to $n user${n == 1 ? '' : 's'}', success: true);
    _loadStats();
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
                label: 'Delivered',
                value: '$_sent',
                icon: Icons.send_rounded,
                color: DP.green,
              ),
              AdminStat(
                label: 'Broadcasts',
                value: '$_broadcasts',
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
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 22),
            const DPSectionHeader('Recently sent'),
            AdminListCard(
              children: [
                for (final b in _recent.take(10))
                  DPListRow(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    subtitleMaxLines: 2,
                    leading: const DPIconBadge.blue(Icons.campaign_outlined,
                        size: 40, iconSize: 19),
                    title: str(b['title']),
                    subtitle:
                        '${toInt(b['recipients'])} recipients · ${str(b['sender'], 'Admin')} · ${agoOf(parseDate(b['createdAt']))}',
                  ),
              ],
            ),
          ],
        ],
      ),
      bottom: DPBottomAction(
        child: DPButton(
          label: _sending
              ? 'Sending notification...'
              : 'Send to $_recipients user${_recipients == 1 ? '' : 's'}',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ),
    );
  }
}
