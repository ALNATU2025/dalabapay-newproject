// lib/presentation/screens/commission/commission_screen.dart
// Commission & earnings — UI only, sample earnings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';

class _Earning {
  final String title;
  final String source; // airtime, data, electricity, cable, referral, wallet
  final double amount;
  final bool credit;
  final int daysAgo;
  final String ref;
  const _Earning(
    this.title,
    this.source,
    this.amount,
    this.credit,
    this.daysAgo,
    this.ref,
  );
}

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  bool _isCommissionVisible = true;
  bool _isWithdrawing = false;
  double _balance = MockUser.commissionBalance;

  static const _earnings = [
    _Earning('MTN airtime commission', 'airtime', 40, true, 0, 'CM-10482'),
    _Earning('Airtel data commission', 'data', 75, true, 1, 'CM-10477'),
    _Earning('Referral bonus — Chidi Eze', 'referral', 500, true, 3, 'RF-2201'),
    _Earning('Moved to wallet', 'wallet', 2000, false, 3, 'WD-0915'),
    _Earning('DSTV commission', 'cable', 157, true, 4, 'CM-10451'),
    _Earning('Ikeja Electric commission', 'electricity', 50, true, 5, 'CM-10440'),
    _Earning('Glo airtime commission', 'airtime', 20, true, 6, 'CM-10431'),
  ];

  IconData _iconFor(String s) => switch (s) {
        'airtime' => DPIcons.phone,
        'data' => DPIcons.wifi,
        'electricity' => DPIcons.bolt,
        'cable' => DPIcons.tv,
        'referral' => DPIcons.referral,
        _ => DPIcons.upRight,
      };

  Future<void> _withdraw() async {
    if (_balance < 500) {
      dpSnack(context, 'You can move earnings once you have ₦500 or more.');
      return;
    }
    final ok = await dpDialog(
      context,
      title: 'Move to wallet?',
      message: '${DP.naira(_balance)} will be added to your wallet balance.',
      confirmLabel: 'Move ${DP.naira(_balance)}',
      cancelLabel: 'Cancel',
      tone: DPTone.info,
    );
    if (ok != true || !mounted) return;
    setState(() => _isWithdrawing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isWithdrawing = false;
      _balance = 0;
    });
    dpSnack(context, 'Earnings moved to your wallet', success: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Commission & earnings',
              actionLabel: 'How it works',
              onAction: () => dpDialog(
                context,
                title: 'How earnings work',
                message:
                    'You earn a small commission on eligible payments like airtime, data, TV and electricity, plus referral bonuses. Earnings sit in a separate balance — move them to your wallet any time (minimum ₦500).',
                confirmLabel: 'Got it',
                tone: DPTone.info,
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget stat(String label, double v) => Expanded(
          child: DPCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DP.caption.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DP.naira(v, decimals: v % 1 != 0),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: DP.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPAppear(child: _buildBalanceCard()),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Lifetime earned', MockUser.totalEarned),
              const SizedBox(width: 12),
              stat('Moved to wallet', 15339.50),
            ],
          ),
          const SizedBox(height: 24),
          _buildWeek(),
          const SizedBox(height: 22),
          _buildReferralCard(),
          const SizedBox(height: 22),
          const DPSectionHeader('Latest earnings'),
          for (final e in _earnings) _buildItem(e),
          const SizedBox(height: 16),
          Text(
            'Commission is credited after an eligible payment succeeds. Rates are shown before you pay.',
            style: DP.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: DP.mint,
        borderRadius: BorderRadius.circular(DP.rXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(DPIcons.sparkle, color: DP.green, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AVAILABLE EARNINGS',
                  style: TextStyle(
                    color: DP.green,
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkResponse(
                radius: 18,
                onTap: () => setState(
                  () => _isCommissionVisible = !_isCommissionVisible,
                ),
                child: Icon(
                  _isCommissionVisible ? DPIcons.eye : DPIcons.eyeOff,
                  color: DP.green,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _isCommissionVisible ? DP.naira(_balance) : '₦ ••••',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w500,
                color: DP.green,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Earned funds are separate from your wallet.',
            style: TextStyle(color: DP.green, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          DPButton(
            label: 'Move to wallet',
            icon: DPIcons.upRight,
            loading: _isWithdrawing,
            onPressed: _isWithdrawing ? null : _withdraw,
          ),
          if (_balance < 500)
            const DPHelper(
              'You can move earnings once you have ₦500 or more.',
              color: DP.green,
            ),
        ],
      ),
    );
  }

  Widget _buildWeek() {
    const totals = [60.0, 135.0, 20.0, 157.0, 500.0, 75.0, 40.0];
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final weekTotal = totals.fold<double>(0, (a, b) => a + b);
    final maxV = totals.reduce((a, b) => a > b ? a : b);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('This week', style: DP.section)),
            Text(
              '${DP.naira(weekTotal, decimals: false)} earned',
              style: const TextStyle(
                color: DP.green,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final v = totals[i];
              final h = 10 + (v / maxV) * 70;
              final isToday = i == 6;
              return Expanded(
                child: Tooltip(
                  message: DP.naira(v),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 10, end: h),
                        duration: Duration(milliseconds: 500 + i * 60),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => Container(
                          width: 22,
                          height: value,
                          decoration: BoxDecoration(
                            color: isToday ? DP.green : DP.mint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[days[i].weekday - 1],
                        style: DP.caption.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralCard() {
    return DPCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () => Navigator.pushNamed(context, '/referral'),
      child: Row(
        children: [
          const DPIconBadge.blue(DPIcons.referral, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite friends, earn more', style: DP.bodyStrong),
                SizedBox(height: 2),
                Text(
                  '${MockUser.referrals} referrals · ₦1,500.00 earned · Code ${MockUser.referralCode}',
                  style: DP.caption,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: MockUser.referralCode),
              );
              dpSnack(context, 'Referral code copied', success: true);
            },
            icon: Icon(DPIcons.copy, color: DP.muted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_Earning e) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now().subtract(Duration(days: e.daysAgo));
    final icon = _iconFor(e.source);
    return DPListRow(
      leading: e.credit
          ? DPIconBadge(icon, size: 42, iconSize: 20)
          : DPIconBadge.blue(icon, size: 42, iconSize: 20),
      title: e.title,
      subtitle: '${d.day} ${months[d.month - 1]} · ${e.ref}',
      trailing: Text(
        '${e.credit ? '+' : '−'}${DP.naira(e.amount, decimals: e.amount % 1 != 0)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: e.credit ? DP.green : DP.ink,
        ),
      ),
    );
  }
}
