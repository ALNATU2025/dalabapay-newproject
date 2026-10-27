// lib/presentation/screens/wallet/bank_topup_screen.dart
// Nigeria "Add money" by transfer to the company account (Kuda):
// the account to pay, "I have sent it" / "Cancel", then waits on this page
// until an admin confirms (GET /api/wallet/fund/bank/:id every few seconds).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';

class BankTopUpScreen extends StatefulWidget {
  /// The top-up from POST /api/wallet/fund/bank (or /fund/bank/open).
  final Map<String, dynamic> topUp;
  const BankTopUpScreen({super.key, required this.topUp});

  @override
  State<BankTopUpScreen> createState() => _BankTopUpScreenState();
}

class _BankTopUpScreenState extends State<BankTopUpScreen> {
  late Map<String, dynamic> _t = widget.topUp;
  bool _busy = false;
  Timer? _poll;

  String get _id => str(_t['id']);
  String get _stage => str(_t['stage'], 'awaiting');
  double get _amount => toDouble(_t['amount']);
  Map<String, dynamic> get _account => asMap(_t['account']);
  bool get _open => _stage == 'awaiting' || _stage == 'sent';

  @override
  void initState() {
    super.initState();
    if (_stage == 'sent') _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final r = asMap(await api.get('/api/wallet/fund/bank/$_id'));
      final t = asMap(r['topUp']);
      if (!mounted || t.isEmpty) return;
      final was = _stage;
      setState(() => _t = t);
      if (!_open) {
        _poll?.cancel();
        if (_stage == 'confirmed' && was != 'confirmed') {
          HapticFeedback.mediumImpact();
          await Session.instance.refreshQuietly();
        }
      }
    } catch (_) {}
  }

  Future<void> _sent() async {
    final ok = await dpDialog(
      context,
      title: 'Have you sent ${DP.naira(_amount)}?',
      message: 'Only tap "Yes" after the transfer to ${str(_account['bankName'])} ${str(_account['accountNumber'])} is done in your bank app.',
      confirmLabel: 'Yes, I have sent it',
      cancelLabel: 'Not yet',
      tone: DPTone.info,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = asMap(await api.post('/api/wallet/fund/bank/$_id/sent'));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _t = asMap(r['topUp']);
      });
      if (_stage == 'sent') _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _cancel() async {
    final ok = await dpDialog(
      context,
      title: 'Cancel this top-up?',
      message: _stage == 'sent'
          ? 'If you already sent the money, don\'t cancel — wait for it to be confirmed.'
          : 'Nothing has been charged. You can start again any time.',
      confirmLabel: 'Cancel top-up',
      cancelLabel: 'Keep it',
      tone: DPTone.warning,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = asMap(await api.post('/api/wallet/fund/bank/$_id/cancel'));
      if (!mounted) return;
      _poll?.cancel();
      setState(() {
        _busy = false;
        _t = asMap(r['topUp']);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_open) return true;
    final ok = await dpDialog(
      context,
      title: 'Leave this page?',
      message: 'Your top-up stays open. Come back to Add Money to see it until it\'s confirmed.',
      confirmLabel: 'Leave',
      cancelLabel: 'Stay',
      tone: DPTone.warning,
    );
    return ok == true;
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    dpSnack(context, '$label copied', success: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: DP.bg,
        body: SafeArea(
          child: Column(
            children: [
              DPTopBar(title: 'Add Money', showLogo: true, onBack: () => Navigator.maybePop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  child: _stage == 'confirmed'
                      ? _done()
                      : _stage == 'cancelled'
                          ? _cancelled()
                          : _pay(),
                ),
              ),
              if (_open) _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pay() {
    final a = _account;
    final number = str(a['accountNumber']);
    final sent = _stage == 'sent';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepStrip(step: sent ? 2 : 1),
        const SizedBox(height: 16),
        Text(sent ? 'Waiting for confirmation' : 'Send exactly ${DP.naira(_amount)}', style: DP.title),
        const SizedBox(height: 6),
        Text(
          sent
              ? 'We\'re checking your transfer. Your wallet is credited as soon as it\'s confirmed.'
              : 'Copy the account number, open your bank app and transfer the amount below.',
          style: DP.caption.copyWith(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: DP.greenGradient,
            borderRadius: BorderRadius.circular(DP.rXxl),
            boxShadow: DP.glow(DP.green),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(DPIcons.bank, color: Colors.white.withValues(alpha: 0.85), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      str(a['bankName']),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        number,
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy account number',
                    onPressed: () => _copy('Account number', number),
                    icon: const Icon(DPIcons.copy, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(str(a['accountName']), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DPButton(
          label: 'Copy account number',
          icon: DPIcons.copy,
          onPressed: () => _copy('Account number', number),
        ),
        const SizedBox(height: 14),
        DPCard(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
          child: Column(
            children: [
              DPSummaryRow('Amount to send', DP.naira(_amount)),
              DPSummaryRow('Fee', 'Free'),
              Row(
                children: [
                  Expanded(child: DPSummaryRow('Reference (optional, add as remark)', str(_t['reference']))),
                  IconButton(
                    tooltip: 'Copy reference',
                    icon: const Icon(DPIcons.copy, size: 18, color: DP.green),
                    onPressed: () => _copy('Reference', str(_t['reference'])),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (sent)
          Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
              const SizedBox(width: 12),
              Expanded(child: Text('Checking… this page updates by itself.', style: DP.bodyStrong)),
            ],
          ),
        if (sent) const SizedBox(height: 14),
        const DPBanner(
          'Do not close this page until your transaction is confirmed.',
          tone: DPTone.warning,
          icon: DPIcons.pending,
        ),
        const SizedBox(height: 10),
        Text(
          'Send from a bank account in your own name, and only the exact amount. Your bank may charge its usual transfer fee.',
          style: DP.caption.copyWith(height: 1.45),
        ),
      ],
    );
  }

  Widget _actions() {
    final sent = _stage == 'sent';
    return DPBottomAction(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!sent)
            DPButton(
              label: 'I have sent it',
              icon: DPIcons.checkCircle,
              loading: _busy,
              onPressed: _busy ? null : _sent,
            ),
          if (!sent) const SizedBox(height: 10),
          DPOutlineButton(
            label: 'Cancel',
            color: DP.red,
            onPressed: _busy ? null : _cancel,
          ),
        ],
      ),
    );
  }

  Widget _done() => Column(
        children: [
          const SizedBox(height: 30),
          const DPIconBadge(DPIcons.checkCircle, size: 84, iconSize: 44),
          const SizedBox(height: 18),
          Text('Wallet funded', style: DP.title),
          const SizedBox(height: 8),
          Text(
            '${DP.naira(_amount)} has been added to your wallet.',
            textAlign: TextAlign.center,
            style: DP.body.copyWith(color: DP.muted),
          ),
          const SizedBox(height: 26),
          DPButton(label: 'Done', onPressed: () => Navigator.pop(context, true)),
        ],
      );

  Widget _cancelled() => Column(
        children: [
          const SizedBox(height: 30),
          DPIconBadge(DPIcons.alert, color: DP.red, background: DP.redBg, size: 84, iconSize: 40),
          const SizedBox(height: 18),
          Text('Top-up cancelled', style: DP.title),
          const SizedBox(height: 8),
          Text(
            str(_t['note']).isNotEmpty && str(_t['note']) != 'Cancelled by customer'
                ? str(_t['note'])
                : 'Nothing was added to your wallet. If you already sent the money, contact support with your bank receipt.',
            textAlign: TextAlign.center,
            style: DP.body.copyWith(color: DP.muted),
          ),
          const SizedBox(height: 26),
          DPButton(label: 'Back', onPressed: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          DPOutlineButton(label: 'Contact support', onPressed: () => Navigator.pushNamed(context, '/help')),
        ],
      );
}

class _StepStrip extends StatelessWidget {
  final int step;
  const _StepStrip({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Send money', 'Confirmation', 'Credited'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < step ? DP.green : DP.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: DP.caption.copyWith(fontSize: 11.5, fontWeight: i < step ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
