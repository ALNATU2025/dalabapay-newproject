// lib/presentation/screens/wallet/wallet_screen.dart
// "Add Money". Three tabs: Bank Transfer (your personal account from
// GET /api/wallet, issued after KYC), One-time (POST /api/wallet/fund/one-time
// returns an account for an exact amount) and Assisted
// (POST /api/wallet/fund/assisted, approved by the team).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'bank_topup_screen.dart';

/// Test mode only: pretends a bank transfer arrived (POST /api/dev/simulate-transfer).
Future<void> simulateTransfer(BuildContext context, double amount,
    {String? reference}) async {
  try {
    await api.post('/api/dev/simulate-transfer', {
      'amount': amount,
      if (reference != null) 'reference': reference,
    });
    await Session.instance.refreshQuietly();
    if (context.mounted) {
      dpSnack(context, 'Test transfer received', success: true);
    }
  } catch (e) {
    if (context.mounted) dpSnack(context, errorMessage(e), error: true);
  }
}

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  static const _methods = ['Bank Transfer', 'One-time', 'Assisted'];
  int _method = 0;
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic> _wallet = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = asMap(await api.get('/api/wallet'));
      if (mounted) setState(() => _wallet = w);
      if (w['manualBank'] is Map) {
        final o = asMap(await api.get('/api/wallet/fund/bank/open'));
        if (mounted) setState(() => _openTopUp = o['topUp'] is Map ? asMap(o['topUp']) : null);
      }
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  /// Nigeria: pay the company account, an admin confirms.
  bool get _manual => _wallet['manualBank'] is Map;
  Map<String, dynamic>? _openTopUp;

  Future<void> _openBankTopUp(Map<String, dynamic> t) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BankTopUpScreen(topUp: t)));
    await Session.instance.refreshQuietly();
    _load();
  }

  Future<void> _sendManual() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < _minFunding || amount > _maxFunding) {
      dpSnack(context, 'Enter an amount between ${DP.naira(_minFunding)} and ${DP.naira(_maxFunding)}', error: true);
      return;
    }
    if (_pinController.text.length < 6) {
      dpSnack(context, 'Enter your 6-digit payment PIN', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final pin = _pinController.text;
    _pinController.clear();
    try {
      final r = asMap(await api.post('/api/wallet/fund/bank', {'amount': amount, 'pin': pin}));
      if (!mounted) return;
      setState(() => _isLoading = false);
      _amountController.clear();
      await _openBankTopUp(asMap(r['topUp']));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  List<Widget> _manualForm() {
    final a = asMap(_wallet['manualBank']);
    final open = _openTopUp;
    return [
      if (open != null) ...[
        DPBanner(
          '${DP.naira(toDouble(open['amount']))} top-up ${str(open['stage']) == 'sent' ? 'is waiting for confirmation' : 'is not finished yet'}.',
          title: 'Top-up in progress',
          tone: DPTone.info,
          icon: DPIcons.pending,
          action: TextButton(onPressed: () => _openBankTopUp(open), child: const Text('Open')),
        ),
        const SizedBox(height: 16),
      ],
      Text(
        'Enter the amount you want to add and your PIN. We\'ll show you our ${str(a['bankName'])} account to send it to.',
        style: DP.body.copyWith(color: DP.muted, fontSize: 14),
      ),
      const SizedBox(height: 18),
      _buildAmountInput(),
      const SizedBox(height: 18),
      _buildAuth(),
      const SizedBox(height: 22),
      DPButton(
        label: 'Send',
        icon: DPIcons.forward,
        loading: _isLoading,
        onPressed: _isLoading ? null : _sendManual,
      ),
      const SizedBox(height: 14),
      Center(
        child: Text(
          'No funding fee. Your wallet is credited as soon as\nwe confirm your transfer.',
          textAlign: TextAlign.center,
          style: DP.caption.copyWith(height: 1.5),
        ),
      ),
    ];
  }

  double get _feePercent => toDouble(_wallet['fundingFeePercent'] ?? 1.5);
  double get _minFunding => toDouble(_wallet['minFunding'] ?? 100);
  double get _maxFunding => toDouble(_wallet['maxFunding'] ?? 1000000);
  Map<String, dynamic>? get _account =>
      _wallet['dedicatedAccount'] is Map ? asMap(_wallet['dedicatedAccount']) : null;

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < _minFunding || amount > _maxFunding) {
      dpSnack(context,
          'Enter an amount between ${DP.naira(_minFunding)} and ${DP.naira(_maxFunding)}',
          error: true);
      return;
    }
    if (_pinController.text.length < 6) {
      dpSnack(context, 'Enter your 6-digit payment PIN', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final pin = _pinController.text;
    _pinController.clear();
    try {
      if (_method == 1) {
        final r = asMap(await api.post('/api/wallet/fund/one-time', {'amount': amount, 'pin': pin}));
        if (!mounted) return;
        setState(() => _isLoading = false);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _OneTimeAccountDialog(
            account: asMap(r['account']),
            feePercent: _feePercent,
          ),
        );
        await Session.instance.refreshQuietly();
      } else {
        await api.post('/api/wallet/fund/assisted', {'amount': amount, 'pin': pin});
        if (!mounted) return;
        setState(() => _isLoading = false);
        _amountController.clear();
        dpDialog(
          context,
          title: 'Request sent',
          message:
              'Our team will reach out to help you fund ${DP.naira(amount)}. We\'ll credit your wallet once your payment is confirmed.',
          confirmLabel: 'OK',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showForm = _method != 0;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Add Money',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_manual) ..._manualForm()
                    // Kuda: the customer's own account number is all they need.
                    else if (_wallet['accountNumberOnly'] == true) ...[
                      _buildDedicatedAccount(),
                      const SizedBox(height: 14),
                      _buildBalanceCard(),
                      const SizedBox(height: 14),
                      const DPBanner(
                        'Send any amount from any Nigerian bank app to your account number above. Your wallet is credited automatically within minutes.',
                      ),
                    ] else ...[
                    DPSegmented(
                      options: _methods,
                      index: _method,
                      onChanged: (i) => setState(() => _method = i),
                    ),
                    const SizedBox(height: 20),
                    if (!showForm) ...[
                      _buildDedicatedAccount(),
                      const SizedBox(height: 14),
                      _buildBalanceCard(),
                      const SizedBox(height: 14),
                      const DPBanner(
                        'Send money from any Nigerian bank app to the account above. Your bank may charge a transfer fee.',
                      ),
                    ] else ...[
                      Text(
                        _method == 1
                            ? 'Get a one-time account for an exact amount. Pay it within the time shown and your wallet is credited automatically.'
                            : 'Our team will help you fund your wallet manually. Enter the amount you want to add.',
                        style: DP.body.copyWith(color: DP.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 18),
                      _buildAmountInput(),
                      const SizedBox(height: 18),
                      _buildAuth(),
                      const SizedBox(height: 18),
                      _buildBalanceCard(),
                      const SizedBox(height: 22),
                      DPButton(
                        label: _method == 2
                            ? 'Request assisted funding'
                            : 'Proceed',
                        loading: _isLoading,
                        onPressed: _isLoading ? null : _proceed,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          _method == 1
                              ? 'Your account will be credited instantly\nafter successful payment.'
                              : 'We\'ll credit your wallet once your payment is confirmed.',
                          textAlign: TextAlign.center,
                          style: DP.caption.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                    ],
                    const SizedBox(height: 18),
                    DPCard(
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                      child: DPListRow(
                        leading: const DPIconBadge.blue(
                          DPIcons.help,
                          size: 40,
                          iconSize: 20,
                        ),
                        title: 'Transfer hasn\'t arrived?',
                        subtitle: 'Find a transfer with its bank reference',
                        trailing:
                            Icon(DPIcons.chevronRight, color: DP.muted),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/transaction-validation',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDedicatedAccount() {
    final account = _account;
    if (account == null) {
      return DPCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DPIconBadge(DPIcons.bank, size: 48, iconSize: 22),
            const SizedBox(height: 12),
            Text('Get your personal account number', style: DP.bodyStrong),
            const SizedBox(height: 6),
            Text(
              _wallet.isEmpty
                  ? 'Loading…'
                  : 'Verify your identity (BVN or NIN) and we\'ll give you a bank account number. Money you send to it lands in your wallet automatically.',
              style: DP.caption,
            ),
            const SizedBox(height: 14),
            DPButton(
              label: 'Verify identity',
              icon: DPIcons.forward,
              onPressed: () async {
                await Navigator.pushNamed(context, '/kyc');
                _load();
              },
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              DPOutlineButton(
                label: 'Test mode: receive ₦10,000',
                onPressed: () async {
                  await simulateTransfer(context, 10000);
                  _load();
                },
              ),
            ],
          ],
        ),
      );
    }
    final number = str(account['accountNumber']);
    return Column(
      children: [
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
                  Icon(
                    DPIcons.bank,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transfer to your Dalabapay account',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    DPIcons.refresh,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                str(account['accountName']),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                str(account['bankName']),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DPButton(
          label: 'Copy account number',
          icon: DPIcons.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: number));
            HapticFeedback.lightImpact();
            dpSnack(context, 'Account number copied', success: true);
          },
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          DPOutlineButton(
            label: 'Test mode: receive ₦10,000',
            onPressed: () async {
              await simulateTransfer(context, 10000);
              _load();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAmountInput() {
    const quick = [1000, 2000, 5000, 10000];
    final labels = quick.map((a) => DP.naira(a, decimals: false)).toList();
    final current = int.tryParse(_amountController.text.trim());
    final sel = current == null || !quick.contains(current)
        ? null
        : DP.naira(current, decimals: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DPLabel('Amount'),
        DPField(
          controller: _amountController,
          hint: '0.00',
          prefixText: '₦  ',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            fontSize: 16,
            color: DP.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        DPHelper('Minimum ${DP.naira(_minFunding, decimals: false)} · Maximum ${DP.naira(_maxFunding, decimals: false)}'),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: DPChip(
                  label: labels[i],
                  selected: sel == labels[i],
                  height: 40,
                  onTap: () => setState(
                    () => _amountController.text = quick[i].toString(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter your payment PIN', style: DP.section),
        const SizedBox(height: 12),
        DPCodeInput(controller: _pinController, length: 6),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return DPCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Column(
        children: [
          if (_method == 0)
            const DPSummaryRow('Transfer processing', 'Usually within minutes'),
          if (_method != 2)
            DPSummaryRow('Dalabapay funding fee',
                '${_feePercent.toStringAsFixed(_feePercent % 1 == 0 ? 0 : 1)}% per transfer'),
          DPSummaryRow('Wallet balance',
              DP.naira(Session.instance.user?.balance ?? toDouble(_wallet['balance']))),
        ],
      ),
    );
  }
}

/// One-time account from the server, with a countdown to its expiry.
class _OneTimeAccountDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  final double feePercent;
  const _OneTimeAccountDialog({required this.account, required this.feePercent});

  @override
  State<_OneTimeAccountDialog> createState() => _OneTimeAccountDialogState();
}

class _OneTimeAccountDialogState extends State<_OneTimeAccountDialog> {
  late int _seconds = parseDate(widget.account['expiresAt'])
      .difference(DateTime.now())
      .inSeconds
      .clamp(0, 24 * 3600)
      .toInt();
  Timer? _timer;
  bool _checking = false;

  Future<void> _checkPayment() async {
    setState(() => _checking = true);
    try {
      final r = asMap(await api.post('/api/wallet/verify-payment',
          {'reference': str(widget.account['reference'])}));
      if (!mounted) return;
      setState(() => _checking = false);
      if (r['status'] == 'success') {
        await Session.instance.refreshQuietly();
        if (!mounted) return;
        dpSnack(context, 'Payment received. Your wallet has been credited.',
            success: true);
        Navigator.pop(context);
      } else {
        dpSnack(context,
            'We haven\'t received it yet. Your wallet updates as soon as the transfer lands.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_seconds <= 0) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _row(IconData icon, String label, String value,
      {bool highlight = false, bool copy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          DPIconBadge.blue(icon, size: 36, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DP.caption.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: highlight ? 20 : 15,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                    color: DP.ink,
                    letterSpacing: highlight ? 1 : 0,
                  ),
                ),
              ],
            ),
          ),
          if (copy)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(DPIcons.copy, size: 18, color: DP.green),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                dpSnack(context, '$label copied', success: true);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final fee = toDouble(a['fee']);
    final pct = widget.feePercent;
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    final soon = _seconds < 300;
    return Dialog(
      backgroundColor: DP.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DP.rXl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('One-time account', style: DP.title),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DP.blueTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}% Fee',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: DP.navyIcon,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(DPIcons.close, color: DP.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DPBanner(
                  'Pay within $mm:$ss. The account expires after that.',
                  tone: soon ? DPTone.warning : DPTone.info,
                  icon: DPIcons.pending,
                ),
              ),
              const SizedBox(height: 10),
              _row(DPIcons.bank, 'Bank', str(a['bankName']), copy: true),
              _row(DPIcons.wallet, 'Account Number', str(a['accountNumber']),
                  highlight: true, copy: true),
              _row(DPIcons.user, 'Account Name', str(a['accountName']),
                  copy: true),
              Divider(height: 24, color: DP.border),
              _row(Icons.payments_outlined, 'Amount to transfer',
                  DP.naira(toDouble(a['amountToPay'])),
                  highlight: true),
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: Text(
                  'Includes ${DP.naira(fee)} funding fee. You\'ll receive ${DP.naira(toDouble(a['youReceive']))}.',
                  style: DP.caption,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DPButton(
                  label: 'I\'ve sent the money',
                  loading: _checking,
                  onPressed: _checking ? null : _checkPayment,
                ),
              ),
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: DPOutlineButton(
                    label: 'Test mode: simulate this transfer',
                    onPressed: () async {
                      await simulateTransfer(context,
                          toDouble(a['amountToPay']),
                          reference: str(a['reference']));
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
