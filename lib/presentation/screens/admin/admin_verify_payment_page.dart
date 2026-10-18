// lib/presentation/screens/admin/admin_verify_payment_page.dart
// Verify Payments — UI only. Check a reference or credit a user manually.
// Sample rule: references ending 0–3 verify, 4–6 are pending, others fail.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
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
  bool _advanced = false;
  bool _busy = false;
  int _verifiedToday = 14;
  double _amountToday = 412500;
  final List<_LogLine> _log = [];

  @override
  void dispose() {
    for (final c in [_ref, _userId, _amount, _desc]) {
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
    await Future.delayed(const Duration(milliseconds: 400));
    _add('INFO', 'Validating reference format...');
    await Future.delayed(const Duration(milliseconds: 500));
    _add('INFO', 'Verifying with payment service...');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final last = int.tryParse(r.substring(r.length - 1)) ?? 9;
    setState(() => _busy = false);
    if (last <= 3) {
      _add('SUCCESS', '$r verified · ₦25,000.00 credited to Chidi Eze');
      setState(() {
        _verifiedToday++;
        _amountToday += 25000;
      });
      _result('Verified', 'Payment verified and wallet credited.', r, true);
    } else if (last <= 6) {
      _add('WARNING', '$r is still pending with the bank');
      _result('Pending', 'The bank hasn\'t confirmed this payment yet.', r, false);
    } else {
      _add('FAILURE', 'No Transaction Found for $r');
      _result('No Transaction Found', 'Check the reference and try again.', r,
          false);
    }
  }

  void _result(String title, String msg, String ref, bool ok) {
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
                if (title != 'No Transaction Found') ...[
                  const DPSummaryRow('User', 'Chidi Eze'),
                  const DPSummaryRow('Amount', '₦25,000.00'),
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
    if (_userId.text.trim().isEmpty || a <= 0) {
      dpSnack(context, 'Please enter User ID and Amount', error: true);
      return;
    }
    setState(() => _busy = true);
    _add('START', 'Processing manual top-up...');
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verifiedToday++;
      _amountToday += a;
    });
    _add('SUCCESS',
        'Manual top-up ${DP.naira(a)} → ${_userId.text.trim()}');
    dpSnack(context, 'Manual top-up of ${DP.naira(a)} done', success: true);
    _userId.clear();
    _amount.clear();
    _desc.clear();
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
          if (_advanced) ...[
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
                  const DPLabel('User ID'),
                  DPField(controller: _userId, hint: 'Enter user ID'),
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
