// lib/presentation/screens/admin/admin_widgets.dart
// Shared building blocks for the admin console (UI only).
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Page frame used by every admin screen: top bar with an ADMIN badge and a
/// breadcrumb under the title.
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  DPIconSquare(
                    icon: DPIcons.back,
                    size: 40,
                    background: Colors.transparent,
                    semanticLabel: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
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
                                style: DP.title.copyWith(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const AdminBadge(),
                          ],
                        ),
                        Text(
                          breadcrumb,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DP.caption.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: bottom,
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

/// Small stat card: icon, value, label.
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
    return DPCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
              if (sub != null)
                Text(
                  sub!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sub!.startsWith('-') ? DP.red : DP.green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: DP.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DP.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Two stat cards per row.
class AdminStatGrid extends StatelessWidget {
  final List<Widget> stats;
  const AdminStatGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < stats.length ? 10 : 0),
          child: Row(
            children: [
              Expanded(child: stats[i]),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < stats.length ? stats[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
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
                      width: 20,
                      height: value,
                      decoration: BoxDecoration(
                        color: last ? color : color.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(6),
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
    return DPCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: DP.borderSoft),
            children[i],
          ],
        ],
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
