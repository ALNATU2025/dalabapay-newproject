// lib/presentation/screens/sierra_leone/sl_add_money_screen.dart
// Add money in Sierra Leone: pay one of our Orange Money / Afrimoney /
// bank accounts, then tap "I've paid" with the transaction ID. An admin
// confirms it and the wallet is credited (no fee).
//   GET  /api/wallet/sl-funding
//   POST /api/wallet/fund/sl-request { amount, method, reference, senderNumber?, note? }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';

class SlAddMoneyScreen extends StatefulWidget {
  const SlAddMoneyScreen({super.key});

  @override
  State<SlAddMoneyScreen> createState() => _SlAddMoneyScreenState();
}

class _SlAddMoneyScreenState extends State<SlAddMoneyScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _sender = TextEditingController();
  String? _method;
  bool _sending = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _submit(Map<String, dynamic> info) async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amount.text) ?? 0;
    final min = toDouble(info['minAmount']);
    final max = toDouble(info['maxAmount']);
    if (_method == null) {
      dpSnack(context, 'Choose how you paid', error: true);
      return;
    }
    if (amount < min || amount > max) {
      dpSnack(context, 'Enter an amount between ${DP.naira(min)} and ${DP.naira(max)}', error: true);
      return;
    }
    if (_reference.text.trim().length < 3) {
      dpSnack(context, 'Enter the transaction ID from your payment message', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await api.post('/api/wallet/fund/sl-request', {
        'amount': amount,
        'method': _method,
        'reference': _reference.text.trim(),
        if (_sender.text.trim().isNotEmpty) 'senderNumber': _sender.text.trim(),
      });
      if (!mounted) return;
      setState(() => _sending = false);
      await dpDialog(
        context,
        title: 'We\'ve got it',
        message:
            'We\'ll check your ${DP.naira(amount)} payment and credit your wallet as soon as it\'s confirmed. You\'ll get a notification.',
        confirmLabel: 'Done',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
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
              title: 'Add money',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: AsyncView<Map<String, dynamic>>(
                load: () async => asMap(await api.get('/api/wallet/sl-funding')),
                builder: (context, info, _) => _body(info),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> info) {
    final methods = asList(info['methods']);
    final chosen = methods.where((m) => m['id'] == _method).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        DPHeadline(
          'Top up in Leones.',
          subtitle: 'Balance: ${DP.naira(Session.instance.user?.balance ?? 0)}',
        ),
        if (methods.isEmpty)
          const DPEmptyState(
            icon: DPIcons.wallet,
            title: 'Top-ups open soon',
            message: 'We\'re setting up payment accounts for Sierra Leone. Please check back shortly.',
          )
        else ...[
          _step(1, 'Send money to one of these accounts'),
          for (final m in methods) _methodCard(m),
          const SizedBox(height: 6),
          DPHelper(str(info['instructions'])),
          const SizedBox(height: 22),
          _step(2, 'Tell us you\'ve paid'),
          const DPLabel('How did you pay?'),
          DPChipRow(
            options: [for (final m in methods) str(m['name'])],
            selected: chosen.isEmpty ? null : str(chosen.first['name']),
            height: 46,
            onSelect: (name) => setState(() => _method = str(methods.firstWhere((m) => m['name'] == name)['id'])),
          ),
          const SizedBox(height: 16),
          const DPLabel('Amount you sent'),
          DPField(
            controller: _amount,
            hint: '0.00',
            prefixText: '${DP.currencySymbol} ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          ),
          DPHelper('Minimum ${DP.naira(toDouble(info['minAmount']))} · Maximum ${DP.naira(toDouble(info['maxAmount']))}'),
          const SizedBox(height: 16),
          const DPLabel('Transaction ID'),
          DPField(
            controller: _reference,
            hint: 'From your payment SMS',
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          const DPLabel('Number you paid from (optional)'),
          DPField(
            controller: _sender,
            hint: DPCountry.sierraLeone.phoneHint,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]'))],
          ),
          const SizedBox(height: 24),
          DPButton(
            label: 'I\'ve paid',
            icon: DPIcons.check,
            loading: _sending,
            onPressed: () => _submit(info),
          ),
          const SizedBox(height: 12),
          const DPBanner(
            'Your wallet is credited once we confirm the payment — usually within minutes during working hours.',
            tone: DPTone.info,
            icon: DPIcons.info,
          ),
        ],
      ],
    );
  }

  Widget _step(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: DP.green, shape: BoxShape.circle),
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: DP.section)),
          ],
        ),
      );

  Widget _methodCard(Map<String, dynamic> m) {
    final account = str(m['account']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DPCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            DPIconBadge(m['id'] == 'bank' ? DPIcons.bank : DPIcons.smartphone, size: 42, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(m['name']), style: DP.caption),
                  Text(account, style: DP.bodyStrong.copyWith(fontSize: 17, letterSpacing: 0.5)),
                  if (str(m['accountName']).isNotEmpty || str(m['bankName']).isNotEmpty)
                    Text(
                      [str(m['accountName']), str(m['bankName'])].where((x) => x.isNotEmpty).join(' · '),
                      style: DP.caption,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(DPIcons.copy, color: DP.green),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: account));
                dpSnack(context, '${str(m['name'])} number copied', success: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
