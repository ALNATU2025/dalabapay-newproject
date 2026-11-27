// lib/presentation/screens/sierra_leone/sl_withdraw_screen.dart
// Withdraw from the Dalabapay wallet to your own Orange Money or Afrimoney
// (Sierra Leone, paid out through Monime).
//   GET  /api/payouts/banks?country=SL&type=mobile_money  → Orange Money, Afrimoney
//   POST /api/payouts/fee    { country, amount, accountType } → fee and total
//   POST /api/payouts/quote  → quoteToken
//   POST /api/payouts/send   { quoteToken, pin }
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';
import 'sl_instant_topup.dart' show mobileMoneyLogo;

/// "+23276123456" / "23276123456" → "076123456".
String slLocalNumber(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('232') && d.length == 11) return '0${d.substring(3)}';
  if (d.length == 8) return '0$d';
  return d;
}

class SlWithdrawScreen extends StatefulWidget {
  const SlWithdrawScreen({super.key});

  @override
  State<SlWithdrawScreen> createState() => _SlWithdrawScreenState();
}

class _SlWithdrawScreenState extends State<SlWithdrawScreen> {
  final _number = TextEditingController(text: slLocalNumber(Session.instance.user?.phone));
  final _amount = TextEditingController();
  String? _provider; // m17 / m18
  bool _busy = false;
  Map<String, dynamic>? _fee;
  String? _feeError;
  Timer? _feeTimer;
  int _feeSeq = 0;

  @override
  void dispose() {
    _number.dispose();
    _amount.dispose();
    _feeTimer?.cancel();
    super.dispose();
  }

  String get _cleanNumber => _number.text.replaceAll(RegExp(r'[\s-]'), '');

  void _amountChanged(String _) {
    _feeTimer?.cancel();
    _feeTimer = Timer(const Duration(milliseconds: 600), _loadFee);
  }

