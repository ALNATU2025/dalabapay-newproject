// lib/presentation/widgets/transactions_dashboard.dart
// Transaction records dashboard on the Transactions page (Nigeria and
// Sierra Leone): money in / out, net, commission, success / pending /
// failed counts, a money in vs out chart and spending by category.
// GET /api/transactions/summary?period=7d|30d|90d|year
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/format.dart';
import '../../ui/ui.dart';

class TransactionsDashboard extends StatefulWidget {
  /// Bump this to reload (pull to refresh, after a payment).
  final int refreshToken;

  /// Data to show without loading (tests and screenshots).
  @visibleForTesting
  final Map<String, dynamic>? initialData;

  const TransactionsDashboard({super.key, this.refreshToken = 0, this.initialData});

  @override
  State<TransactionsDashboard> createState() => _TransactionsDashboardState();
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.label, this.icon, this.color);
}

const _cats = {
  'airtime': _Cat('Airtime', Icons.phone_android_rounded, Color(0xFF2779FD)),
  'data': _Cat('Data', Icons.wifi_rounded, Color(0xFF079A68)),
  'electricity': _Cat('Electricity', Icons.bolt_rounded, Color(0xFFF59E0B)),
  'cable': _Cat('Cable TV', Icons.live_tv_rounded, Color(0xFF7C3AED)),
  'education': _Cat('Education', Icons.school_rounded, Color(0xFF0EA5E9)),
  'insurance': _Cat('Insurance', Icons.health_and_safety_rounded, Color(0xFFEC4899)),
  'transfers': _Cat('Transfers', Icons.north_east_rounded, Color(0xFF6366F1)),
  'cards': _Cat('Dollar Card', Icons.credit_card_rounded, Color(0xFF14B8A6)),
  'other': _Cat('Other', Icons.more_horiz_rounded, Color(0xFF94A3B8)),
};

const _inColor = Color(0xFF079A68);
const _outColor = Color(0xFFE5484D);

