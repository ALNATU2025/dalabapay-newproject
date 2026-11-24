// lib/presentation/screens/admin/admin_vtpass_portal_page.dart
// VTpass portal (Admin → Provider settings → VTpass portal): a management
// view of every payment Dalabapay sent through VTpass.
//   Overview     — VTpass wallet, totals, success rate, commission VTpass
//                  pays Dalabapay (VTpass's figure, else the set rate,
//                  default 1.8%), net after customer commission, a volume /
//                  commission chart, status mix, services, failure reasons.
//   Transactions — searchable, filterable list with VTpass ids, codes,
//                  commission and failure reasons; detail + requery; CSV.
// GET /api/admin/vtpass/summary, /transactions, /transactions.csv;
// PATCH /api/admin/vtpass/settings.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

const _green = Color(0xFF079A68);
const _red = Color(0xFFE5484D);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF7C3AED);
const _blue = Color(0xFF2779FD);

String _money(num v, {bool dec = false}) => DP.naira(v, decimals: dec);
String _short(num v) {
  final a = v.abs();
  if (a >= 1e9) return '₦${(v / 1e9).toStringAsFixed(1)}B';
  if (a >= 1e6) return '₦${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)}M';
  if (a >= 1e3) return '₦${(v / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}k';
  return '₦${v.toStringAsFixed(0)}';
}

Color _statusColor(String s) => switch (s) {
      'success' => _green,
      'failed' || 'reversed' => _red,
      'refunded' => _blue,
      'disputed' => _purple,
      _ => _amber,
    };

IconData _serviceIcon(String service) => switch (service) {
      'cable' => Icons.live_tv_rounded,
      'international' => Icons.public_rounded,
      'electricity' => Icons.bolt_rounded,
      'data' => Icons.wifi_rounded,
      'education' => Icons.school_rounded,
      'insurance' => Icons.health_and_safety_rounded,
      _ => Icons.phone_android_rounded,
    };

class AdminVtpassPortalPage extends StatefulWidget {
  /// For tests and screenshots: show this summary / list without loading.
  @visibleForTesting
  final Map<String, dynamic>? initialSummary;
  @visibleForTesting
  final Map<String, dynamic>? initialTransactions;
  @visibleForTesting
  final int initialTab;

  const AdminVtpassPortalPage({super.key, this.initialSummary, this.initialTransactions, this.initialTab = 0});

  @override
  State<AdminVtpassPortalPage> createState() => _AdminVtpassPortalPageState();
}

class _AdminVtpassPortalPageState extends State<AdminVtpassPortalPage> {
  static const _periods = {'today': 'Today', 'week': '7 days', 'month': '30 days', 'year': '12 months', 'all': 'All time'};
  late int _tab = widget.initialTab;

  // Overview
  String _period = 'month';
  Map<String, dynamic>? _summary;
  Object? _summaryError;
  bool _loadingSummary = false;
  int? _bar; // tapped chart bar

