// lib/presentation/screens/admin/admin_verify_payment_page.dart
// Verify Payments: check a top-up by reference with the payment provider
// (POST /api/admin/payments/verify) or credit a user manually when a
// transfer arrived but wasn't matched (POST /api/admin/payments/manual).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminVerifyPaymentPage extends StatefulWidget {
  const AdminVerifyPaymentPage({super.key});

  @override
  State<AdminVerifyPaymentPage> createState() => _AdminVerifyPaymentPageState();
}

class _LogLine {
  final String level; // START, INFO, SUCCESS, WARNING, FAILURE
  final String text;
  final DateTime at;
  _LogLine(this.level, this.text) : at = DateTime.now();
}

class _AdminVerifyPaymentPageState extends State<AdminVerifyPaymentPage> {
  final _ref = TextEditingController();
  final _userId = TextEditingController();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _bankRef = TextEditingController();
  bool _advanced = false;
  bool _busy = false;
  int _verifiedToday = 0;
  double _amountToday = 0;
  final List<_LogLine> _log = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final r = asMap(await api.get('/api/admin/payments/verify/stats'));
      if (!mounted) return;
      setState(() {
        _verifiedToday = toInt(r['verifiedToday']);
        _amountToday = toDouble(r['amountToday']);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_ref, _userId, _amount, _desc, _bankRef]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add(String level, String text) {
    if (!mounted) return;
    setState(() => _log.insert(0, _LogLine(level, text)));
  }

  Future<void> _verify() async {
    final r = _ref.text.trim();
    if (r.isEmpty) {
      dpSnack(context, 'Please enter a transaction reference', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    _add('START', 'Verifying $r');
    _add('INFO', 'Checking with the payment service...');
    Map<String, dynamic> res;
    try {
      res = asMap(await api.post('/api/admin/payments/verify', {'reference': r}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _add('FAILURE', errorMessage(e));
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final status = str(res['status']);
    final txn = res['transaction'] is Map ? asMap(res['transaction']) : null;
    final user = str(asMap(txn?['user'])['fullName'], 'the user');
    final amount = DP.naira(toDouble(txn?['amount']));
    if (status == 'success') {
      _add('SUCCESS', '$r verified · $amount for $user');
      _loadStats();
      _result('Verified', 'Payment verified and wallet credited.', r, true, txn);
    } else if (status == 'pending') {
      _add('WARNING', '$r is still pending with the bank');
      _result('Pending', 'The bank hasn\'t confirmed this payment yet.', r, false, txn);
    } else if (status == 'not_found') {
      _add('FAILURE', 'No Transaction Found for $r');
      _result('No Transaction Found', 'Check the reference and try again.', r,
          false, null);
    } else {
      _add('WARNING', '$r is ${statusLabel(status).toLowerCase()}');
      _result(statusLabel(status), 'This top-up was not completed.', r, false, txn);
    }
  }

  void _result(String title, String msg, String ref, bool ok,
      Map<String, dynamic>? txn) {
    showAdminSheet(
      context,
      title: 'Transaction Details',
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DPStatusHero(
              kind: ok
                  ? DPStatusKind.success
                  : (title == 'Pending'
                      ? DPStatusKind.pending
                      : DPStatusKind.failed),
              size: 76,
            ),
          ),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: DP.title),
          const SizedBox(height: 4),
          Text(msg,
              textAlign: TextAlign.center,
              style: DP.body.copyWith(color: DP.muted)),
          const SizedBox(height: 14),
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                DPSummaryRow('Reference', ref),
                if (txn != null) ...[
                  DPSummaryRow('User', str(asMap(txn['user'])['fullName'], '—')),
                  DPSummaryRow('Email', str(asMap(txn['user'])['email'], '—')),
                  DPSummaryRow('Amount', DP.naira(toDouble(txn['amount']))),
                  DPSummaryRow('Date', dateTimeLabel(parseDate(txn['createdAt']))),
                  DPSummaryRow('Status', title,
                      valueColor: StatusPill.colorFor(title)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          DPButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Future<void> _manual() async {
    final a = double.tryParse(_amount.text) ?? 0;
    if (_userId.text.trim().length < 3 || a <= 0) {
      dpSnack(context, 'Please enter the user and amount', error: true);
      return;
    }
    final ok = await dpDialog(
      context,
      title: 'Credit ${DP.naira(a)}?',
      message: 'This adds ${DP.naira(a)} to ${_userId.text.trim()}\'s wallet. Only do this once you\'ve confirmed the money arrived.',
      confirmLabel: 'Credit wallet',
      cancelLabel: 'Cancel',
      tone: DPTone.warning,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    _add('START', 'Processing manual top-up...');
    Map<String, dynamic> res;
    try {
      res = asMap(await api.post('/api/admin/payments/manual', {
        'user': _userId.text.trim(),
        'amount': a,
        if (_bankRef.text.trim().isNotEmpty) 'reference': _bankRef.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      }));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _add('FAILURE', errorMessage(e));
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final who = str(asMap(res['user'])['fullName'], _userId.text.trim());
    _add('SUCCESS', 'Manual top-up ${DP.naira(a)} → $who');
    dpSnack(context, 'Manual top-up of ${DP.naira(a)} done', success: true);
    _loadStats();
    _userId.clear();
    _amount.clear();
    _desc.clear();
    _bankRef.clear();
  }

  Color _levelColor(String l) => switch (l) {
        'SUCCESS' => DP.green,
        'WARNING' => DP.amber,
        'FAILURE' => DP.red,
        'START' => DP.navy,
        _ => DP.navyIcon,
      };

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Verify Payment',
      breadcrumb: 'Admin / Verify Payment',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Verified Today',
                value: '$_verifiedToday',
                icon: Icons.verified_outlined,
                color: DP.green,
              ),
              AdminStat(
                label: 'Amount Today',
                value: DP.naira(_amountToday, decimals: false),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const DPSectionHeader('Transaction Verification'),
          DPField(
            controller: _ref,
            hint: 'Enter payment reference',
            prefix: const Icon(DPIcons.receipt, size: 20),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 12),
          DPButton(
            label: _busy ? 'Verifying...' : 'Verify',
            icon: DPIcons.search,
            loading: _busy,
            onPressed: _busy ? null : _verify,
          ),
          const SizedBox(height: 10),
          Center(
            child: DPTextLink(
              label: _advanced ? 'Hide Advanced' : 'Advanced Options',
              onTap: () => setState(() => _advanced = !_advanced),
            ),
          ),
          if (_advanced && adminCan('wallet:fund')) ...[
            const SizedBox(height: 10),
            DPCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manual Verification', style: DP.section),
                  const SizedBox(height: 4),
                  Text(
                    'Credit a user directly when a transfer arrived but wasn\'t matched.',
                    style: DP.caption,
                  ),
                  const SizedBox(height: 14),
                  const DPLabel('User (email, phone or ID)'),
                  DPField(controller: _userId, hint: 'e.g. user@example.com'),
                  const SizedBox(height: 12),
                  const DPLabel('Amount'),
                  DPField(
                    controller: _amount,
                    hint: 'Enter amount',
                    prefixText: '₦  ',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  const DPLabel('Bank reference (recommended)'),
                  DPField(
                    controller: _bankRef,
                    hint: 'Stops the same transfer being credited twice',
                  ),
                  const SizedBox(height: 12),
                  const DPLabel('Description (Optional)'),
                  DPField(
                    controller: _desc,
                    hint: 'Enter verification description',
                  ),
                  const SizedBox(height: 16),
                  DPButton.mint(
                    label: 'Manual Verify',
                    onPressed: _busy ? null : _manual,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          DPSectionHeader(
            'Verification Log',
            actionLabel: _log.isEmpty ? null : 'Clear',
            onAction: () => setState(_log.clear),
          ),
          if (_log.isEmpty)
            DPCard(
              child: Text(
                'Verification steps will appear here.',
                style: DP.caption,
              ),
            )
          else
            DPCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final l in _log)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 68,
                            child: Text(
                              l.level,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _levelColor(l.level),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(l.text,
                                style: DP.caption.copyWith(color: DP.inkSoft)),
                          ),
                          Text(
                            '${l.at.hour.toString().padLeft(2, '0')}:${l.at.minute.toString().padLeft(2, '0')}:${l.at.second.toString().padLeft(2, '0')}',
                            style: DP.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