class _TransactionsDashboardState extends State<TransactionsDashboard> {
  static const _periods = {'7d': '7 days', '30d': '30 days', '90d': '3 months', 'year': '12 months'};
  String _period = '30d';
  Map<String, dynamic>? _data;
  bool _loading = true;
  Object? _error;
  int _req = 0;
  int? _selected; // tapped bar

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _period = str(widget.initialData!['period'], '30d');
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(TransactionsDashboard old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final id = ++_req;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = asMap(await api.get('/api/transactions/summary', query: {'period': _period}));
      if (!mounted || id != _req) return;
      setState(() {
        _data = r;
        _loading = false;
        _selected = null;
      });
    } catch (e) {
      if (!mounted || id != _req) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  String get _cur => str(_data?['currency']).isEmpty ? DP.currency : str(_data?['currency']);
  String _money(num v, {bool decimals = true}) => DP.moneyIn(v, _cur, decimals: decimals);

  String _short(num v) {
    final a = v.abs();
    final sym = DP.symbolFor(_cur);
    final sep = sym == 'Le' ? ' ' : '';
    if (a >= 1e6) return '$sym$sep${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)}M';
    if (a >= 1e3) return '$sym$sep${(v / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}k';
    return '$sym$sep${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Transaction Records', style: DP.title)),
            if (_loading && _data != null)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: DP.green),
              ),
          ],
        ),
        const SizedBox(height: 10),
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
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _body(),
        ),
      ],
    );
  }

  Widget _body() {
    if (_data == null && _loading) {
      return const SizedBox(
        key: ValueKey('loading'),
        height: 180,
        child: Center(child: CircularProgressIndicator(color: DP.green)),
      );
    }
    if (_data == null) {
      return DPCard(
        key: const ValueKey('error'),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: DP.red),
            const SizedBox(width: 10),
            Expanded(child: Text(errorMessage(_error ?? 'Could not load your records'), style: DP.caption)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final d = _data!;
    return Column(
      key: ValueKey('data-$_period'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DPAppear(child: _totals(d)),
        const SizedBox(height: 12),
        DPAppear(delay: const Duration(milliseconds: 80), child: _countsRow(d)),
        const SizedBox(height: 12),
        DPAppear(delay: const Duration(milliseconds: 160), child: _chartCard(d)),
        const SizedBox(height: 12),
        DPAppear(delay: const Duration(milliseconds: 240), child: _categoriesCard(d)),
      ],
    );
  }

  // ── Money in / out ────────────────────────────────────────
  Widget _totals(Map<String, dynamic> d) {
    final prev = asMap(d['previous']);
    final net = toDouble(d['net']);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statTile('Money in', toDouble(d['moneyIn']), toDouble(prev['moneyIn']),
                  Icons.south_west_rounded, _inColor, goodWhenUp: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile('Money out', toDouble(d['moneyOut']), toDouble(prev['moneyOut']),
                  Icons.north_east_rounded, _outColor, goodWhenUp: false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DPCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: _miniFigure(
                  'Net flow',
                  DPCountUp(
                    value: net,
                    format: (v) => '${v >= 0 ? '+' : '−'}${_money(v.abs())}',
                    style: DP.bodyStrong.copyWith(color: net >= 0 ? _inColor : _outColor),
                  ),
                ),
              ),
              Container(width: 1, height: 34, color: DP.border),
              const SizedBox(width: 14),
              Expanded(
                child: _miniFigure(
                  'Commission earned',
                  DPCountUp(
                    value: toDouble(d['commissionEarned']),
                    format: (v) => _money(v),
                    style: DP.bodyStrong.copyWith(color: const Color(0xFF7C3AED)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniFigure(String label, Widget value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DP.caption),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
        ],
      );

  Widget _statTile(String label, double value, double previous, IconData icon, Color color,
      {required bool goodWhenUp}) {
    final change = previous > 0 ? (value - previous) / previous * 100 : null;
    final up = (change ?? 0) >= 0;
    final good = up == goodWhenUp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DP.surface,
        borderRadius: BorderRadius.circular(DP.rLg),
        border: Border.all(color: DP.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.10), DP.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (good ? _inColor : _outColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 11, color: good ? _inColor : _outColor),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs() >= 1000 ? '999+' : change.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: good ? _inColor : _outColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, style: DP.caption),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DPCountUp(
              value: value,
              format: (v) => _money(v),
              style: DP.bodyStrong.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (change != null)
            Text('vs previous ${_periods[_period]}', style: DP.caption.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }

  // ── Counts ────────────────────────────────────────────────
  Widget _countsRow(Map<String, dynamic> d) {
    final c = asMap(d['counts']);
    Widget pill(String label, int n, Color color, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(DP.rMd),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text('$n', style: DP.bodyStrong.copyWith(color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(label, style: DP.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        pill('Total', toInt(c['total']), DP.blue, Icons.receipt_long_rounded),
        const SizedBox(width: 8),
        pill('Successful', toInt(c['success']), _inColor, Icons.check_circle_rounded),
        const SizedBox(width: 8),
        pill('Pending', toInt(c['pending']), DP.amber, Icons.schedule_rounded),
        const SizedBox(width: 8),
        pill('Failed', toInt(c['failed']), _outColor, Icons.cancel_rounded),
      ],
    );
  }

  // ── Chart ─────────────────────────────────────────────────
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _bucketLabel(String iso, String unit, {bool long = false}) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    if (unit == 'month') return long ? '${_months[d.month - 1]} ${d.year}' : _months[d.month - 1];
    if (unit == 'week') return long ? 'Week of ${d.day} ${_months[d.month - 1]}' : '${d.day}/${d.month}';
    return long ? '${d.day} ${_months[d.month - 1]} ${d.year}' : '${d.day}';
  }

  Widget _chartCard(Map<String, dynamic> d) {
    final series = (d['series'] as List? ?? const []).map(asMap).toList();
    final unit = str(d['unit']);
    final ins = series.map((s) => toDouble(s['in'])).toList();
    final outs = series.map((s) => toDouble(s['out'])).toList();
    final maxV = [...ins, ...outs].fold<double>(0, math.max);
    final sel = _selected != null && _selected! < series.length ? _selected : null;
    final labelEvery = series.length <= 7 ? 1 : (series.length <= 14 ? 2 : (series.length <= 31 ? 5 : 2));

    return DPCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Money in vs out', style: DP.bodyStrong)),
              _legendDot('In', _inColor),
              const SizedBox(width: 10),
              _legendDot('Out', _outColor),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 20,
            child: Text(
              sel == null
                  ? (maxV == 0 ? 'No completed payments yet' : 'Tap a bar for details')
                  : '${_bucketLabel(str(series[sel]['date']), unit, long: true)} · In ${_money(ins[sel])} · Out ${_money(outs[sel])}',
              style: DP.caption.copyWith(fontSize: 11.5, color: sel == null ? null : DP.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (t) {
                  if (series.isEmpty) return;
                  final i = (t.localPosition.dx / box.maxWidth * series.length).floor().clamp(0, series.length - 1);
                  setState(() => _selected = _selected == i ? null : i);
                },
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('chart-$_period-${d['to']}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Stack(
                    children: [
                      CustomPaint(
                        size: Size(box.maxWidth, 150),
                        painter: _BarsPainter(
                          ins: ins,
                          outs: outs,
                          maxV: maxV,
                          progress: t,
                          selected: sel,
                          grid: DP.borderSoft,
                        ),
                      ),
                      if (maxV > 0)
                        Positioned(
                          left: 2,
                          top: 1,
                          child: Text(_short(maxV), style: DP.caption.copyWith(fontSize: 9.5)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < series.length; i++)
                Expanded(
                  child: Text(
                    i % labelEvery == 0 || i == series.length - 1 ? _bucketLabel(str(series[i]['date']), unit) : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: DP.caption.copyWith(
                      fontSize: 9.5,
                      color: sel == i ? DP.ink : null,
                      fontWeight: sel == i ? FontWeight.w700 : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color c) => Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: DP.caption.copyWith(fontSize: 11)),
        ],
      );

  // ── Spending by category ─────────────────────────────────
  Widget _categoriesCard(Map<String, dynamic> d) {
    final cats = (d['categories'] as List? ?? const []).map(asMap).toList();
    final total = toDouble(d['moneyOut']);
    return DPCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by category', style: DP.bodyStrong),
          const SizedBox(height: 14),
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 36, color: DP.muted),
                    const SizedBox(height: 6),
                    Text('No spending in the last ${_periods[_period]}', style: DP.caption),
                  ],
                ),
              ),
            )
          else ...[
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('donut-$_period-${d['to']}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => CustomPaint(
                    painter: _DonutPainter(
                      values: cats.map((c) => toDouble(c['amount'])).toList(),
                      colors: cats.map((c) => (_cats[str(c['key'])] ?? _cats['other']!).color).toList(),
                      progress: t,
                      track: DP.borderSoft,
                    ),
                    child: child,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Spent', style: DP.caption),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: FittedBox(
                            child: Text(_short(total), style: DP.title.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final c in cats) _categoryRow(c),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(Map<String, dynamic> c) {
    final cat = _cats[str(c['key'])] ?? _cats['other']!;
    final share = toDouble(c['share']);
    final n = toInt(c['count']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, size: 18, color: cat.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${str(c['label']).isEmpty ? cat.label : str(c['label'])} · $n ${n == 1 ? 'payment' : 'payments'}',
                        style: DP.body.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_money(toDouble(c['amount'])), style: DP.bodyStrong.copyWith(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: share / 100),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 6,
                            color: cat.color,
                            backgroundColor: DP.borderSoft,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text('${share.toStringAsFixed(share < 10 ? 1 : 0)}%',
                          textAlign: TextAlign.right, style: DP.caption.copyWith(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> ins;
  final List<double> outs;
  final double maxV;
  final double progress;
  final int? selected;
  final Color grid;

  _BarsPainter({
    required this.ins,
    required this.outs,
    required this.maxV,
    required this.progress,
    required this.selected,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final n = ins.length;
    if (n == 0 || maxV <= 0) return;
    final slot = size.width / n;
    final barW = math.max(1.5, math.min(14.0, slot * 0.34));
    final gap = math.min(2.0, slot * 0.06);
    final top = 16.0; // room for the max label
    final h = size.height - top;
    void bar(double x, double v, Color c, bool dim) {
      if (v <= 0) return;
      final bh = math.max(2.0, h * (v / maxV) * progress);
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - bh, barW, bh),
        topLeft: Radius.circular(barW / 2.5),
        topRight: Radius.circular(barW / 2.5),
      );
      canvas.drawRRect(r, Paint()..color = dim ? c.withValues(alpha: 0.3) : c);
    }

    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final dim = selected != null && selected != i;
      if (selected == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(slot * i + 1, 0, slot - 2, size.height), const Radius.circular(6)),
          Paint()..color = grid.withValues(alpha: 0.9),
        );
      }
      bar(cx - barW - gap / 2, ins[i], _inColor, dim);
      bar(cx + gap / 2, outs[i], _outColor, dim);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress || old.selected != selected || old.ins != ins || old.outs != outs || old.grid != grid;
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final Color track;

  _DonutPainter({required this.values, required this.colors, required this.progress, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var start = -math.pi / 2;
    final sweepAll = math.pi * 2 * progress;
    final gap = values.length > 1 ? 0.04 : 0.0;
    for (var i = 0; i < values.length; i++) {
      final sweep = sweepAll * values[i] / total;
      if (sweep > gap) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt
            ..color = colors[i],
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.values != values || old.track != track;
}
