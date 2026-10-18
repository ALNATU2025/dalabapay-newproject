// lib/presentation/widgets/payment_flow.dart
// Shared "Review payment → PIN → Payment successful" flow used by every
// bill screen. UI only: "Pay" waits a moment and shows the success screen.
// Nothing is charged and no request is made.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../mock/mock_data.dart';
import '../../ui/ui.dart';

/// Sample commission rates (percent) so the "Estimated commission" row has
/// something to show. Replace with the backend's rates.
const Map<String, double> kMockCommissionRates = {
  'airtime': 2.0,
  'data': 2.5,
  'electricity': 0.5,
  'cable': 1.0,
  'education': 1.5,
  'insurance': 2.0,
  'international': 1.0,
};

double? estimateCommission(String service, double amount) {
  final rate = kMockCommissionRates[service];
  if (rate == null || amount <= 0) return null;
  return amount * rate / 100;
}

/// Wallet balance + estimated commission summary card.
class WalletCommissionCard extends StatelessWidget {
  final double walletBalance;
  final double amount;
  final String service;
  final bool balanceVisible;

  const WalletCommissionCard({
    super.key,
    this.walletBalance = MockUser.walletBalance,
    required this.amount,
    required this.service,
    this.balanceVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final est = estimateCommission(service, amount);
    return DPCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Column(
        children: [
          DPSummaryRow(
            'Wallet balance',
            balanceVisible ? DP.naira(walletBalance) : '₦ ••••',
          ),
          if (est != null)
            DPSummaryRow(
              'Estimated commission',
              DP.naira(est),
              valueColor: DP.green,
            ),
        ],
      ),
    );
  }
}

/// Opens the review screen. When the user pays, the success screen replaces
/// it. [service] picks the sample commission rate.
Future<void> showReviewAndPay(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String serviceLabel,
  required double amount,
  required List<DPReviewRow> rows,
  required String service,
  double fee = 0,
  String? footnote,
  String successTitle = 'Payment Successful!',
  String successSubtitle = 'Your transaction has been completed successfully.',
  List<DPReviewRow>? successRows,
  bool pinRequired = true,
  String payLabel = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ReviewPage(
        icon: icon,
        title: title,
        serviceLabel: serviceLabel,
        amount: amount,
        fee: fee,
        rows: rows,
        service: service,
        footnote: footnote,
        successTitle: successTitle,
        successSubtitle: successSubtitle,
        successRows: successRows,
        pinRequired: pinRequired,
        payLabel: payLabel,
      ),
    ),
  );
}

class _ReviewPage extends StatefulWidget {
  final IconData icon;
  final String title;
  final String serviceLabel;
  final double amount;
  final double fee;
  final List<DPReviewRow> rows;
  final String service;
  final String? footnote;
  final String successTitle;
  final String successSubtitle;
  final List<DPReviewRow>? successRows;
  final bool pinRequired;
  final String payLabel;

  const _ReviewPage({
    required this.icon,
    required this.title,
    required this.serviceLabel,
    required this.amount,
    required this.fee,
    required this.rows,
    required this.service,
    required this.footnote,
    required this.successTitle,
    required this.successSubtitle,
    required this.successRows,
    required this.pinRequired,
    required this.payLabel,
  });

  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  final _pin = TextEditingController();
  bool _processing = false;
  bool _done = false;
  late final String _reference =
      'DP${DateTime.now().millisecondsSinceEpoch}${math.Random().nextInt(90) + 10}';

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _processing = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.amount + widget.fee;
    final commission = estimateCommission(widget.service, widget.amount);

    if (_done) {
      return Scaffold(
        backgroundColor: DP.bg,
        body: DPSuccessPanel(
          title: widget.successTitle,
          subtitle: widget.successSubtitle,
          serviceLabel: widget.serviceLabel,
          amount: total,
          commission: commission,
          rows: [
            ...(widget.successRows ?? widget.rows.where((r) => !r.strong)),
            DPReviewRow('Date & time', mockDateTime(DateTime.now())),
            DPReviewRow('Reference', _reference),
          ],
          onDone: () => Navigator.of(context).pop(),
          onShare: () => dpSnack(context, 'Sharing isn\'t set up in this UI build'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DP.bg,
      body: DPReviewPanel(
        icon: widget.icon,
        title: widget.title,
        amount: widget.amount,
        rows: widget.rows,
        walletBalance: MockUser.walletBalance,
        totalDebit: total,
        commission: commission,
        pinController: _pin,
        pinRequired: widget.pinRequired,
        processing: _processing,
        onPay: _pay,
        onClose: () => Navigator.of(context).pop(),
        biometricAvailable: true,
        biometricLabel: 'fingerprint',
        onBiometric: _pay,
        footnote: widget.footnote,
        payLabel: widget.payLabel,
      ),
    );
  }
}

/// Section title used on the bill screens.
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: DP.section),
    );
  }
}
