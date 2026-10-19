// lib/presentation/screens/admin/vtpass_settings_dashboard.dart
// Provider Settings: bill-provider balance and environment
// (GET /api/admin/provider), health check and credential test, service
// switches, maintenance mode and low-balance alerts (PATCH /api/admin/settings).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class VtpassSettingsDashboard extends StatefulWidget {
  const VtpassSettingsDashboard({super.key});

  @override
  State<VtpassSettingsDashboard> createState() =>
      _VtpassSettingsDashboardState();
}

class _VtpassSettingsDashboardState extends State<VtpassSettingsDashboard> {
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _provider = {};
  Map<String, dynamic> _readiness = {};
  bool _loading = true;
  Object? _error;
  bool _checking = false;
  bool _testing = false;
  bool _saving = false;
  Map<String, dynamic>? _health;
  final _message = TextEditingController();

  bool get _canWrite => adminCan('settings:write');
  bool get _canManageProvider => adminCan('provider:manage');

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
        api.get('/api/admin/settings'),
        api.get('/api/admin/provider'),
      ]);
      if (!mounted) return;
      Map<String, dynamic> ready = {};
      try {
        ready = asMap(await api.get('/api/admin/readiness'));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _readiness = ready;
        _settings = asMap(results[0]);
        _provider = asMap(results[1]);
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

  Future<void> _patch(Map<String, dynamic> body, {String? done}) async {
    if (!_canWrite) {
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

  Future<void> _checkHealth() async {
    setState(() => _checking = true);
    try {
      final h = asMap(await api.post('/api/admin/provider/health'));
      if (!mounted) return;
      setState(() {
        _health = h;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _testCredentials() async {
    setState(() => _testing = true);
    Map<String, dynamic> r;
    try {
      r = asMap(await api.post('/api/admin/provider/test'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _testing = false);
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _testing = false);
    final ok = r['ok'] == true;
    dpDialog(
      context,
      title: ok ? 'Test completed' : 'Test failed',
      message: str(r['message'], ok ? 'Credentials are valid.' : 'The provider rejected the credentials.'),
      confirmLabel: 'Close',
      tone: ok ? DPTone.success : DPTone.error,
    );
  }

  Widget _readinessCard() {
    final ready = _readiness['ready'] == true;
    final checks = asList(_readiness['checks']);
    (IconData, Color) look(String status) => switch (status) {
          'ok' => (DPIcons.checkCircle, DP.green),
          'warn' => (DPIcons.info, DP.amber),
          _ => (DPIcons.alert, DP.red),
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DPSectionHeader(
          'Go-live checklist',
          actionLabel: 'Re-check',
          onAction: _load,
        ),
        DPBanner(
          ready
              ? 'Ready for real transactions. Make one small payment first.'
              : 'Not ready for real money yet — fix the red items below.',
          tone: ready ? DPTone.success : DPTone.error,
          icon: ready ? DPIcons.checkCircle : DPIcons.alert,
        ),
        const SizedBox(height: 10),
        DPCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final c in checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(look(str(c['status'])).$1,
                          size: 20, color: look(str(c['status'])).$2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(c['label']), style: DP.bodyStrong),
                            const SizedBox(height: 2),
                            Text(str(c['detail']), style: DP.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminScaffold(
        title: 'Provider Settings',
        breadcrumb: 'Admin / Provider Settings',
        body: DPLoading(),
      );
    }
    if (_error != null && _settings.isEmpty) {
      return AdminScaffold(
        title: 'Provider Settings',
        breadcrumb: 'Admin / Provider Settings',
        body: DPLoadError(error: _error, onRetry: _load),
      );
    }
    final bill = asMap(_provider['bill']);
    final providerName = str(bill['name'], 'none');
    final env = str(bill['environment'], providerName);
    final configured = bill['configured'] == true;
    final live = env.contains('live');
    final balance = _provider['balance'] == null ? null : toDouble(_provider['balance']);
    final low = _provider['lowBalance'] == true;
    final threshold = toDouble(_provider['lowBalanceThreshold']);
    final services = asMap(_settings['services']);
    final labels = asMap(_settings['serviceLabels']);
    final maintenance = _settings['maintenance'] == true;
    final lowAlerts = _settings['lowBalanceAlerts'] == true;
    final healthy = _health == null ? null : _health!['ok'] == true;

    return AdminScaffold(
      title: 'Provider Settings',
      breadcrumb: 'Admin / Provider Settings',
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: DP.navyGradient,
                borderRadius: BorderRadius.circular(DP.rXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${providerName.contains('vtpass') ? 'VTpass' : (providerName == 'none' ? 'Bill provider' : providerName.toUpperCase())} Balance',
                        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                      ),
                      const Spacer(),
                      StatusPill(
                        !configured
                            ? 'Not connected'
                            : (live
                                ? 'Live Mode'
                                : (env.contains('sandbox') ? 'Sandbox Mode' : '${_cap(env)} Mode')),
                        color: live ? const Color(0xFF7FE3BC) : DP.amberBg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (balance != null)
                    DPCountUp(
                      value: balance,
                      format: (v) => DP.naira(v),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    const Text(
                      'Not available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    configured
                        ? 'Top up the provider wallet from the provider\'s own dashboard.'
                        : 'No bill provider is connected. Set BILL_PROVIDER and its keys on the server.',
                    style: const TextStyle(color: Color(0xFF7FE3BC), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (low) ...[
              const SizedBox(height: 12),
              const DPBanner(
                'Provider wallet balance is low',
                tone: DPTone.warning,
                icon: DPIcons.alert,
              ),
            ],
            if (_readiness.isNotEmpty) ...[
              const SizedBox(height: 20),
              _readinessCard(),
            ],
            const SizedBox(height: 20),
            const DPSectionHeader('Environment'),
            DPCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  DPSummaryRow('Bill providers', providerName),
                  DPSummaryRow('Payment provider', str(asMap(_provider['payment'])['name'], 'none')),
                  for (final e in asMap(bill['services']).entries)
                    DPSummaryRow(
                      str(labels[e.key], e.key),
                      asMap(e.value)['configured'] == true
                          ? '${str(asMap(e.value)['provider'])} · ${str(asMap(e.value)['environment'])}'
                          : '${str(asMap(e.value)['provider'])} · not connected',
                      valueColor: asMap(e.value)['configured'] == true ? null : DP.red,
                    ),
                ],
              ),
            ),
            const DPHelper('The provider and live/sandbox mode are set in the server\'s environment, so they can\'t be switched by accident from the app.'),
            const SizedBox(height: 20),
            const DPSectionHeader('Server Health'),
            DPCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.dns_outlined,
                          color: healthy == false ? DP.red : DP.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _health == null
                              ? 'Not checked yet'
                              : str(_health!['message'], healthy! ? 'Server is healthy' : 'Server problem'),
                          style: DP.bodyStrong,
                        ),
                      ),
                      StatusPill(_checking
                          ? 'Checking...'
                          : (healthy == null ? 'Unknown' : (healthy ? 'Healthy' : 'Failed'))),
                    ],
                  ),
                  if (_health != null) ...[
                    const SizedBox(height: 10),
                    DPSummaryRow('Last Checked', _time(parseDate(_health!['checkedAt']))),
                    DPSummaryRow('Response time', '${toInt(_health!['latencyMs'])} ms'),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DPOutlineButton(
                          label: _checking ? 'Checking...' : 'Check Health',
                          icon: DPIcons.refresh,
                          height: 46,
                          onPressed: _checking || !_canManageProvider ? null : _checkHealth,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DPOutlineButton(
                          label: _testing ? 'Testing...' : 'Test Credentials',
                          icon: DPIcons.key,
                          color: DP.navyIcon,
                          height: 46,
                          onPressed: _testing || !_canManageProvider ? null : _testCredentials,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const DPSectionHeader('Service Controls'),
            Text('Enable or disable individual services', style: DP.caption),
            if (_saving) const LinearProgressIndicator(color: DP.green),
            const SizedBox(height: 10),
            DPCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (final e in services.entries) ...[
                    if (e.key != services.keys.first)
                      Divider(height: 1, color: DP.borderSoft),
                    DPMenuRow(
                      icon: _iconFor(e.key),
                      title: str(labels[e.key], e.key),
                      subtitle: e.value == true ? 'Active' : 'Disabled for all users',
                      trailing: Switch(
                        value: e.value == true,
                        onChanged: _saving || !_canWrite
                            ? null
                            : (v) => _patch({
                                  'services': {e.key: v},
                                }, done: '${str(labels[e.key], e.key)} ${v ? 'enabled' : 'disabled'}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const DPSectionHeader('Maintenance Control'),
            DPCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DPMenuRow(
                    icon: Icons.construction_rounded,
                    title: 'Maintenance Mode',
                    subtitle: maintenance
                        ? 'All bill payments are paused'
                        : 'Services running normally',
                    color: maintenance ? DP.red : null,
                    trailing: Switch(
                      value: maintenance,
                      onChanged: _saving || !_canWrite
                          ? null
                          : (v) async {
                              if (v) {
                                final ok = await dpDialog(
                                  context,
                                  title: 'Pause all payments?',
                                  message: 'Customers won\'t be able to buy anything until you turn this off.',
                                  confirmLabel: 'Turn on',
                                  cancelLabel: 'Cancel',
                                  tone: DPTone.warning,
                                );
                                if (ok != true) return;
                              }
                              _patch({'maintenance': v},
                                  done: v ? 'Maintenance mode on' : 'Maintenance mode off');
                            },
                    ),
                  ),
                  const SizedBox(height: 6),
                  DPField(
                    controller: _message,
                    hint: 'Update maintenance message...',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  DPButton.mint(
                    label: 'Update',
                    height: 44,
                    onPressed: _saving || !_canWrite
                        ? null
                        : () {
                            if (_message.text.trim().length < 3) {
                              dpSnack(context, 'Enter a short message', error: true);
                              return;
                            }
                            _patch({'maintenanceMessage': _message.text.trim()},
                                done: 'Maintenance message updated');
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const DPSectionHeader('Low Balance Alerts'),
            DPCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DPMenuRow(
                icon: DPIcons.bell,
                title: 'Low Balance Alert',
                subtitle: 'Notify admins below ${DP.naira(threshold, decimals: false)}',
                trailing: Switch(
                  value: lowAlerts,
                  onChanged: _saving || !_canWrite
                      ? null
                      : (v) => _patch({'lowBalanceAlerts': v}),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const DPSectionHeader('Documentation & Info'),
            DPCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DPMenuRow(
                icon: Icons.menu_book_outlined,
                title: 'Open Documentation',
                subtitle: 'VTpass API documentation',
                onTap: () async {
                  var opened = false;
                  try {
                    opened = await launchUrl(
                      Uri.parse('https://www.vtpass.com/documentation/'),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                  if (!opened && context.mounted) {
                    dpSnack(context, 'Open www.vtpass.com/documentation in your browser');
                  }
                },
                trailing: Icon(DPIcons.chevronRight, color: DP.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String s) => switch (s) {
        'airtime' => DPIcons.smartphone,
        'data' => DPIcons.wifi,
        'electricity' => DPIcons.bolt,
        'cable' => DPIcons.tv,
        'education' => DPIcons.school,
        'insurance' => DPIcons.shield,
        'international' => DPIcons.globe,
        _ => DPIcons.upRight,
      };
}
