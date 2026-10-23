// lib/presentation/screens/admin/admin_cashwyre_page.dart
// Pricing for bank / mobile money transfers and dollar cards (Cashwyre),
// and what Cashwyre reports per country (GET /api/admin/cashwyre/coverage).
// Your margin is added on top of Cashwyre's own fee and exchange rate.
//   GET   /api/admin/settings
//   PATCH /api/admin/settings { cashwyre }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminCashwyrePage extends StatefulWidget {
  const AdminCashwyrePage({super.key});

  @override
  State<AdminCashwyrePage> createState() => _AdminCashwyrePageState();
}

class _AdminCashwyrePageState extends State<AdminCashwyrePage> {
  static const _fields = [
    ['payoutFeePercent', 'Transfer fee (% of Cashwyre\'s cost)', '%'],
    ['fxMarginPercent', 'Currency conversion margin', '%'],
    ['cardFeePercent', 'Card creation / top-up margin', '%'],
    ['cardWithdrawMarginPercent', 'Card → wallet margin', '%'],
    ['minCardUsd', 'Smallest new card', '\$'],
    ['maxCardUsd', 'Largest new card', '\$'],
    ['maxCardsPerUser', 'Cards per customer', '#'],
  ];
  final _c = {for (final f in _fields) f[0]: TextEditingController()};
  bool _loaded = false;
  bool _saving = false;
  bool _checking = false;
  List<Map<String, dynamic>>? _coverage;

  Future<void> _checkCoverage() async {
    setState(() => _checking = true);
    final r = await runWithFeedback(context, () => api.get('/api/admin/cashwyre/coverage'));
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (r != null) _coverage = asList(asMap(r)['countries']);
    });
    if (r != null && asMap(r)['connected'] == false) dpSnack(context, 'Cashwyre keys are not set on the server.', error: true);
  }

  Widget _coverageRow(Map<String, dynamic> c) {
    String part(String label, dynamic v) {
      final m = asMap(v);
      if (m['count'] == null) return '$label: error';
      final n = toInt(m['count']);
      return n == 0 ? '$label: none' : '$label: $n';
    }
    final examples = asMap(c['mobile_money'])['examples'];
    final momoNames = (examples is List ? examples : const []).map((e) => '$e').join(', ');
    final bal = c['walletBalance'];
    final shown = c['shown'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DPCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${str(c['name'])} (${str(c['currency'])})', style: DP.bodyStrong),
                  Text('${part('Banks', c['bank'])} · ${part('Mobile money', c['mobile_money'])}', style: DP.caption),
                  if (momoNames.isNotEmpty) Text(momoNames, style: DP.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    'Wallet ${str(c['wallet'])}: ${bal == null ? 'not found' : toDouble(bal).toStringAsFixed(2)}',
                    style: DP.tiny.copyWith(color: bal == null || toDouble(bal) <= 0 ? DP.red : DP.green),
                  ),
                ],
              ),
            ),
            StatusPill(shown ? 'Shown' : 'Hidden'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _n(dynamic v) {
    final d = toDouble(v);
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  Future<Map<String, dynamic>> _load() async {
    final s = asMap(await api.get('/api/admin/settings'));
    if (!_loaded) {
      final cw = asMap(s['cashwyre']);
      for (final f in _fields) {
        _c[f[0]]!.text = _n(cw[f[0]]);
      }
      _loaded = true;
    }
    return s;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => api.patch('/api/admin/settings', {
        'cashwyre': {
          for (final f in _fields)
            if (_c[f[0]]!.text.trim().isNotEmpty) f[0]: double.tryParse(_c[f[0]]!.text) ?? 0,
        },
      }),
      success: 'Pricing saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = adminCan('settings:write');
    return AdminScaffold(
      title: 'Transfers & Cards',
      breadcrumb: 'Admin / Transfers & Cards',
      body: AsyncView<Map<String, dynamic>>(
        load: _load,
        builder: (context, _, __) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            const DPBanner(
              'Bank & mobile money transfers and dollar cards go through Cashwyre and are paid from your Cashwyre balance — keep it funded (USD for cards and transfers to other currencies). Switch each service on or off and set limits in Provider Settings and Transaction Limits.',
              tone: DPTone.info,
              icon: DPIcons.info,
            ),
            const SizedBox(height: 18),
            for (final f in _fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DPLabel(f[1]),
                    DPField(
                      controller: _c[f[0]],
                      enabled: canEdit,
                      prefixText: f[2] == '\$' ? '\$ ' : null,
                      suffix: f[2] == '%'
                          ? const Padding(padding: EdgeInsets.all(14), child: Text('%'))
                          : null,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (canEdit) DPButton(label: 'Save', loading: _saving, onPressed: _save),
            const SizedBox(height: 24),
            const DPSectionHeader('Country coverage'),
            const DPHelper('What Cashwyre reports for each country. Customers only see countries with banks or mobile money, and a country is paused when its wallet is empty.'),
            const SizedBox(height: 10),
            _coverage == null
                ? DPOutlineButton(
                    label: _checking ? 'Checking all countries…' : 'Check coverage',
                    icon: DPIcons.refresh,
                    onPressed: _checking ? null : _checkCoverage,
                  )
                : Column(children: [for (final c in _coverage!) _coverageRow(c)]),
          ],
        ),
      ),
    );
  }
}
