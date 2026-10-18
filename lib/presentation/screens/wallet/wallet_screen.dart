// lib/presentation/screens/wallet/wallet_screen.dart
// "Add Money" — UI only. Three tabs: Bank Transfer (sample personal
// account), One-time (shows a sample one-time account with a countdown)
// and Assisted (shows a confirmation). No money moves.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';

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
  bool _useBiometric = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < 100 || amount > 1000000) {
      dpSnack(context, 'Enter an amount between ₦100 and ₦1,000,000',
          error: true);
      return;
    }
    if (!_useBiometric && _pinController.text.length < 6) {
      dpSnack(context, 'Enter your 6-digit payment PIN', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (_method == 1) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _OneTimeAccountDialog(amount: amount),
      );
    } else {
      dpDialog(
        context,
        title: 'Request sent',
        message:
            'Our team will reach out to help you fund ${DP.naira(amount)}. We\'ll credit your wallet once your payment is confirmed.',
        confirmLabel: 'OK',
      );
    }
    _pinController.clear();
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
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: DP.greenGradient,
            borderRadius: BorderRadius.circular(DP.rXl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33079A68),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
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
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  MockUser.accountNumber,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dalabapay - ${MockUser.fullName}',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                MockUser.bankName,
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
            Clipboard.setData(
              const ClipboardData(text: MockUser.accountNumber),
            );
            HapticFeedback.lightImpact();
            dpSnack(context, 'Account number copied', success: true);
          },
        ),
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
        const DPHelper('Minimum ₦100 · Maximum ₦1,000,000'),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(DPIcons.fingerprint, color: DP.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Confirm with biometrics', style: DP.body),
              ),
              Switch(
                value: _useBiometric,
                onChanged: (v) => setState(() {
                  _useBiometric = v;
                  if (v) _pinController.clear();
                }),
              ),
            ],
          ),
        ),
        if (!_useBiometric) ...[
          Text('Enter your payment PIN', style: DP.section),
          const SizedBox(height: 12),
          DPCodeInput(controller: _pinController, length: 6),
        ],
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
            const DPSummaryRow('Dalabapay funding fee', '1.5% per transfer'),
          DPSummaryRow('Wallet balance', DP.naira(MockUser.walletBalance)),
        ],
      ),
    );
  }
}

/// Sample one-time account with a 30-minute countdown.
class _OneTimeAccountDialog extends StatefulWidget {
  final double amount;
  const _OneTimeAccountDialog({required this.amount});

  @override
  State<_OneTimeAccountDialog> createState() => _OneTimeAccountDialogState();
}

class _OneTimeAccountDialogState extends State<_OneTimeAccountDialog> {
  int _seconds = 30 * 60;
  Timer? _timer;

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
    final fee = widget.amount * 0.015;
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
                    child: const Text(
                      '1.5% Fee',
                      style: TextStyle(
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
              _row(DPIcons.bank, 'Bank', 'Paystack-Titan', copy: true),
              _row(DPIcons.wallet, 'Account Number', '9876543210',
                  highlight: true, copy: true),
              _row(DPIcons.user, 'Account Name', 'DALABAPAY / ADAEZE OKAFOR',
                  copy: true),
              Divider(height: 24, color: DP.border),
              _row(Icons.payments_outlined, 'Amount to transfer',
                  DP.naira(widget.amount + fee),
                  highlight: true),
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: Text(
                  'Includes ${DP.naira(fee)} funding fee. You\'ll receive ${DP.naira(widget.amount)}.',
                  style: DP.caption,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DPButton(
                  label: 'I\'ve sent the money',
                  onPressed: () {
                    dpSnack(
                      context,
                      'Thanks! Your wallet updates once the transfer lands.',
                      success: true,
                    );
                    Navigator.pop(context);
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
