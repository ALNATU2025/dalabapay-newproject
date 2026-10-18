// lib/presentation/screens/admin/admin_transaction_limits_page.dart
// Transaction Limits — UI only. System default caps per service, per-user
// overrides, maintenance mode and service switches.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class _Limit {
  double? perTxn; // null = unlimited
  double? daily;
  _Limit(this.perTxn, this.daily);
  _Limit copy() => _Limit(perTxn, daily);
}

class AdminTransactionLimitsPage extends StatefulWidget {
  const AdminTransactionLimitsPage({super.key});

  @override
  State<AdminTransactionLimitsPage> createState() =>
      _AdminTransactionLimitsPageState();
}

class _AdminTransactionLimitsPageState
    extends State<AdminTransactionLimitsPage> {
  int _tab = 0;
  bool _maintenance = false;
  bool _saving = false;
  final _message = TextEditingController(
    text: 'Some services are paused for maintenance. Please check back soon.',
  );

  static const _serviceNames = [
    'Airtime',
    'Data',
    'Electricity',
    'Cable TV',
    'Education',
    'Insurance',
    'International Airtime',
    'Money Transfer',
  ];

  final Map<String, _Limit> _defaults = {
    'Airtime': _Limit(50000, 200000),
    'Data': _Limit(50000, 200000),
    'Electricity': _Limit(500000, 1000000),
    'Cable TV': _Limit(200000, 500000),
    'Education': _Limit(100000, 300000),
    'Insurance': _Limit(100000, 300000),
    'International Airtime': _Limit(50000, 150000),
    'Money Transfer': _Limit(500000, 2000000),
  };
  final Map<String, bool> _enabled = {for (final s in _serviceNames) s: true};
  final Map<String, Map<String, _Limit>> _userLimits = {};

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String _fmt(double? v) =>
      v == null ? 'UNLIMITED' : DP.naira(v, decimals: false);

  void _edit(String service, _Limit limit, {String? forUser}) {
    final per = TextEditingController(
        text: limit.perTxn?.toStringAsFixed(0) ?? '');
    final day =
        TextEditingController(text: limit.daily?.toStringAsFixed(0) ?? '');
    showAdminSheet(
      context,
      title: forUser == null ? '$service limits' : '$service · $forUser',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DPLabel('Per Transaction (₦)'),
          DPField(
            controller: per,
            hint: 'Leave empty for unlimited',
            prefixText: '₦  ',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 14),
          const DPLabel('Daily Cap (₦)'),
          DPField(
            controller: day,
            hint: 'Leave empty for unlimited',
            prefixText: '₦  ',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 18),
          DPButton(
            label: 'Save Limits',
            onPressed: () {
              setState(() {
                limit.perTxn = double.tryParse(per.text);
                limit.daily = double.tryParse(day.text);
              });
              Navigator.pop(ctx);
              dpSnack(context, '$service limits saved', success: true);
            },
          ),
          if (forUser != null) ...[
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Use system default',
              color: DP.muted,
              onPressed: () {
                setState(() {
                  final copy = _defaults[service]!;
                  limit
                    ..perTxn = copy.perTxn
                    ..daily = copy.daily;
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveDefaults() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _saving = false);
    dpSnack(context, 'System defaults saved', success: true);
  }

  void _pickUser() async {
    final u = await dpPickFromList<AdminUser>(
      context,
      title: 'Select a User',
      items: kAdminUsers,
      labelOf: (u) => u.name,
      subtitleOf: (u) => '${u.email} · ${u.phone}',
      leadingOf: (u) => DPAvatar(name: u.name, size: 36),
      searchable: true,
    );
    if (u == null || !mounted) return;
    _userLimits.putIfAbsent(
      u.id,
      () => {for (final e in _defaults.entries) e.key: e.value.copy()},
    );
    _openUserLimits(u);
  }

  void _openUserLimits(AdminUser u) {
    final limits = _userLimits[u.id]!;
    showAdminSheet(
      context,
      title: 'Limits · ${u.name}',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(u.email, style: DP.caption),
          const SizedBox(height: 12),
          AdminListCard(
            children: [
              for (final s in _serviceNames)
                DPListRow(
                  onTap: () {
                    Navigator.pop(ctx);
                    _edit(s, limits[s]!, forUser: u.name);
                  },
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  title: s,
                  subtitle:
                      '${_fmt(limits[s]!.perTxn)} per txn · ${_fmt(limits[s]!.daily)} daily',
                  trailing: const Icon(DPIcons.edit, size: 18, color: DP.muted),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DPButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Transaction Limits',
      breadcrumb: 'Admin / Transaction Limits',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          const Text('Manage user limits & service availability',
              style: DP.caption),
          const SizedBox(height: 12),
          DPSegmented(
            options: const ['System Default', 'Per User', 'Services'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          if (_tab == 0) ...[
            const DPSectionHeader('Transaction Limits per Service'),
            AdminListCard(
              children: [
                for (final s in _serviceNames)
                  DPListRow(
                    onTap: () => _edit(s, _defaults[s]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    title: s,
                    subtitle:
                        '${_fmt(_defaults[s]!.perTxn)} per transaction\n${_fmt(_defaults[s]!.daily)} daily cap',
                    subtitleMaxLines: 2,
                    trailing:
                        const Icon(DPIcons.edit, size: 18, color: DP.muted),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DPButton(
              label: _saving ? 'Saving Defaults...' : 'Save Defaults',
              loading: _saving,
              onPressed: _saveDefaults,
            ),
          ] else if (_tab == 1) ...[
            const DPBanner(
              'Give a single user higher or lower limits than the system default.',
              tone: DPTone.info,
              icon: DPIcons.info,
            ),
            const SizedBox(height: 14),
            DPSelectField(
              value: null,
              hint: 'Search by name, email, phone or ID...',
              leading: const Icon(DPIcons.search, size: 20, color: DP.muted),
              onTap: _pickUser,
            ),
            const SizedBox(height: 16),
            if (_userLimits.isEmpty)
              const DPEmptyState(
                icon: Icons.speed_rounded,
                title: 'Select a User',
                message: 'Users with custom limits will be listed here.',
              )
            else ...[
              const DPSectionHeader('Users with custom limits'),
              AdminListCard(
                children: [
                  for (final id in _userLimits.keys)
                    () {
                      final u = kAdminUsers.firstWhere((x) => x.id == id);
                      return AdminUserRow(
                        name: u.name,
                        subtitle: u.email,
                        onTap: () => _openUserLimits(u),
                        trailing: const Icon(DPIcons.chevronRight,
                            color: DP.muted),
                      );
                    }(),
                ],
              ),
            ],
          ] else ...[
            DPCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DPMenuRow(
                    icon: Icons.construction_rounded,
                    title: 'Maintenance Mode',
                    subtitle: _maintenance
                        ? 'Users see the message below'
                        : 'App running normally',
                    color: _maintenance ? DP.red : null,
                    trailing: Switch(
                      value: _maintenance,
                      onChanged: (v) => setState(() => _maintenance = v),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const DPLabel('Maintenance Message'),
                  DPField(
                    controller: _message,
                    hint: 'Enter maintenance message...',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  DPButton.mint(
                    label: 'Update Message',
                    height: 44,
                    onPressed: () => dpSnack(
                        context, 'Maintenance message updated',
                        success: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const DPSectionHeader('Service Controls'),
            const Text('Enable or disable individual services',
                style: DP.caption),
            const SizedBox(height: 10),
            DPCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (final s in _serviceNames) ...[
                    if (s != _serviceNames.first)
                      const Divider(height: 1, color: DP.borderSoft),
                    DPMenuRow(
                      icon: Icons.toggle_on_outlined,
                      title: s,
                      subtitle: _enabled[s]! ? 'Available' : 'Paused',
                      trailing: Switch(
                        value: _enabled[s]!,
                        onChanged: (v) => setState(() => _enabled[s] = v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
