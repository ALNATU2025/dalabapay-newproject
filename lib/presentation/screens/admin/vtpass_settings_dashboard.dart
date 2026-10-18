// lib/presentation/screens/admin/vtpass_settings_dashboard.dart
// VTpass Settings — UI only. Provider balance, environment, health,
// service switches, maintenance and alerts.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_widgets.dart';

class VtpassSettingsDashboard extends StatefulWidget {
  const VtpassSettingsDashboard({super.key});

  @override
  State<VtpassSettingsDashboard> createState() =>
      _VtpassSettingsDashboardState();
}

class _VtpassSettingsDashboardState extends State<VtpassSettingsDashboard> {
  bool _live = true;
  bool _maintenance = false;
  bool _lowBalanceAlerts = true;
  bool _checking = false;
  bool _testing = false;
  String _health = 'Server is healthy';
  DateTime _lastChecked = DateTime.now();
  final _message = TextEditingController(
    text: 'We\'re doing quick maintenance. Please try again shortly.',
  );
  final Map<String, bool> _services = {
    'Airtime': true,
    'Data': true,
    'Electricity': true,
    'Cable TV': true,
    'Education': true,
    'Insurance': false,
    'International Airtime': true,
    'Money Transfer': true,
  };

  static const double _balance = 186450.75;
  static const double _lowThreshold = 50000;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    setState(() => _checking = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _checking = false;
      _health = 'Server is healthy';
      _lastChecked = DateTime.now();
    });
  }

  Future<void> _testCredentials() async {
    setState(() => _testing = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _testing = false);
    dpDialog(
      context,
      title: 'Test completed',
      message:
          'Credentials are valid for ${_live ? 'Live' : 'Sandbox'} mode. Response time 412 ms.',
      confirmLabel: 'Close',
    );
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final low = _balance < _lowThreshold;
    return AdminScaffold(
      title: 'VTpass Settings',
      breadcrumb: 'Admin / VTpass Settings',
      body: ListView(
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
                    const Text(
                      'VTpass Balance',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                    ),
                    const Spacer(),
                    StatusPill(
                      _live ? 'Live Mode' : 'Sandbox Mode',
                      color: _live ? const Color(0xFF7FE3BC) : DP.amberBg,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DPCountUp(
                  value: _balance,
                  format: (v) => DP.naira(v),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                DPButton(
                  label: 'Add Funds to VTpass',
                  leadingIcon: DPIcons.plus,
                  height: 44,
                  background: DP.greenBright,
                  onPressed: () => dpSnack(
                    context,
                    'Funding VTpass isn\'t set up in this UI build',
                  ),
                ),
              ],
            ),
          ),
          if (low) ...[
            const SizedBox(height: 12),
            const DPBanner(
              'VTpass wallet balance is low',
              tone: DPTone.warning,
              icon: DPIcons.alert,
            ),
          ],
          const SizedBox(height: 20),
          const DPSectionHeader('Environment'),
          DPSegmented(
            options: const ['Sandbox Mode', 'Live Mode'],
            index: _live ? 1 : 0,
            onChanged: (i) async {
              if (i == 1 && !_live) {
                final ok = await dpDialog(
                  context,
                  title: 'Switch to Live?',
                  message: 'Real payments will be processed with VTpass.',
                  confirmLabel: 'Go Live',
                  cancelLabel: 'Cancel',
                  tone: DPTone.warning,
                );
                if (ok != true) return;
              }
              setState(() => _live = i == 1);
            },
          ),
          const SizedBox(height: 20),
          const DPSectionHeader('Server Health'),
          DPCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_outlined, color: DP.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_health, style: DP.bodyStrong)),
                    StatusPill(_checking ? 'Checking...' : 'Healthy'),
                  ],
                ),
                const SizedBox(height: 10),
                DPSummaryRow('Last Checked', _time(_lastChecked)),
                const DPSummaryRow('Uptime', '99.97%'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DPOutlineButton(
                        label: _checking ? 'Checking...' : 'Check Health',
                        icon: DPIcons.refresh,
                        height: 46,
                        onPressed: _checking ? null : _checkHealth,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DPOutlineButton(
                        label: _testing ? 'Testing...' : 'Test Credentials',
                        icon: DPIcons.key,
                        color: DP.navyIcon,
                        height: 46,
                        onPressed: _testing ? null : _testCredentials,
                      ),
                    ),
                  ],
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
                for (final e in _services.entries) ...[
                  if (e.key != _services.keys.first)
                    const Divider(height: 1, color: DP.borderSoft),
                  DPMenuRow(
                    icon: _iconFor(e.key),
                    title: e.key,
                    subtitle: e.value ? 'Active' : 'Disabled for all users',
                    trailing: Switch(
                      value: e.value,
                      onChanged: (v) => setState(() => _services[e.key] = v),
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
                  subtitle: _maintenance
                      ? 'All VTpass services are paused'
                      : 'Services running normally',
                  color: _maintenance ? DP.red : null,
                  trailing: Switch(
                    value: _maintenance,
                    onChanged: (v) => setState(() => _maintenance = v),
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
                  onPressed: () =>
                      dpSnack(context, 'Maintenance message updated',
                          success: true),
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
              subtitle: 'Notify admins below ${DP.naira(_lowThreshold, decimals: false)}',
              trailing: Switch(
                value: _lowBalanceAlerts,
                onChanged: (v) => setState(() => _lowBalanceAlerts = v),
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
              subtitle: 'Access VTpass API documentation',
              onTap: () =>
                  dpSnack(context, 'Links aren\'t set up in this UI build'),
              trailing: const Icon(DPIcons.chevronRight, color: DP.muted),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String s) => switch (s) {
        'Airtime' => DPIcons.smartphone,
        'Data' => DPIcons.wifi,
        'Electricity' => DPIcons.bolt,
        'Cable TV' => DPIcons.tv,
        'Education' => DPIcons.school,
        'Insurance' => DPIcons.shield,
        'International Airtime' => DPIcons.globe,
        _ => DPIcons.upRight,
      };
}