  // Transactions
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _listMeta = {};
  String? _status;
  String _q = '';
  DateTimeRange? _range;
  int _page = 1;
  bool _loadingList = false;
  Object? _listError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary;
      _period = str(widget.initialSummary!['period'], 'month');
    } else {
      _loadSummary();
    }
    if (widget.initialTransactions != null) {
      _listMeta = widget.initialTransactions!;
      _items.addAll((widget.initialTransactions!['items'] as List? ?? const []).map(asMap));
    } else if (widget.initialSummary == null) {
      _loadList(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final s = asMap(await api.get('/api/admin/vtpass/summary', query: {'period': _period}));
      if (!mounted) return;
      setState(() {
        _summary = s;
        _bar = null;
        _loadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = e;
        _loadingSummary = false;
      });
    }
  }

  Map<String, dynamic> get _query => {
        if (_status != null) 'status': _status,
        if (_q.trim().isNotEmpty) 'q': _q.trim(),
        if (_range != null) 'from': isoDay(_range!.start),
        if (_range != null) 'to': isoDay(_range!.end),
      };

  Future<void> _loadList({bool reset = false}) async {
    if (_loadingList) return;
    setState(() {
      _loadingList = true;
      _listError = null;
      if (reset) _page = 1;
    });
    try {
      final r = asMap(await api.get('/api/admin/vtpass/transactions', query: {..._query, 'page': '$_page', 'limit': '25'}));
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll((r['items'] as List? ?? const []).map(asMap));
        _listMeta = r;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e;
        _loadingList = false;
      });
    }
  }

  void _search(String v) {
    _q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _loadList(reset: true));
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (r == null) return;
    setState(() => _range = r);
    _loadList(reset: true);
  }

  Future<void> _exportCsv() async {
    if (!adminCan('transactions:export')) {
      dpSnack(context, "Your role can't export transactions.", error: true);
      return;
    }
    dpSnack(context, 'Preparing export…');
    try {
      final csv = await api.getText('/api/admin/vtpass/transactions.csv', query: _query);
      final name = 'vtpass-transactions-${isoDay(DateTime.now())}.csv';
      try {
        await Share.shareXFiles([XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: name)], subject: name);
      } catch (_) {
        await Share.share(csv, subject: name);
      }
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _editRate() async {
    final rate = toDouble(_summary?['commissionRate'] ?? 1.8);
    final c = TextEditingController(text: rate.toString());
    final saved = await showAdminSheet<double>(
      context,
      title: 'VTpass commission rate',
      builder: (ctx, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What VTpass pays Dalabapay on each successful payment. Used when VTpass doesn't report the commission itself.",
              style: DP.caption.copyWith(height: 1.4),
            ),
            const SizedBox(height: 14),
            DPField(
              controller: c,
              hint: '1.8',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffix: const Padding(padding: EdgeInsets.only(right: 14), child: Text('%')),
            ),
            const SizedBox(height: 16),
            DPButton(
              label: 'Save rate',
              onPressed: () {
                final v = double.tryParse(c.text.trim());
                if (v == null || v < 0 || v > 20) {
                  dpSnack(ctx, 'Enter a rate between 0% and 20%', error: true);
                  return;
                }
                Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
      ),
    );
    if (saved == null) return;
    try {
      await api.patch('/api/admin/vtpass/settings', {'commissionRate': saved});
      if (!mounted) return;
      dpSnack(context, 'Commission rate set to $saved%');
      _loadSummary();
      if (_tab == 1) _loadList(reset: true);
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'VTpass Portal',
      breadcrumb: 'Admin · Providers · VTpass',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _loadSummary();
            _loadList(reset: true);
          },
          icon: Icon(Icons.refresh_rounded, color: DP.navyInk, size: 20),
        ),
        IconButton(
          tooltip: 'Provider settings',
          onPressed: () => Navigator.pushNamed(context, '/admin/vtpass'),
          icon: Icon(Icons.tune_rounded, color: DP.navyInk, size: 20),
        ),
      ],
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: _tabs()),
          Expanded(child: _tab == 0 ? _overview() : _transactions()),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int i, String label, IconData icon) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_tab == i) return;
            setState(() => _tab = i);
            if (i == 1 && _items.isEmpty && widget.initialTransactions == null) _loadList(reset: true);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: on ? DP.navyGradient : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: on ? Colors.white : DP.muted),
                const SizedBox(width: 6),
                Text(label, style: DP.bodyStrong.copyWith(fontSize: 13.5, color: on ? Colors.white : DP.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DP.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DP.border),
      ),
      child: Row(children: [
        tab(0, 'Overview', Icons.space_dashboard_rounded),
        tab(1, 'Transactions', Icons.receipt_long_rounded),
      ]),
    );
  }

  // ════════════════════════ OVERVIEW ════════════════════════
  Widget _overview() {
    final s = _summary;
    if (s == null) {
      return Center(
        child: _summaryError == null
            ? const CircularProgressIndicator(color: _green)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(errorMessage(_summaryError!), textAlign: TextAlign.center, style: DP.body),
                  TextButton(onPressed: _loadSummary, child: const Text('Retry')),
                ]),
              ),
      );
    }
    final counts = asMap(s['counts']);
    final c = asMap(s['commission']);
    final rate = toDouble(s['commissionRate']);
    final sr = s['successRate'];
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          DPAppear(child: _hero(s)),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in _periods.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DPChip(
                      label: e.value,
                      selected: _period == e.key,
                      height: 36,
                      onTap: () {
                        if (_period == e.key) return;
                        setState(() => _period = e.key);
                        _loadSummary();
                      },
                    ),
                  ),
                if (_loadingSummary)
                  const Padding(
                    padding: EdgeInsets.all(9),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminStatGrid(stats: [
            AdminStat(label: 'Transactions', value: '${toInt(counts['total'])}', icon: Icons.receipt_long_rounded, color: _blue, sub: '${toInt(counts['success'])} successful'),
            AdminStat(label: 'Successful volume', value: _money(toDouble(s['volume'])), icon: Icons.payments_rounded, color: _green, sub: 'Avg ${_money(toDouble(s['averagePayment']))}'),
            AdminStat(label: 'Commission earned', value: _money(toDouble(c['earned']), dec: true), icon: Icons.savings_rounded, color: _purple, sub: '${_pct(rate)}% from VTpass'),
            AdminStat(label: 'Success rate', value: sr == null ? '—' : '${toDouble(sr).toStringAsFixed(1)}%', icon: Icons.verified_rounded, color: sr != null && toDouble(sr) < 90 ? _red : _green, sub: '${toInt(counts['failed'])} failed'),
            AdminStat(label: 'Paid to customers', value: _money(toDouble(c['paidToUsers']), dec: true), icon: Icons.volunteer_activism_rounded, color: _amber, sub: 'Customer commission'),
            AdminStat(label: 'Net earnings', value: _money(toDouble(c['net']), dec: true), icon: Icons.trending_up_rounded, color: toDouble(c['net']) < 0 ? _red : _green, sub: 'Commission − paid out'),
          ]),
          const SizedBox(height: 14),
          DPAppear(delay: const Duration(milliseconds: 80), child: _chartCard(s)),
          const SizedBox(height: 14),
          DPAppear(delay: const Duration(milliseconds: 140), child: _statusCard(counts)),
          const SizedBox(height: 14),
          DPAppear(delay: const Duration(milliseconds: 200), child: _servicesCard(s)),
          const SizedBox(height: 14),
          DPAppear(delay: const Duration(milliseconds: 260), child: _commissionCard(s)),
          const SizedBox(height: 14),
          DPAppear(delay: const Duration(milliseconds: 320), child: _failuresCard(s)),
        ],
      ),
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _card({required String title, Widget? trailing, required Widget child, String? subtitle}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: DP.surface,
          borderRadius: BorderRadius.circular(DP.rLg),
          border: Border.all(color: DP.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: DP.bodyStrong.copyWith(fontSize: 15)),
                  if (subtitle != null) Text(subtitle, style: DP.caption.copyWith(fontSize: 11.5)),
                ]),
              ),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _hero(Map<String, dynamic> s) {
    final p = asMap(s['provider']);
    final bal = s['balance'];
    final low = s['lowBalance'] == true;
    final live = str(p['environment']) == 'live';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: DP.navyGradient,
        borderRadius: BorderRadius.circular(DP.rXl),
        boxShadow: DP.glow(DP.navy, strength: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('VTpass wallet', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (live ? _green : _amber).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: live ? const Color(0xFF34D399) : _amber, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(live ? 'LIVE' : str(p['environment'], 'SANDBOX').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Available balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              bal == null ? 'Unavailable' : DP.naira(toDouble(bal)),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(low ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                size: 16, color: low ? const Color(0xFFFBBF24) : const Color(0xFF34D399)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                bal == null
                    ? "Couldn't read the balance from VTpass right now."
                    : low
                        ? 'Below your ${DP.naira(toDouble(s['lowBalanceThreshold']), decimals: false)} alert level. Top up on vtpass.com.'
                        : 'Healthy · alert below ${DP.naira(toDouble(s['lowBalanceThreshold']), decimals: false)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _label(String key, String unit, {bool long = false}) {
    final p = key.split('-').map(int.tryParse).toList();
    if (p.length < 2 || p.contains(null)) return key;
    if (unit == 'month') return long ? '${_months[p[1]! - 1]} ${p[0]}' : _months[p[1]! - 1];
    return long ? '${p[2]} ${_months[p[1]! - 1]} ${p[0]}' : '${p[2]}/${p[1]}';
  }

  Widget _chartCard(Map<String, dynamic> s) {
    final series = (s['series'] as List? ?? const []).map(asMap).toList();
    final unit = str(s['seriesUnit'], 'day');
    final vols = series.map((e) => toDouble(e['volume'])).toList();
    final earns = series.map((e) => toDouble(e['earned'])).toList();
    final sel = _bar != null && _bar! < series.length ? _bar : null;
    final every = series.length <= 8 ? 1 : (series.length / 6).ceil();
    return _card(
      title: 'Volume & commission',
      subtitle: sel == null
          ? (series.isEmpty ? 'No VTpass payments in this period' : 'Tap a bar for details')
          : '${_label(str(series[sel]['date']), unit, long: true)} · ${_money(vols[sel])} · commission ${_money(earns[sel], dec: true)} · ${toInt(series[sel]['success'])} ok / ${toInt(series[sel]['failed'])} failed',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _legend('Volume', _green),
        const SizedBox(width: 10),
        _legend('Commission', _purple),
      ]),
      child: Column(children: [
        SizedBox(
          height: 170,
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                if (series.isEmpty) return;
                final i = (d.localPosition.dx / box.maxWidth * series.length).floor().clamp(0, series.length - 1);
                setState(() => _bar = _bar == i ? null : i);
              },
              child: TweenAnimationBuilder<double>(
                key: ValueKey('chart-$_period-${series.length}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Stack(children: [
                  CustomPaint(
                    size: Size(box.maxWidth, 170),
                    painter: _VolumePainter(vols: vols, earns: earns, progress: t, selected: sel, grid: DP.borderSoft),
                  ),
                  if (vols.isNotEmpty && vols.reduce(math.max) > 0)
                    Positioned(left: 2, top: 0, child: Text(_short(vols.reduce(math.max)), style: DP.caption.copyWith(fontSize: 9.5))),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < series.length; i++)
            Expanded(
              child: Text(
                i % every == 0 || i == series.length - 1 ? _label(str(series[i]['date']), unit) : '',
                textAlign: TextAlign.center,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: DP.caption.copyWith(fontSize: 9.5, color: sel == i ? DP.ink : null, fontWeight: sel == i ? FontWeight.w700 : null),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _legend(String label, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: DP.caption.copyWith(fontSize: 11)),
      ]);

  Widget _statusCard(Map<String, dynamic> counts) {
    final parts = [
      ('Successful', toInt(counts['success']), _green),
      ('Failed', toInt(counts['failed']), _red),
      ('Pending', toInt(counts['pending']), _amber),
      ('Refunded', toInt(counts['refunded']), _blue),
    ];
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    return _card(
      title: 'Status breakdown',
      subtitle: '$total payments',
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: total == 0
                ? Container(color: DP.borderSoft)
                : Row(children: [
                    for (final p in parts)
                      if (p.$2 > 0) Expanded(flex: p.$2, child: Container(color: p.$3)),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: [
          for (final p in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('${p.$1} ', style: DP.caption),
              Text('${p.$2}', style: DP.bodyStrong.copyWith(fontSize: 13)),
              Text(total == 0 ? '' : '  ${(p.$2 / total * 100).toStringAsFixed(0)}%', style: DP.caption.copyWith(fontSize: 11)),
            ]),
        ]),
      ]),
    );
  }

  Widget _servicesCard(Map<String, dynamic> s) {
    final rows = (s['byService'] as List? ?? const []).map(asMap).toList();
    final maxV = rows.fold<double>(0, (a, r) => math.max(a, toDouble(r['volume'])));
    return _card(
      title: 'By service',
      subtitle: 'Successful volume and commission per biller',
      child: rows.isEmpty
          ? Text('No payments yet.', style: DP.caption)
          : Column(children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: _blue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_serviceIcon(str(r['service'])), size: 18, color: _blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text('${str(r['label'])} · ${toInt(r['success'])}/${toInt(r['count'])} ok',
                                style: DP.body.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          Text(_money(toDouble(r['volume'])), style: DP.bodyStrong.copyWith(fontSize: 13)),
                        ]),
                        const SizedBox(height: 5),
                        Row(children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxV == 0 ? 0 : toDouble(r['volume']) / maxV,
                                minHeight: 6,
                                color: _green,
                                backgroundColor: DP.borderSoft,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('+${_money(toDouble(r['earned']), dec: true)}', style: DP.caption.copyWith(fontSize: 11, color: _purple, fontWeight: FontWeight.w700)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }

  Widget _commissionCard(Map<String, dynamic> s) {
    final c = asMap(s['commission']);
    final rate = toDouble(s['commissionRate']);
    final canEdit = adminCan('commission:write');
    Widget line(String k, String v, {Color? color, bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(k, style: DP.body.copyWith(fontSize: 13.5))),
            Text(v, style: (strong ? DP.bodyStrong : DP.body).copyWith(fontSize: 13.5, color: color)),
          ]),
        );
    return _card(
      title: 'Commission statement',
      subtitle: 'What VTpass pays Dalabapay',
      trailing: canEdit
          ? TextButton.icon(onPressed: _editRate, icon: const Icon(Icons.edit_rounded, size: 16), label: Text('${_pct(rate)}%'))
          : Text('${_pct(rate)}%', style: DP.bodyStrong),
      child: Column(children: [
        line('Reported by VTpass (${toInt(c['reportedCount'])} payments)', _money(toDouble(c['reportedByVtpass']), dec: true)),
        line('Estimated at ${_pct(rate)}% (${toInt(c['estimatedCount'])} payments)', _money(toDouble(c['earned']) - toDouble(c['reportedByVtpass']), dec: true)),
        Divider(color: DP.border, height: 14),
        line('Total commission earned', _money(toDouble(c['earned']), dec: true), color: _purple, strong: true),
        line('Paid to customers', '− ${_money(toDouble(c['paidToUsers']), dec: true)}', color: _amber),
        Divider(color: DP.border, height: 14),
        line('Net to Dalabapay', _money(toDouble(c['net']), dec: true), color: toDouble(c['net']) < 0 ? _red : _green, strong: true),
      ]),
    );
  }

  Widget _failuresCard(Map<String, dynamic> s) {
    final rows = (s['topFailures'] as List? ?? const []).map(asMap).toList();
    return _card(
      title: 'Top failure reasons',
      subtitle: 'As reported by VTpass',
      trailing: rows.isEmpty
          ? null
          : TextButton(
              onPressed: () {
                setState(() {
                  _tab = 1;
                  _status = 'failed';
                });
                _loadList(reset: true);
              },
              child: const Text('View failed'),
            ),
      child: rows.isEmpty
          ? Row(children: [
              const Icon(Icons.celebration_rounded, color: _green, size: 18),
              const SizedBox(width: 8),
              Text('No failed payments in this period', style: DP.caption),
            ])
          : Column(children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _red.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                      child: Text('${toInt(r['count'])}×', style: const TextStyle(color: _red, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(str(r['reason']), style: DP.body.copyWith(fontSize: 13))),
                  ]),
                ),
            ]),
    );
  }

  // ═══════════════════════ TRANSACTIONS ═══════════════════════
  Widget _transactions() {
    const filters = {null: 'All', 'success': 'Successful', 'failed': 'Failed', 'pending': 'Pending', 'refunded': 'Refunded'};
    final total = toInt(_listMeta['total']);
    final totals = asMap(_listMeta['totals']);
    final more = _page < math.max(1, toInt(_listMeta['pages']));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Expanded(child: AdminSearch(hint: 'Reference, VTpass ID, customer, smartcard…', onChanged: _search)),
          const SizedBox(width: 8),
          _iconBtn(Icons.date_range_rounded, _range == null ? 'Dates' : '${_range!.start.day}/${_range!.start.month}–${_range!.end.day}/${_range!.end.month}', _pickRange, on: _range != null),
          const SizedBox(width: 8),
          _iconBtn(Icons.download_rounded, 'CSV', _exportCsv),
        ]),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in filters.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DPChip(
                  label: f.value,
                  selected: _status == f.key,
                  height: 34,
                  onTap: () {
                    setState(() => _status = f.key);
                    _loadList(reset: true);
                  },
                ),
              ),
            if (_range != null)
              DPChip(
                label: 'Clear dates ✕',
                selected: false,
                height: 34,
                onTap: () {
                  setState(() => _range = null);
                  _loadList(reset: true);
                },
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _purple.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            _totalCell('Payments', '$total'),
            _totalCell('Successful volume', _money(toDouble(totals['volume']))),
            _totalCell('Commission', _money(toDouble(totals['commission']), dec: true), color: _purple),
          ]),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _loadList(reset: true),
          child: _items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Center(
                    child: _loadingList
                        ? const CircularProgressIndicator(color: _green)
                        : Column(children: [
                            Icon(_listError == null ? Icons.receipt_long_outlined : Icons.cloud_off_rounded, size: 40, color: DP.muted),
                            const SizedBox(height: 8),
                            Text(_listError == null ? 'No VTpass payments match.' : errorMessage(_listError!), style: DP.caption),
                          ]),
                  ),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: _items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _items.length) {
                      if (!more) return Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('End of list', style: DP.caption)));
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: _loadingList
                              ? const CircularProgressIndicator(color: _green)
                              : OutlinedButton(
                                  onPressed: () {
                                    _page++;
                                    _loadList();
                                  },
                                  child: const Text('Load more'),
                                ),
                        ),
                      );
                    }
                    return _txnRow(_items[i]);
                  },
                ),
        ),
      ),
    ]);
  }

  Widget _totalCell(String k, String v, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: DP.caption.copyWith(fontSize: 10.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(v, style: DP.bodyStrong.copyWith(fontSize: 14, color: color)),
          ),
        ]),
      );

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap, {bool on = false}) => Material(
        color: on ? _blue.withValues(alpha: 0.12) : DP.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? _blue : DP.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: on ? _blue : DP.navyInk),
              const SizedBox(width: 4),
              Text(label, style: DP.caption.copyWith(fontWeight: FontWeight.w700, color: on ? _blue : DP.ink)),
            ]),
          ),
        ),
      );

  String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} · ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _txnRow(Map<String, dynamic> t) {
    final st = str(t['status']);
    final color = _statusColor(st);
    final u = asMap(t['user']);
    final vt = asMap(t['vtpass']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: DP.surface,
        borderRadius: BorderRadius.circular(DP.rLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(DP.rLg),
          onTap: () => _detail(t),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DP.rLg),
              border: Border(left: BorderSide(color: color, width: 3), top: BorderSide(color: DP.border), right: BorderSide(color: DP.border), bottom: BorderSide(color: DP.border)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
                  child: Icon(_serviceIcon(str(t['service'])), size: 19, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(t['description'], str(t['serviceLabel'])), style: DP.bodyStrong.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${str(u['fullName'], 'Unknown')} · ${str(t['recipient'])}', style: DP.caption.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_money(toDouble(t['amount']), dec: true), style: DP.bodyStrong.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  StatusPill(st.toUpperCase(), color: color),
                ]),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 13, color: DP.muted),
                const SizedBox(width: 4),
                Text(_when(str(t['createdAt'])), style: DP.caption.copyWith(fontSize: 11)),
                const SizedBox(width: 12),
                if (str(vt['transactionId']).isNotEmpty) ...[
                  Icon(Icons.tag_rounded, size: 13, color: DP.muted),
                  const SizedBox(width: 2),
                  Flexible(child: Text(str(vt['transactionId']), style: DP.caption.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
                const Spacer(),
                if (st == 'success')
                  Text('+${_money(toDouble(t['commission']), dec: true)}${t['commissionReported'] == true ? '' : ' est.'}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _purple)),
              ]),
              if (str(t['failureReason']).isNotEmpty && st != 'success') ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: _red.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${str(vt['code']).isEmpty ? '' : 'Code ${str(vt['code'])} · '}${str(t['failureReason'])}${t['refunded'] == true ? ' · refunded' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: _red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  void _detail(Map<String, dynamic> t) {
    final u = asMap(t['user']);
    final vt = asMap(t['vtpass']);
    final st = str(t['status']);
    Widget kv(String k, String v, {bool copy = false}) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: DP.caption)),
              Expanded(child: SelectableText(v, style: DP.body.copyWith(fontSize: 13.5))),
              if (copy)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: v));
                    dpSnack(context, 'Copied');
                  },
                  child: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.copy_rounded, size: 16, color: DP.muted)),
                ),
            ]),
          );
    showAdminSheet<void>(
      context,
      title: str(t['description'], 'VTpass payment'),
      builder: (ctx, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_money(toDouble(t['amount']), dec: true), style: DP.title.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            StatusPill(st.toUpperCase(), color: _statusColor(st)),
          ]),
          const SizedBox(height: 8),
          kv('Customer', '${str(u['fullName'])} · ${str(u['phone'])} (${str(u['country'])})'),
          kv('Service', str(t['serviceLabel'])),
          kv('Recipient', str(t['recipient']), copy: true),
          kv('Date', _when(str(t['createdAt']))),
          kv('Reference', str(t['reference']), copy: true),
          kv('VTpass ID', str(vt['transactionId']), copy: true),
          kv('VTpass code', str(vt['code'])),
          kv('VTpass status', str(vt['status'])),
          if (st == 'success') kv('Commission', '${_money(toDouble(t['commission']), dec: true)} ${t['commissionReported'] == true ? '(reported by VTpass)' : '(estimated)'}'),
          if (toDouble(t['userCommission']) > 0) kv('Paid to customer', _money(toDouble(t['userCommission']), dec: true)),
          kv('Failure reason', str(t['failureReason'])),
          if (t['refunded'] == true) kv('Refund', 'Refunded to the customer\'s wallet'),
          const SizedBox(height: 14),
          if ((st == 'pending' || st == 'processing') && adminCan('transactions:status'))
            DPButton(
              label: 'Requery VTpass now',
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final r = asMap(await api.post('/api/admin/transactions/${str(t['id'])}/requery'));
                  if (!mounted) return;
                  dpSnack(context, 'VTpass says: ${str(r['result'], 'checked')}');
                  _loadList(reset: true);
                  _loadSummary();
                } catch (e) {
                  if (mounted) dpSnack(context, errorMessage(e), error: true);
                }
              },
            ),
        ]),
      ),
    );
  }
}

