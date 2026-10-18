// lib/presentation/screens/validation/transaction_validation_page.dart
// "Verify Payment": looks up a wallet top-up by its reference
// (POST /api/wallet/verify-payment). Recent top-ups and counts come from
// GET /api/wallet/fundings.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';

class TransactionValidationPage extends StatefulWidget {
  const TransactionValidationPage({super.key});

  @override
  State<TransactionValidationPage> createState() =>
      _TransactionValidationPageState();
}

class _TransactionValidationPageState extends State<TransactionValidationPage> {
  final _ref = TextEditingController();
  bool _checking = false;
  List<Map<String, dynamic>> _recent = [];
  int _verified = 0;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _ref.addListener(() => setState(() {}));
    _loadFundings();
  }

  Future<void> _loadFundings() async {
    try {
      final r = asMap(await api.get('/api/wallet/fundings'));
      if (!mounted) return;
      setState(() {
        _recent = itemsOf(r);
        _verified = toInt(r['verified']);
        _pending = toInt(r['pending']);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final r = _ref.text.trim();
    if (r.length < 6) {
      dpSnack(context, 'Reference is too short', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    Map<String, dynamic> res;
    try {
      res = asMap(await api.post('/api/wallet/verify-payment', {'reference': r}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    final status = str(res['status']);
    final txn = res['transaction'] is Map ? asMap(res['transaction']) : null;
    if (status == 'success') {
      Session.instance.refreshQuietly();
      _loadFundings();
      _result(
        DPStatusKind.success,
        'Transaction Verified ✅',
        'This transaction has been verified and credited to your wallet.',
        'Verify Another',
        txn,
      );
    } else if (status == 'pending') {
      _result(
        DPStatusKind.pending,
        'Transaction Pending',
        'No funds have been added to your wallet yet. Please wait for the payment to complete.',
        'OK',
        txn,
      );
    } else if (status == 'not_found') {
      _result(
        DPStatusKind.failed,
        'Transaction Not Found',
        'We could not find this transaction in our system. Check the reference or contact support.',
        'Contact Support',
        null,
      );
    } else {
      _result(
        DPStatusKind.failed,
        'Transaction ${DPStatus.labelFor(status)}',
        'This top-up didn\'t go through. Contact support if money left your bank account.',
        'Contact Support',
        txn,
      );
    }
  }

  void _result(DPStatusKind kind, String title, String msg, String button,
      Map<String, dynamic>? txn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 12),
              DPStatusHero(kind: kind, size: 80),
              const SizedBox(height: 12),
              Text(title, style: DP.title, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              DPCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    DPSummaryRow('Reference', _ref.text.trim()),
                    if (txn != null) ...[
                      DPSummaryRow('Amount', DP.naira(toDouble(txn['amount']))),
                      if (toDouble(txn['fee']) > 0)
                        DPSummaryRow('Fee', DP.naira(toDouble(txn['fee']))),
                      DPSummaryRow('Date', dateTimeLabel(parseDate(txn['createdAt']))),
                      DPSummaryRow(
                        'Status',
                        DPStatus.labelFor(str(txn['status'])),
                        valueColor: DPStatus.colorFor(str(txn['status'])),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: DP.body.copyWith(color: DP.muted),
              ),
              const SizedBox(height: 20),
              DPButton(
                label: button,
                onPressed: () {
                  Navigator.pop(ctx);
                  if (button == 'Contact Support') {
                    Navigator.pushNamed(context, '/help');
                  } else {
                    _ref.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Transaction Validation'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: DP.navyGradient,
                      borderRadius: BorderRadius.circular(DP.rXl),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(DPIcons.shieldCheck,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verify Payment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Check your transaction status instantly',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stat('Verified', '$_verified', DP.green, DPIcons.checkCircle),
                      const SizedBox(width: 10),
                      _stat('Pending', '$_pending', DP.amber, DPIcons.pending),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const DPLabel('Transaction Reference'),
                  DPField(
                    controller: _ref,
                    hint: 'e.g. WF20260118…',
                    prefix: const Icon(DPIcons.receipt, size: 20),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 16),
                  DPButton(
                    label: 'Verify transaction',
                    icon: DPIcons.search,
                    loading: _checking,
                    onPressed: _ref.text.trim().isEmpty ? null : _verify,
                  ),
                  const SizedBox(height: 24),
                  const DPSectionHeader('Recent top-ups'),
                  DPCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        if (recent.isEmpty)
                          const DPEmptyState(
                            icon: DPIcons.downLeft,
                            title: 'No top-ups yet',
                          ),
                        for (final t in recent)
                          DPListRow(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            leading: const DPIconBadge(DPIcons.downLeft,
                                size: 40, iconSize: 19),
                            title: str(t['description'], 'Wallet top-up'),
                            subtitle:
                                '${str(t['reference'])} · ${DPStatus.labelFor(str(t['status']))}',
                            trailing: Text(
                              DP.naira(toDouble(t['amount'])),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: DPStatus.colorFor(str(t['status'])),
                              ),
                            ),
                            onTap: () => _ref.text = str(t['reference']),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  DPCard(
                    color: DP.blueTint,
                    borderColor: null,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(DPIcons.help, color: DP.navyIcon),
                            SizedBox(width: 8),
                            Text('Need Help?', style: DP.section),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '• Your reference can be found in your transaction receipt\n'
                          '• You can also use the bank\'s transfer reference\n'
                          '• Each transaction can only be verified once\n'
                          '• For pending transactions, wait a few minutes or contact support',
                          style: DP.caption.copyWith(
                            color: DP.inkSoft,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DPOutlineButton(
                          label: 'Contact Support',
                          icon: DPIcons.messageCircle,
                          onPressed: () =>
                              Navigator.pushNamed(context, '/help'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color c, IconData icon) {
    return Expanded(
      child: DPCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                Text(label, style: DP.caption.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
