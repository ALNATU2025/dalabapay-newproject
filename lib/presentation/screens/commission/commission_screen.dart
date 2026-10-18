// lib/presentation/screens/commission/commission_screen.dart
// Commission & earnings: GET /api/commission (balance, week chart, recent
// earnings) and POST /api/commission/withdraw to move them to the wallet.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/transaction_widgets.dart';

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  bool _isCommissionVisible = true;
  bool _isWithdrawing = false;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _referrals = {};
  bool _loading = true;
  Object? _error;

  double get _balance => toDouble(_data['balance']);
  double get _minWithdrawal => toDouble(_data['minWithdrawal'] ?? 500);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.get('/api/commission'),
        api.get('/api/referrals').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _data = asMap(results[0]);
        _referrals = asMap(results[1]);
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

  IconData _iconFor(Map<String, dynamic> t) {
    final type = str(t['type']);
    if (type == 'referral_bonus') return DPIcons.referral;
    if (type == 'commission_withdrawal') return DPIcons.upRight;
    return switch (str(t['service'])) {
      'airtime' || 'international' => DPIcons.phone,
      'data' => DPIcons.wifi,
      'electricity' => DPIcons.bolt,
      'cable' => DPIcons.tv,
      'education' => DPIcons.school,
      'insurance' => DPIcons.shield,
      _ => DPIcons.sparkle,
    };
  }

  Future<void> _withdraw() async {
    if (_balance < _minWithdrawal) {
      dpSnack(context,
          'You can move earnings once you have ${DP.naira(_minWithdrawal)} or more.');
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
    try {
      await api.post('/api/commission/withdraw');
      await Session.instance.refreshQuietly();
      await _load();
      if (!mounted) return;
      setState(() => _isWithdrawing = false);
      dpSnack(context, 'Earnings moved to your wallet', success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWithdrawing = false);
      dpSnack(context, errorMessage(e), error: true);
    }
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
                    'You earn a small commission on eligible payments like airtime, data, TV and electricity, plus referral bonuses. Earnings sit in a separate balance — move them to your wallet any time (minimum ${DP.naira(_minWithdrawal)}).',
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
    if (_loading) return const DPLoading();
    if (_error != null && _data.isEmpty) {
      return DPLoadError(error: _error, onRetry: _load);
    }
    final recent = asList(_data['recent']);
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
    return RefreshIndicator(
      color: DP.green,
      onRefresh: _load,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPAppear(child: _buildBalanceCard()),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Lifetime earned', toDouble(_data['lifetime'])),
              const SizedBox(width: 12),
              stat('Moved to wallet', toDouble(_data['movedToWallet'])),
            ],
          ),
          const SizedBox(height: 24),
          _buildWeek(),
          const SizedBox(height: 22),
          _buildReferralCard(),
          const SizedBox(height: 22),
          const DPSectionHeader('Latest earnings'),
          if (recent.isEmpty)
            const DPEmptyState(
              icon: DPIcons.sparkle,
              title: 'No earnings yet',
              message: 'Pay for airtime, data, TV or electricity to start earning.',
            )
          else
            for (final e in recent) _buildItem(e),
          const SizedBox(height: 16),
          Text(
            'Commission is credited after an eligible payment succeeds. Rates are shown before you pay.',
            style: DP.caption,
          ),
        ],
      ),
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
          if (_balance < _minWithdrawal)
            DPHelper(
              'You can move earnings once you have ${DP.naira(_minWithdrawal)} or more.',
              color: DP.green,
            ),
        ],
      ),
    );
  }

  Widget _buildWeek() {
    final week = asList(_data['week']);
    final now = DateTime.now();
    final totals = List.generate(
        7, (i) => i < week.length ? toDouble(week[i]['amount']) : 0.0);
    final days = List.generate(
        7,
        (i) => i < week.length
            ? DateTime.tryParse(str(week[i]['date'])) ??
                now.subtract(Duration(days: 6 - i))
            : now.subtract(Duration(days: 6 - i)));
    final weekTotal = totals.fold<double>(0, (a, b) => a + b);
    final maxV = totals.fold<double>(0, (a, b) => a > b ? a : b);
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
              final h = 10 + (maxV > 0 ? v / maxV : 0) * 70;
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
      onTap: () => Navigator.pushNamed(context, '/referral').then((_) => _load()),
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
                  '${toInt(_referrals['totalReferrals'])} referrals · ${DP.naira(toDouble(_referrals['totalEarned']))} earned · Code ${Session.instance.user?.referralCode ?? ''}',
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
                ClipboardData(text: Session.instance.user?.referralCode ?? ''),
              );
              dpSnack(context, 'Referral code copied', success: true);
            },
            icon: Icon(DPIcons.copy, color: DP.muted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> t) {
    final d = parseDate(t['createdAt']);
    final icon = _iconFor(t);
    // Moving earnings out reads as a debit here even though the wallet
    // receives it.
    final credit = t['type'] != 'commission_withdrawal' && txIsCredit(t);
    final amount = toDouble(t['amount']);
    return DPListRow(
      onTap: () => showTransactionReceipt(context, t),
      leading: credit
          ? DPIconBadge(icon, size: 42, iconSize: 20)
          : DPIconBadge.blue(icon, size: 42, iconSize: 20),
      title: str(t['description'], transactionTypeLabel(str(t['type']))),
      subtitle: '${dateLabel(d)} · ${str(t['reference'])}',
      trailing: Text(
        '${credit ? '+' : '−'}${DP.naira(amount, decimals: amount % 1 != 0)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: credit ? DP.green : DP.ink,
        ),
      ),
    );
  }
}
