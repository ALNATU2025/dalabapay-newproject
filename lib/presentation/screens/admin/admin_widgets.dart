// lib/presentation/screens/admin/admin_widgets.dart
// Shared building blocks for the admin console.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Page frame used by every admin screen: a navy header with soft rings,
/// the title, an ADMIN badge and a breadcrumb; the page fades in below.
class AdminScaffold extends StatelessWidget {
  final String title;
  final String breadcrumb;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottom;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.breadcrumb,
    required this.body,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: DP.navyGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
              boxShadow: DP.glow(DP.navy, strength: 0.6),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
              child: Stack(
                children: [
                  Positioned(right: -50, top: -60, child: _Ring(size: 180, opacity: 0.08)),
                  Positioned(right: 70, bottom: -70, child: _Ring(size: 120, opacity: 0.06)),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 16),
                      child: Row(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Back',
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => Navigator.of(context).maybePop(),
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(DPIcons.back, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const AdminBadge(),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  breadcrumb,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          if (actions.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: DP.surface,
                                borderRadius: BorderRadius.circular(DP.rPill),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: DPAppear(offsetY: 10, child: body)),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

class _Ring extends StatelessWidget {
  final double size;
  final double opacity;
  const _Ring({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 16),
        ),
      );
}

/// Counts up to the number inside [text] ("₦12,500", "24", "Le 3.50"),
/// keeping its prefix, suffix, commas and decimals.
class AdminCountUp extends StatelessWidget {
  final String text;
  final TextStyle style;
  const AdminCountUp(this.text, {super.key, required this.style});

  static final _re = RegExp(r'^(\D*?)(-?[\d,]+(?:\.\d+)?)(.*)$');

  static String _format(double v, int decimals) {
    final fixed = v.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${v < 0 ? '-' : ''}$whole${decimals > 0 ? '.${parts[1]}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final m = _re.firstMatch(text);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (m == null || still) return Text(text, style: style, maxLines: 1);
    final raw = m.group(2)!;
    final target = double.tryParse(raw.replaceAll(',', '')) ?? 0;
    final decimals = raw.contains('.') ? raw.split('.').last.length : 0;
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${m.group(1)}${_format(v, decimals)}${m.group(3)}', style: style, maxLines: 1),
    );
  }
}

class AdminBadge extends StatelessWidget {
  final String label;
  const AdminBadge({super.key, this.label = 'ADMIN'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DP.green, DP.greenDeep]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Stat card: icon in a gradient circle, a counting-up value, a label and
/// an optional change ("+12%", "-3%").
class AdminStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  const AdminStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = DP.navyIcon,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final down = sub != null && sub!.trim().startsWith('-');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: DP.surface,
        borderRadius: BorderRadius.circular(DP.rLg),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: DP.isDark ? 0.18 : 0.10), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.85), color],
                  ),
                  boxShadow: DP.glow(color, strength: 0.5),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const Spacer(),
              if (sub != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (down ? DP.red : DP.green).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(DP.rPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(down ? Icons.trending_down_rounded : Icons.trending_up_rounded, size: 13, color: down ? DP.red : DP.green),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            sub!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: down ? DP.red : DP.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AdminCountUp(
              value,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: DP.ink, letterSpacing: -0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DP.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Stat cards in a grid: two per row on phones, four on wide screens;
/// they rise in one after another.
class AdminStatGrid extends StatelessWidget {
  final List<Widget> stats;
  const AdminStatGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 760 ? 4 : 2;
      final rows = <Widget>[];
      for (var i = 0; i < stats.length; i += cols) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(bottom: i + cols < stats.length ? 12 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(
                      child: i + j < stats.length
                          ? DPAppear(delay: DPMotion.stagger(i + j, stepMs: 70), child: stats[i + j])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
      return Column(children: rows);
    });
  }
}

/// Coloured status pill (Successful, Pending, Failed, Active…).
class StatusPill extends StatelessWidget {
  final String text;
  final Color? color;
  const StatusPill(this.text, {super.key, this.color});

  static Color colorFor(String s) {
    final t = s.toLowerCase();
    if (t.contains('success') ||
        t.contains('active') && !t.contains('inactive') ||
        t.contains('resolved') ||
        t.contains('approved') ||
        t.contains('verified') ||
        t.contains('healthy') ||
        t.contains('live')) {
      return DP.green;
    }
    if (t.contains('pend') ||
        t.contains('await') ||
        t.contains('review') ||
        t.contains('warning') ||
        t.contains('sandbox')) {
      return DP.amber;
    }
    if (t.contains('refund')) return DP.navyIcon;
    if (t.contains('fail') ||
        t.contains('inactive') ||
        t.contains('reject') ||
        t.contains('locked') ||
        t.contains('disput') ||
        t.contains('critical')) {
      return DP.red;
    }
    return DP.navyIcon;
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? colorFor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DP.rPill),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}

/// Search box used on admin lists.
class AdminSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AdminSearch({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 15, color: DP.ink),
      decoration: DPField.decoration(
        hint: hint,
        prefix: const Icon(DPIcons.search, size: 20),
      ),
    );
  }
}

/// Simple animated bar chart for the last 7 days.
class AdminBarChart extends StatelessWidget {
  final List<double> values;
  final String Function(double) format;
  final Color color;
  const AdminBarChart({
    super.key,
    required this.values,
    required this.format,
    this.color = DP.green,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final h = maxV <= 0 ? 8.0 : 8 + (v / maxV) * 84;
          final day = now.subtract(Duration(days: values.length - 1 - i));
          final last = i == values.length - 1;
          return Expanded(
            child: Tooltip(
              message: format(v),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 8, end: h),
                    duration: Duration(milliseconds: 500 + i * 60),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => Container(
                      width: 22,
                      height: value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: last
                              ? [color, color.withValues(alpha: 0.75)]
                              : [color.withValues(alpha: 0.30), color.withValues(alpha: 0.14)],
                        ),
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: last ? DP.glow(color, strength: 0.45) : const [],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[day.weekday - 1],
                    style: DP.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Bottom sheet frame with a handle and title.
Future<T?> showAdminSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext ctx, StateSetter setSheet) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DP.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DPSheetHandle(),
                  const SizedBox(height: 8),
                  Text(title, style: DP.title),
                  const SizedBox(height: 14),
                  builder(ctx, setSheet),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One user row with avatar, name, email and trailing widget.
class AdminUserRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const AdminUserRow({
    super.key,
    required this.name,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DPListRow(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: DPAvatar(name: name, size: 42),
      title: name,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

/// Wraps a list of rows in a card with dividers.
class AdminListCard extends StatelessWidget {
  final List<Widget> children;
  const AdminListCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return DPAppear(
      offsetY: 14,
      child: DPCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: DP.borderSoft),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Quick-amount chips (₦1,000 … ₦50,000) that fill a controller.
class QuickAmounts extends StatelessWidget {
  final TextEditingController controller;
  final List<int> amounts;
  final VoidCallback? onChanged;
  const QuickAmounts({
    super.key,
    required this.controller,
    this.amounts = const [1000, 5000, 10000, 50000],
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = amounts.map((a) => DP.naira(a, decimals: false)).toList();
    final cur = int.tryParse(controller.text.trim());
    return DPChipGrid(
      options: labels,
      columns: 4,
      height: 40,
      selected: cur != null && amounts.contains(cur)
          ? DP.naira(cur, decimals: false)
          : null,
      onSelect: (l) {
        controller.text = amounts[labels.indexOf(l)].toString();
        onChanged?.call();
      },
    );
  }
}
