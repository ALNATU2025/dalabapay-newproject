// lib/presentation/screens/admin/admin_service_commission_page.dart
// Service Commission — UI only. Revenue summary, rates per service and
// service performance.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class _Svc {
  final String name;
  final IconData icon;
  double rate; // % commission to user
  double margin; // % platform margin
  final int txns;
  final double volume;
  _Svc(this.name, this.icon, this.rate, this.margin, this.txns, this.volume);
}

class AdminServiceCommissionPage extends StatefulWidget {
  const AdminServiceCommissionPage({super.key});

  @override
  State<AdminServiceCommissionPage> createState() =>
      _AdminServiceCommissionPageState();
}

class _AdminServiceCommissionPageState
    extends State<AdminServiceCommissionPage> {
  String _period = 'This Month';
  static const _periods = ['Today', 'This Week', 'This Month', 'This Year', 'All Time'];

  final List<_Svc> _svcs = [
    _Svc('Airtime', DPIcons.smartphone, 2.0, 1.0, 1840, 3120000),
    _Svc('Data', DPIcons.wifi, 2.5, 1.5, 1210, 2650000),
    _Svc('Electricity', DPIcons.bolt, 0.5, 0.5, 430, 4870000),
    _Svc('Cable TV', DPIcons.tv, 1.0, 0.5, 520, 6230000),
    _Svc('Education', DPIcons.school, 1.5, 1.0, 96, 410000),
    _Svc('Insurance', DPIcons.shield, 2.0, 2.0, 22, 330000),
    _Svc('International Airtime', DPIcons.globe, 1.0, 2.0, 74, 590000),
  ];

  double get _factor => switch (_period) {
        'Today' => 1 / 30,
        'This Week' => 0.23,
        'This Year' => 11,
        'All Time' => 19,
        _ => 1,
      };

  void _editRate(_Svc s) {
    final rate = TextEditingController(text: s.rate.toString());
    final margin = TextEditingController(text: s.margin.toString());
    showAdminSheet(
      context,
      title: '${s.name} Commission',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DPLabel('User commission rate (%)'),
          DPField(
            controller: rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 14),
          const DPLabel('Platform margin (%)'),
          DPField(
            controller: margin,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 8),
          const DPHelper('Example: on ₦1,000 at 2%, the user earns ₦20.'),
          const SizedBox(height: 18),
          DPButton(
            label: 'Save Rates',
            onPressed: () {
              setState(() {
                s.rate = double.tryParse(rate.text) ?? s.rate;
                s.margin = double.tryParse(margin.text) ?? s.margin;
              });
              Navigator.pop(ctx);
              dpSnack(context, '${s.name} rates updated', success: true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _factor;
    final volume = _svcs.fold<double>(0, (a, s) => a + s.volume) * f;
    final revenue =
        _svcs.fold<double>(0, (a, s) => a + s.volume * s.margin / 100) * f;
    final commission =
        _svcs.fold<double>(0, (a, s) => a + s.volume * s.rate / 100) * f;
    final txns = (_svcs.fold<int>(0, (a, s) => a + s.txns) * f).round();
    final maxVol = _svcs.fold<double>(0, (a, s) => a > s.volume ? a : s.volume);

    return AdminScaffold(
      title: 'Service Commission',
      breadcrumb: 'Admin / Service Commission',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          DPChipScroller(
            options: _periods,
            selected: _period,
            onSelect: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 14),
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Platform Revenue',
                value: DP.naira(revenue, decimals: false),
                icon: Icons.trending_up_rounded,
                color: DP.green,
              ),
              AdminStat(
                label: 'Commission Paid',
                value: DP.naira(commission, decimals: false),
                icon: DPIcons.sparkle,
                color: DP.amber,
              ),
              AdminStat(
                label: 'Total Transaction Volume',
                value: DP.naira(volume, decimals: false),
                icon: Icons.payments_outlined,
              ),
              AdminStat(
                label: 'Avg Revenue per Txn',
                value: DP.naira(txns == 0 ? 0 : revenue / txns),
                icon: Icons.calculate_outlined,
                color: DP.navy,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('Revenue Trend (Last 7 Days)'),
          DPCard(
            padding: const EdgeInsets.all(16),
            child: AdminBarChart(
              values: kRevenue7d.map((v) => v * 0.012).toList(),
              format: (v) => DP.naira(v, decimals: false),
            ),
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('Commission Rates'),
          const Text('Tap a service to change its rates', style: DP.caption),
          const SizedBox(height: 10),
          AdminListCard(
            children: [
              for (final s in _svcs)
                DPListRow(
                  onTap: () => _editRate(s),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: DPIconBadge.blue(s.icon, size: 40, iconSize: 19),
                  title: s.name,
                  subtitle: 'User ${s.rate}% · Platform ${s.margin}%',
                  trailing: const Icon(DPIcons.edit, size: 18, color: DP.muted),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('Service Performance'),
          DPCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final s in _svcs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.name,
                                  style: DP.body.copyWith(fontSize: 13.5)),
                            ),
                            Text(
                              '${(s.txns * f).round()} txns · ${DP.naira(s.volume * f, decimals: false)}',
                              style: DP.caption.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: s.volume / maxVol,
                            minHeight: 7,
                            backgroundColor: DP.borderSoft,
                            color: DP.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