  Future<void> _loadFee() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    final seq = ++_feeSeq;
    if (amount <= 0) {
      setState(() {
        _fee = null;
        _feeError = null;
      });
      return;
    }
    try {
      final r = asMap(await api.post('/api/payouts/fee', {'country': 'SL', 'amount': amount, 'accountType': 'mobile_money'}));
      if (!mounted || seq != _feeSeq) return;
      setState(() {
        _fee = r;
        _feeError = null;
      });
    } catch (e) {
      if (!mounted || seq != _feeSeq) return;
      setState(() {
        _fee = null;
        _feeError = errorMessage(e);
      });
    }
  }

  double _serviceFee(Map<String, dynamic> b) => toDouble(asMap(b['cashwyre'])['feeInYourCurrency']) + toDouble(b['dalabapayFee']);

  Future<void> _withdraw(List<Map<String, dynamic>> providers) async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amount.text) ?? 0;
    final chosen = providers.where((p) => str(p['code']) == _provider).toList();
    String? err;
    if (chosen.isEmpty) {
      err = 'Choose Orange Money or Afrimoney';
    } else if (!RegExp(r'^0\d{8}$').hasMatch(_cleanNumber)) {
      err = 'Enter your mobile money number, e.g. 076123456';
    } else if (amount <= 0) {
      err = 'Enter the amount to withdraw';
    }
    if (err != null) {
      dpSnack(context, err, error: true);
      return;
    }
    final p = chosen.first;
    final name = Session.instance.user?.fullName.trim() ?? '';
    setState(() => _busy = true);
    Map<String, dynamic> q;
    try {
      q = asMap(await api.post('/api/payouts/quote', {
        'country': 'SL',
        'accountType': 'mobile_money',
        'bankCode': p['code'],
        'accountNumber': _cleanNumber,
        'accountName': name.length >= 2 ? name : 'Dalabapay customer',
        'amount': amount,
        'narration': 'Dalabapay withdrawal',
      }));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        dpSnack(context, errorMessage(e), error: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final charge = toDouble(q['charge']);
    final b = asMap(q['breakdown']);
    final txn = await showReviewAndPay(
      context,
      icon: DPIcons.smartphone,
      title: 'Withdraw to ${str(p['name'])}',
      serviceLabel: 'Withdrawal · ${str(p['name'])}',
      amount: charge,
      service: 'sl_payout',
      rows: [
        DPReviewRow(str(p['name']), _cleanNumber),
        DPReviewRow('You receive', DP.naira(amount)),
        if (b.isNotEmpty) DPReviewRow('Fee', DP.naira(_serviceFee(b))),
        DPReviewRow('Total from wallet', DP.naira(charge), strong: true),
      ],
      footnote: 'Check the number. Money sent to the wrong number may not be recoverable.',
      successTitle: 'Withdrawal sent',
      successSubtitle: 'The money is on its way to your ${str(p['name'])}. We\'ll notify you when it arrives.',
      onPay: (pin) async {
        final r = await api.post('/api/payouts/send', {'quoteToken': q['quoteToken'], 'pin': pin});
        return asMap(asMap(r)['transaction']);
      },
    );
    if (txn != null && mounted && str(txn['status']) != 'failed') Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Withdraw',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: AsyncView<List<Map<String, dynamic>>>(
                load: () async => asList(await api.get('/api/payouts/banks', query: {'country': 'SL', 'type': 'mobile_money'})),
                builder: (context, providers, _) => _body(providers),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> providers) {
    if (providers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: DPEmptyState(
          icon: DPIcons.wallet,
          title: 'Withdrawals open soon',
          message: 'Withdrawals to Orange Money and Afrimoney are being switched on. Please check back shortly.',
        ),
      );
    }
    final fee = _fee;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        DPCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const DPIconBadge(DPIcons.wallet, size: 42, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet balance', style: DP.caption),
                    Text(DP.naira(Session.instance.user?.balance ?? 0), style: DP.bodyStrong.copyWith(fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const DPLabel('Withdraw to'),
        Row(
          children: [
            for (final p in providers) ...[
              if (p != providers.first) const SizedBox(width: 12),
              Expanded(child: _providerCard(p)),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const DPLabel('Your mobile money number'),
        DPField(
          controller: _number,
          hint: DPCountry.sierraLeone.phoneHint,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(12)],
        ),
        const SizedBox(height: 16),
        const DPLabel('Amount'),
        DPField(
          controller: _amount,
          hint: '0.00',
          prefixText: '${DP.currencySymbol} ',
          onChanged: _amountChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        ),
        if (_feeError != null) DPHelper(_feeError!),
        if (fee != null) ...[
          const SizedBox(height: 12),
          DPCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _line('Fee', DP.naira(_serviceFee(fee))),
                const SizedBox(height: 6),
                _line('Total from wallet', DP.naira(toDouble(fee['total'])), strong: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        DPButton(
          label: 'Withdraw',
          icon: DPIcons.downLeft,
          loading: _busy,
          onPressed: () => _withdraw(providers),
        ),
        const SizedBox(height: 12),
        const DPBanner(
          'Money arrives in your mobile money account, usually within a minute.',
          tone: DPTone.info,
          icon: DPIcons.info,
        ),
      ],
    );
  }

  Widget _line(String a, String b, {bool strong = false}) => Row(
        children: [
          Expanded(child: Text(a, style: strong ? DP.bodyStrong : DP.caption)),
          Text(b, style: strong ? DP.bodyStrong : DP.body),
        ],
      );

  Widget _providerCard(Map<String, dynamic> p) {
    final code = str(p['code']);
    final on = _provider == code;
    return GestureDetector(
      key: ValueKey('withdraw-$code'),
      onTap: () => setState(() => _provider = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: DP.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? DP.green : DP.border, width: on ? 2 : 1),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: Center(child: mobileMoneyLogo('$code ${p['name']}', height: 30) ?? const Icon(DPIcons.smartphone)),
            ),
            const SizedBox(height: 8),
            Text(str(p['name']), style: DP.bodyStrong.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