/// Bars = successful volume; line = commission (own scale).
class _VolumePainter extends CustomPainter {
  final List<double> vols;
  final List<double> earns;
  final double progress;
  final int? selected;
  final Color grid;
  _VolumePainter({required this.vols, required this.earns, required this.progress, required this.selected, required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    final n = vols.length;
    if (n == 0) return;
    final maxV = vols.fold<double>(0, math.max);
    final maxE = earns.fold<double>(0, math.max);
    const top = 16.0;
    final h = size.height - top;
    final slot = size.width / n;
    final bw = math.max(2.0, math.min(22.0, slot * 0.55));
    for (var i = 0; i < n; i++) {
      final x = slot * i + (slot - bw) / 2;
      if (selected == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(slot * i + 1, 0, slot - 2, size.height), const Radius.circular(6)),
          Paint()..color = grid,
        );
      }
      if (maxV > 0 && vols[i] > 0) {
        final bh = math.max(2.0, h * vols[i] / maxV * progress);
        final dim = selected != null && selected != i;
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - bh, bw, bh), topLeft: Radius.circular(bw / 3), topRight: Radius.circular(bw / 3)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_green.withValues(alpha: dim ? 0.35 : 1), _green.withValues(alpha: dim ? 0.15 : 0.55)],
            ).createShader(Rect.fromLTWH(x, size.height - bh, bw, bh)),
        );
      }
    }
    if (maxE > 0) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final x = slot * i + slot / 2;
        final y = size.height - h * (earns[i] / maxE) * 0.9 * progress;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _purple
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
      if (n <= 31) {
        for (var i = 0; i < n; i++) {
          final x = slot * i + slot / 2;
          final y = size.height - h * (earns[i] / maxE) * 0.9 * progress;
          canvas.drawCircle(Offset(x, y), selected == i ? 4.5 : 2.6, Paint()..color = _purple);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_VolumePainter o) => o.progress != progress || o.selected != selected || o.vols != vols || o.earns != earns || o.grid != grid;
}
