// lib/presentation/screens/admin/admin_service_commission_page.dart
// Service Commission: revenue summary, rates per service and service
// performance (GET /api/admin/commission, PATCH .../commission/rates/:service).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class _Svc {
  final String key;
  final String name;
  final IconData icon;
  double rate; // % commission to user
  double margin; // % platform margin
  final int txns;
  final double volume;
  final double revenue;
  _Svc(this.key, this.name, this.icon, this.rate, this.margin, this.txns,
      this.volume, this.revenue);

  static IconData iconFor(String k) => switch (k) {
        'airtime' => DPIcons.smartphone,
        'data' => DPIcons.wifi,
        'electricity' => DPIcons.bolt,
        'cable' => DPIcons.tv,
        'education' => DPIcons.school,
        'insurance' => DPIcons.shield,
        _ => DPIcons.globe,
      };

  factory _Svc.fromJson(Map<String, dynamic> j) => _Svc(
        str(j['service']),
        str(j['label']),
        iconFor(str(j['service'])),
        toDouble(asMap(j['rate'])['user']),
        toDouble(asMap(j['rate'])['platform']),
        toInt(j['transactions']),
        toDouble(j['volume']),
        toDouble(j['revenue']),
      );
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
  static const _periodValues = {
    'Today': 'today',
    'This Week': 'week',
    'This Month': 'month',
    'This Year': 'year',
    'All Time': 'all',
  };

  List<_Svc> _svcs = [];
  Map<String, dynamic> _data = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = asMap(await api.get('/api/admin/commission',
          query: {'period': _periodValues[_period]}));
      if (!mounted) return;
      setState(() {
        _data = d;
        _svcs = asList(d['services']).map(_Svc.fromJson).toList();
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

  void _editRate(_Svc s) {
    final rate = TextEditingController(text: s.rate.toString());
    final margin = TextEditingController(text: s.margin.toString());
    var saving = false;
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
          const DPHelper('Each rate can be between 0% and 20%.'),
          const SizedBox(height: 18),
          DPButton(
            label: 'Save Rates',
            loading: saving,
            onPressed: saving || !adminCan('commission:write')
                ? null
                : () async {
                    final u = double.tryParse(rate.text);
                    final p = double.tryParse(margin.text);
                    if (u == null || p == null || u > 20 || p > 20) {
                      dpSnack(ctx, 'Enter rates between 0 and 20', error: true);
                      return;
                    }
                    setSheet(() => saving = true);
                    try {
                      await api.patch('/api/admin/commission/rates/${s.key}',
                          {'user': u, 'platform': p});
                    } catch (e) {
                      setSheet(() => saving = false);
                      if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    dpSnack(context, '${s.name} rates updated', success: true);
                    _load();
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminScaffold(
        title: 'Service Commission',
        breadcrumb: 'Admin / Service Commission',
        body: DPLoading(),
      );
    }
    if (_error != null && _data.isEmpty) {
      return AdminScaffold(
        title: 'Service Commission',
        breadcrumb: 'Admin / Service Commission',
        body: DPLoadError(error: _error, onRetry: _load),
      );
    }
    final volume = toDouble(_data['volume']);
    final revenue = toDouble(_data['revenue']);
    final commission = toDouble(_data['commissionPaid']);
    final avg = toDouble(_data['avgRevenuePerTxn']);
    final maxVol = _svcs.fold<double>(0, (a, s) => a > s.volume ? a : s.volume);
    final trend = asList(_data['revenue7d']).map((d) => toDouble(d['value'])).toList();

    return AdminScaffold(
      title: 'Service Commission',
      breadcrumb: 'Admin / Service Commission',
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: _load,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          DPChipScroller(
            options: _periods,
            selected: _period,
            onSelect: (p) {
              setState(() => _period = p);
              _load();
            },
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
                value: DP.naira(avg),
                icon: Icons.calculate_outlined,
                color: DP.navyInk,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('Revenue Trend (Last 7 Days)'),
          DPCard(
            padding: const EdgeInsets.all(16),
            child: AdminBarChart(
              values: trend.isEmpty ? List.filled(7, 0.0) : trend,
              format: (v) => DP.naira(v, decimals: false),
            ),
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('Commission Rates'),
          Text('Tap a service to change its rates', style: DP.caption),
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
                  trailing: Icon(DPIcons.edit, size: 18, color: DP.muted),
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
                              '${s.txns} txns · ${DP.naira(s.volume, decimals: false)} · earned ${DP.naira(s.revenue, decimals: false)}',
                              style: DP.caption.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxVol > 0 ? s.volume / maxVol : 0,
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
      ),
    );
  }
}
