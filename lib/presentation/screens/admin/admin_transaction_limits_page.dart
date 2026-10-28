// lib/presentation/screens/admin/admin_transaction_limits_page.dart
// Transaction Limits: system default caps per service
// (GET /api/admin/limits, PUT .../limits/defaults), per-user overrides
// (GET/PUT .../limits/users/:id), maintenance mode and service switches
// (PATCH /api/admin/settings).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class _Limit {
  double? perTxn; // null = unlimited
  double? daily;
  bool custom;
  _Limit(this.perTxn, this.daily, {this.custom = false});

  factory _Limit.fromJson(dynamic v) {
    final m = asMap(v);
    return _Limit(
      m['perTxn'] == null ? null : toDouble(m['perTxn']),
      m['daily'] == null ? null : toDouble(m['daily']),
      custom: m['custom'] == true,
    );
  }
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
  bool _saving = false;
  bool _loading = true;
  Object? _error;
  final _message = TextEditingController();

  Map<String, String> _labels = {};
  Map<String, _Limit> _defaults = {};
  List<Map<String, dynamic>> _overrides = [];
  Map<String, dynamic> _settings = {};

  bool get _canWrite => adminCan('limits:write');
  bool get _canSettings => adminCan('settings:write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.get('/api/admin/limits'),
        api.get('/api/admin/settings'),
      ]);
      final l = asMap(results[0]);
      if (!mounted) return;
      setState(() {
        _labels = asMap(l['labels']).map((k, v) => MapEntry(k, str(v)));
        _defaults = asMap(l['defaults']).map((k, v) => MapEntry(k, _Limit.fromJson(v)));
        _overrides = asList(l['overrides']);
        _settings = asMap(results[1]);
        _message.text = str(_settings['maintenanceMessage']);
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

  /// Sierra Leone services (sl_…) are in Leones.
  String _fmt(double? v, [String service = '']) => v == null
      ? 'UNLIMITED'
      : DP.moneyIn(v, service.startsWith('sl_') ? 'SLE' : 'NGN', decimals: false);

  String _label(String service) => _labels[service] ?? service;

  /// Opens the editor; [onSave] receives the new limit, or null for
  /// "use system default" (per-user only).
  void _edit(
    String service,
    _Limit limit, {
    String? forUser,
    required Future<void> Function(_Limit? next) onSave,
  }) {
    final per = TextEditingController(text: limit.perTxn?.toStringAsFixed(0) ?? '');
    final day = TextEditingController(text: limit.daily?.toStringAsFixed(0) ?? '');
    var saving = false;
    showAdminSheet(
      context,
      title: forUser == null ? '${_label(service)} limits' : '${_label(service)} · $forUser',
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
            loading: saving,
            onPressed: saving || !_canWrite
                ? null
                : () async {
                    final p = double.tryParse(per.text);
                    final d = double.tryParse(day.text);
                    if (p != null && d != null && p > d) {
                      dpSnack(ctx, 'The daily cap must be at least the per-transaction limit', error: true);
                      return;
                    }
                    setSheet(() => saving = true);
                    try {
                      await onSave(_Limit(p, d));
                    } catch (e) {
                      setSheet(() => saving = false);
                      if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      dpSnack(context, '${_label(service)} limits saved', success: true);
                    }
                  },
          ),
          if (forUser != null) ...[
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Use system default',
              color: DP.muted,
              onPressed: saving || !_canWrite
                  ? null
                  : () async {
                      setSheet(() => saving = true);
                      try {
                        await onSave(null);
                      } catch (e) {
                        setSheet(() => saving = false);
                        if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveDefault(String service, _Limit? next) async {
    final r = asMap(await api.put('/api/admin/limits/defaults', {
      service: {'perTxn': next?.perTxn, 'daily': next?.daily},
    }));
    if (!mounted) return;
    setState(() => _defaults = r.map((k, v) => MapEntry(k, _Limit.fromJson(v))));
  }

  Future<void> _pickUser() async {
    List<AdminUser> users = [];
    var loading = true;
    Timer? debounce;
    StateSetter? sheetSetter;

    Future<void> search(String q) async {
      try {
        final r = await api.get('/api/admin/users', query: {'q': q.trim(), 'limit': 30});
        users = itemsOf(r).map(AdminUser.fromJson).toList();
      } catch (_) {
        users = [];
      }
      loading = false;
      sheetSetter?.call(() {});
    }

    search('');
    final picked = await showAdminSheet<AdminUser>(
      context,
      title: 'Select a User',
      builder: (ctx, setSheet) {
        sheetSetter = setSheet;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSearch(
              hint: 'Search by name, email or phone...',
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 400), () => search(v));
              },
            ),
            const SizedBox(height: 10),
            if (loading)
              const DPLoading(padding: 20)
            else if (users.isEmpty)
              const DPEmptyState(icon: Icons.group_outlined, title: 'No matching users')
            else
              AdminListCard(
                children: [
                  for (final u in users)
                    AdminUserRow(
                      name: u.name,
                      subtitle: '${u.email} · ${u.phone}',
                      onTap: () => Navigator.pop(ctx, u),
                    ),
                ],
              ),
          ],
        );
      },
    );
    debounce?.cancel();
    if (picked == null || !mounted) return;
    _openUserLimits(picked.id, picked.name, picked.email);
  }

  Future<void> _openUserLimits(String userId, String name, String email) async {
    final Map<String, _Limit> limits;
    try {
      final r = asMap(await api.get('/api/admin/limits/users/$userId'));
      limits = asMap(r['limits']).map((k, v) => MapEntry(k, _Limit.fromJson(v)));
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;

    Future<void> save(String service, _Limit? next) async {
      await api.put('/api/admin/limits/users/$userId', {
        service: next == null ? null : {'perTxn': next.perTxn, 'daily': next.daily},
      });
      _load();
    }

    showAdminSheet(
      context,
      title: 'Limits · $name',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(email, style: DP.caption),
          const SizedBox(height: 12),
          AdminListCard(
            children: [
              for (final s in limits.keys)
                DPListRow(
                  onTap: () {
                    Navigator.pop(ctx);
                    _edit(s, limits[s]!, forUser: name, onSave: (next) async {
                      await save(s, next);
                      if (mounted) _openUserLimitsAgain(userId, name, email);
                    });
                  },
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  title: _label(s),
                  subtitle:
                      '${_fmt(limits[s]!.perTxn, s)} per txn · ${_fmt(limits[s]!.daily, s)} daily',
                  trailing: limits[s]!.custom
                      ? const StatusPill('CUSTOM', color: DP.navyIcon)
                      : Icon(DPIcons.edit, size: 18, color: DP.muted),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DPButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _openUserLimitsAgain(String userId, String name, String email) {
    Future.microtask(() => _openUserLimits(userId, name, email));
  }

  Future<void> _patchSettings(Map<String, dynamic> body, {String? done}) async {
    if (!_canSettings) {
      dpSnack(context, 'Your role can\'t change settings.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final s = asMap(await api.patch('/api/admin/settings', body));
      if (!mounted) return;
      setState(() {
        _settings = s;
        _saving = false;
      });
      if (done != null) dpSnack(context, done, success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminScaffold(
        title: 'Transaction Limits',
        breadcrumb: 'Admin / Transaction Limits',
        body: DPLoading(),
      );
    }
    if (_error != null && _defaults.isEmpty) {
      return AdminScaffold(
        title: 'Transaction Limits',
        breadcrumb: 'Admin / Transaction Limits',
        body: DPLoadError(error: _error, onRetry: _load),
      );
    }
    final services = asMap(_settings['services']);
    final maintenance = _settings['maintenance'] == true;
    return AdminScaffold(
      title: 'Transaction Limits',
      breadcrumb: 'Admin / Transaction Limits',
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            Text('Manage user limits & service availability', style: DP.caption),
            const SizedBox(height: 12),
            DPSegmented(
              options: const ['System Default', 'Per User', 'Services'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              const DPSectionHeader('Transaction Limits per Service'),
              Text(
                _canWrite
                    ? 'Tap a service to change its limits. Changes apply straight away.'
                    : 'View only — your role can\'t change limits.',
                style: DP.caption,
              ),
              const SizedBox(height: 10),
              AdminListCard(
                children: [
                  for (final s in _defaults.keys)
                    DPListRow(
                      onTap: () => _edit(s, _defaults[s]!,
                          onSave: (next) => _saveDefault(s, next)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      title: _label(s),
                      subtitle:
                          '${_fmt(_defaults[s]!.perTxn, s)} per transaction\n${_fmt(_defaults[s]!.daily, s)} daily cap',
                      subtitleMaxLines: 2,
                      trailing: Icon(DPIcons.edit, size: 18, color: DP.muted),
                    ),
                ],
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
                hint: 'Search by name, email or phone...',
                leading: Icon(DPIcons.search, size: 20, color: DP.muted),
                onTap: _pickUser,
              ),
              const SizedBox(height: 16),
              if (_overrides.isEmpty)
                const DPEmptyState(
                  icon: Icons.speed_rounded,
                  title: 'Select a User',
                  message: 'Users with custom limits will be listed here.',
                )
              else ...[
                const DPSectionHeader('Users with custom limits'),
                AdminListCard(
                  children: [
                    for (final o in _overrides)
                      AdminUserRow(
                        name: str(asMap(o['user'])['fullName']),
                        subtitle:
                            '${str(asMap(o['user'])['email'])} · ${asMap(o['limits']).keys.map(_label).join(', ')}',
                        onTap: () => _openUserLimits(
                          str(asMap(o['user'])['id']),
                          str(asMap(o['user'])['fullName']),
                          str(asMap(o['user'])['email']),
                        ),
                        trailing: Icon(DPIcons.chevronRight, color: DP.muted),
                      ),
                  ],
                ),
              ],
            ] else ...[
              if (_saving) const LinearProgressIndicator(color: DP.green),
              DPCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DPMenuRow(
                      icon: Icons.construction_rounded,
                      title: 'Maintenance Mode',
                      subtitle: maintenance
                          ? 'Users see the message below'
                          : 'App running normally',
                      color: maintenance ? DP.red : null,
                      trailing: Switch(
                        value: maintenance,
                        onChanged: _saving || !_canSettings
                            ? null
                            : (v) => _patchSettings({'maintenance': v},
                                done: v ? 'Maintenance mode on' : 'Maintenance mode off'),
                      ),
                    ),
                    DPMenuRow(
                      icon: Icons.phonelink_lock_rounded,
                      title: 'New device code',
                      subtitle: asMap(_settings['deviceCheck'])['enabled'] == true
                          ? 'A code is needed to log in on a new phone (email NG, SMS SL)'
                          : 'Off: new phones log in straight away (an alert is still sent)',
                      trailing: Switch(
                        value: asMap(_settings['deviceCheck'])['enabled'] == true,
                        onChanged: _saving || !_canSettings
                            ? null
                            : (v) => _patchSettings({'deviceCheck': {'enabled': v}},
                                done: v ? 'New device code on' : 'New device code off'),
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
                      onPressed: _saving || !_canSettings
                          ? null
                          : () {
                              if (_message.text.trim().length < 3) {
                                dpSnack(context, 'Enter a short message', error: true);
                                return;
                              }
                              _patchSettings({'maintenanceMessage': _message.text.trim()},
                                  done: 'Maintenance message updated');
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const DPSectionHeader('Service Controls'),
              Text('Enable or disable individual services', style: DP.caption),
              const SizedBox(height: 10),
              DPCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (final e in services.entries) ...[
                      if (e.key != services.keys.first)
                        Divider(height: 1, color: DP.borderSoft),
                      DPMenuRow(
                        icon: Icons.toggle_on_outlined,
                        title: _label(e.key),
                        subtitle: e.value == true ? 'Available' : 'Paused',
                        trailing: Switch(
                          value: e.value == true,
                          onChanged: _saving || !_canSettings
                              ? null
                              : (v) => _patchSettings({
                                    'services': {e.key: v},
                                  }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
