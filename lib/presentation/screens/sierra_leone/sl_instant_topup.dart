// lib/presentation/screens/sierra_leone/sl_instant_topup.dart
// Instant Add Money in Sierra Leone with Monime: pick Orange Money or
// Afrimoney, enter the amount and the number you pay from, get a USSD code,
// dial it and approve with your mobile money PIN. The wallet is credited
// automatically (the page checks every few seconds).
//   GET  /api/wallet/fund/monime          → providers, min/max, fee %
//   POST /api/wallet/fund/monime          { amount, providerId, phone } → ussdCode
//   GET  /api/wallet/fund/monime/:id      → status
//   POST /api/wallet/fund/monime/:id/cancel
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';

const _orange = Color(0xFFFF7900);
const _afri = Color(0xFF9B1C7E);

/// The Orange Money / Afrimoney logo for a provider name or id, on a white
/// rounded tile (readable in dark mode too); null for anything else.
Widget? mobileMoneyLogo(String nameOrId, {double height = 30}) {
  final k = nameOrId.toLowerCase();
  final String? asset = k.contains('orange') || k == 'm17'
      ? 'assets/images/orange_money.png'
      : (k.contains('afri') || k.contains('africell') || k == 'm18')
          ? 'assets/images/afrimoney.png'
          : null;
  if (asset == null) return null;
  return Container(
    height: height,
    width: height * 3.4, // both logos are about 3.2–3.5 times wider than tall
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
    child: Image.asset(asset, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
  );
}

class SlInstantTopup extends StatefulWidget {
  final Map<String, dynamic> info; // GET /api/wallet/fund/monime
  final VoidCallback? onDone;
  const SlInstantTopup({super.key, required this.info, this.onDone});

  @override
  State<SlInstantTopup> createState() => _SlInstantTopupState();
}

class _SlInstantTopupState extends State<SlInstantTopup> {
  final _amount = TextEditingController();
  final _phone = TextEditingController(text: _localPhone(Session.instance.user?.phone));
  String? _provider;
  bool _busy = false;

  // The code in progress.
  Map<String, dynamic>? _txn;
  String _ussd = '';
  String _status = ''; // pending | success | failed
  Timer? _poll;
  int _checks = 0;

  static String _localPhone(String? p) {
    final d = (p ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('232') && d.length == 11) return '0${d.substring(3)}';
    return d.length == 9 && d.startsWith('0') ? d : '';
  }

  @override
  void initState() {
    super.initState();
    final list = asList(widget.info['providers']);
    if (list.isNotEmpty) _provider = str(list.first['id']);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amount.text) ?? 0;
    final min = toDouble(widget.info['minAmount']);
    final max = toDouble(widget.info['maxAmount']);
    if (_provider == null) return dpSnack(context, 'Choose Orange Money or Afrimoney', error: true);
    if (amount < min || amount > max) {
      return dpSnack(context, 'Enter an amount between ${DP.naira(min)} and ${DP.naira(max)}', error: true);
    }
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 8) {
      return dpSnack(context, 'Enter the number you will pay from', error: true);
    }
    setState(() => _busy = true);
    try {
      final r = asMap(await api.post('/api/wallet/fund/monime', {'amount': amount, 'providerId': _provider, 'phone': _phone.text.trim()}));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _txn = asMap(r['transaction']);
        _ussd = str(r['ussdCode']);
        _status = 'pending';
        _checks = 0;
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _check() async {
    final id = str(_txn?['id']);
    if (id.isEmpty) return;
    _checks++;
    try {
      final r = asMap(await api.get('/api/wallet/fund/monime/$id'));
      final t = asMap(r['transaction']);
      final st = str(t['status']);
      if (!mounted) return;
      if (st != 'pending') {
        _poll?.cancel();
        setState(() {
          _status = st;
          _txn = t;
        });
        if (st == 'success') {
          HapticFeedback.heavyImpact();
          Session.instance.refreshQuietly();
        }
      } else if (_checks > 240) {
        _poll?.cancel(); // ~16 minutes: the code has expired by now
      }
    } catch (_) {
      // try again next tick
    }
  }

  Future<void> _dial() async {
    if (_ussd.isEmpty) return;
    try {
      final ok = await launchUrl(Uri.parse('tel:${Uri.encodeComponent(_ussd)}'));
      if (!ok && mounted) dpSnack(context, 'Dial $_ussd on your phone');
    } catch (_) {
      if (mounted) dpSnack(context, 'Dial $_ussd on your phone');
    }
  }

  Future<void> _cancel() async {
    final id = str(_txn?['id']);
    _poll?.cancel();
    try {
      final r = asMap(await api.post('/api/wallet/fund/monime/$id/cancel'));
      final st = str(asMap(r['transaction'])['status']);
      if (!mounted) return;
      if (st == 'success') {
        setState(() => _status = 'success');
        return;
      }
    } catch (_) {}
    if (mounted) setState(_reset);
  }

  void _reset() {
    _txn = null;
    _ussd = '';
    _status = '';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _txn == null ? _form() : _codeView(),
    );
  }

  Widget _form() {
    final providers = asList(widget.info['providers']);
    final fee = toDouble(widget.info['feePercent']);
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DPLabel('Pay with'),
        Row(children: [
          for (var i = 0; i < providers.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _providerCard(providers[i])),
          ],
        ]),
        const SizedBox(height: 16),
        const DPLabel('Amount'),
        DPField(
          controller: _amount,
          hint: '0.00',
          prefixText: '${DP.currencySymbol} ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        ),
        DPHelper(
          'Minimum ${DP.naira(toDouble(widget.info['minAmount']))} · Maximum ${DP.naira(toDouble(widget.info['maxAmount']))}'
          '${fee > 0 ? ' · ${fee.toStringAsFixed(fee == fee.roundToDouble() ? 0 : 1)}% fee' : ' · No fee'}',
        ),
        const SizedBox(height: 16),
        const DPLabel('Number you will pay from'),
        DPField(
          controller: _phone,
          hint: DPCountry.sierraLeone.phoneHint,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]'))],
        ),
        const SizedBox(height: 24),
        DPButton(label: 'Get payment code', icon: Icons.arrow_forward_rounded, loading: _busy, onPressed: _start),
        const SizedBox(height: 12),
        const DPBanner(
          'You\'ll dial a short code and approve with your mobile money PIN. Your wallet is credited automatically in seconds.',
          tone: DPTone.info,
          icon: DPIcons.info,
        ),
      ],
    );
  }

  Widget _providerCard(Map<String, dynamic> p) {
    final id = str(p['id']);
    final name = str(p['name']);
    final on = _provider == id;
    final color = name.toLowerCase().contains('orange') ? _orange : _afri;
    return Material(
      color: on ? color.withValues(alpha: 0.10) : DP.surface,
      borderRadius: BorderRadius.circular(DP.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(DP.rMd),
        onTap: () => setState(() => _provider = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 64,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DP.rMd),
            border: Border.all(color: on ? color : DP.border, width: on ? 2 : 1),
          ),
          child: Stack(children: [
            Center(
              child: mobileMoneyLogo(name.isEmpty ? id : name, height: 36) ??
                  Text(name, style: DP.bodyStrong.copyWith(fontSize: 14, color: on ? color : DP.ink)),
            ),
            if (on)
              Positioned(right: -4, top: -6, child: Icon(Icons.check_circle_rounded, color: color, size: 18)),
          ]),
        ),
      ),
    );
  }

  Widget _codeView() {
    final amount = toDouble(_txn?['amount']);
    if (_status == 'success') {
      return Column(key: const ValueKey('ok'), children: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: DP.green.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: DP.green, size: 56),
        ),
        const SizedBox(height: 14),
        Text('Wallet funded', style: DP.title),
        const SizedBox(height: 6),
        Text('${DP.naira(amount)} has been added to your wallet.', style: DP.body, textAlign: TextAlign.center),
        const SizedBox(height: 22),
        DPButton(label: 'Done', onPressed: () => widget.onDone?.call()),
      ]);
    }
    if (_status == 'failed') {
      return Column(key: const ValueKey('fail'), children: [
        const SizedBox(height: 12),
        const Icon(Icons.timer_off_rounded, color: DP.red, size: 56),
        const SizedBox(height: 12),
        Text('Not completed', style: DP.title),
        const SizedBox(height: 6),
        Text(
          str(asMap(_txn?['metadata'])['failureReason'], 'The code expired before payment.') + ' No money was taken.',
          style: DP.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        DPButton(label: 'Try again', onPressed: () => setState(_reset)),
      ]);
    }
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: DP.navyGradient, borderRadius: BorderRadius.circular(DP.rXl)),
          child: Column(children: [
            Text('Dial this code to pay ${DP.naira(amount)}', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
            const SizedBox(height: 10),
            FittedBox(
              child: SelectableText(
                _ussd.isEmpty ? '—' : _ussd,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: DP.green, padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: _dial,
                  icon: const Icon(Icons.dialpad_rounded, size: 18),
                  label: const Text('Dial now'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _ussd));
                  dpSnack(context, 'Code copied', success: true);
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        _stepLine(1, 'Dial the code on the phone with ${_phone.text.trim()}.'),
        _stepLine(2, 'Confirm the amount and enter your mobile money PIN.'),
        _stepLine(3, 'Stay on this page: your wallet is credited automatically.'),
        const SizedBox(height: 14),
        Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: DP.green)),
          const SizedBox(width: 10),
          Expanded(child: Text('Waiting for your payment…', style: DP.caption)),
          TextButton(onPressed: _check, child: const Text('Check now')),
        ]),
        const SizedBox(height: 4),
        Center(child: DPTextLink(label: 'Cancel this top-up', onTap: _cancel)),
      ],
    );
  }

  Widget _stepLine(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: DP.green.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: DP.green, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: DP.body.copyWith(fontSize: 14))),
        ]),
      );
}
