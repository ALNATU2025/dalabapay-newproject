// lib/presentation/widgets/payment_flow.dart
// Shared "Review payment → PIN → result" flow used by every bill screen.
// The screen passes [onPay], which calls the backend with the PIN and
// returns the transaction; this page shows success, pending or failed.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api.dart';
import '../../core/api/session.dart';
import '../../core/format.dart';
import '../../ui/ui.dart';
import 'receipt_share.dart';

/// Commission rates (percent per service) from GET /api/services/rates.
class CommissionRates {
  CommissionRates._();
  static Map<String, double> _rates = {};
  static DateTime? _loadedAt;

  static Future<void> load({bool force = false}) async {
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5)) {
      return;
    }
    try {
      final data = asMap(await api.get('/api/services/rates'));
      _rates = data.map((k, v) => MapEntry(k, toDouble(v)));
      _loadedAt = DateTime.now();
    } catch (_) {}
  }

  static double? rateFor(String service) => _rates[service];
}

double? estimateCommission(String service, double amount) {
  final rate = CommissionRates.rateFor(service);
  if (rate == null || rate <= 0 || amount <= 0) return null;
  return amount * rate / 100;
}

/// Wallet balance + estimated commission summary card.
class WalletCommissionCard extends StatefulWidget {
  final double amount;
  final String service;
  final bool balanceVisible;

  const WalletCommissionCard({
    super.key,
    required this.amount,
    required this.service,
    this.balanceVisible = true,
  });

  @override
  State<WalletCommissionCard> createState() => _WalletCommissionCardState();
}

class _WalletCommissionCardState extends State<WalletCommissionCard> {
  @override
  void initState() {
    super.initState();
    CommissionRates.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final est = estimateCommission(widget.service, widget.amount);
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Session.instance,
      builder: (context, user, _) => DPCard(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Column(
          children: [
            DPSummaryRow(
              'Wallet balance',
              widget.balanceVisible ? DP.naira(user?.balance ?? 0) : '₦ ••••',
            ),
            if (est != null)
              DPSummaryRow(
                'Estimated commission',
                DP.naira(est),
                valueColor: DP.green,
              ),
          ],
        ),
      ),
    );
  }
}

/// Builds plain-text receipt lines for sharing.
String receiptText(Map<String, dynamic> txn, {String? title}) {
  final b = StringBuffer('DalabaPay receipt\n');
  if (title != null) b.writeln(title);
  b.writeln('Amount: ${DP.naira(toDouble(txn['amount']))}');
  b.writeln('Status: ${DPStatus.labelFor(str(txn['status']))}');
  if (txn['recipient'] != null) b.writeln('Recipient: ${txn['recipient']}');
  final m = asMap(txn['metadata']);
  if (m['token'] != null) b.writeln('Token: ${m['token']}');
  b.writeln('Reference: ${txn['reference']}');
  b.writeln('Date: ${dateTimeLabel(parseDate(txn['createdAt']))}');
  return b.toString();
}

void shareReceipt(Map<String, dynamic> txn, {String? title}) {
  Share.share(receiptText(txn, title: title ?? str(txn['description'])));
}

/// Opens the review screen. When the user pays, [onPay] is called with the
/// PIN and must return the transaction JSON. Returns that transaction, or
/// null if the user closed the screen without paying.
Future<Map<String, dynamic>?> showReviewAndPay(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String serviceLabel,
  required double amount,
  required List<DPReviewRow> rows,
  required String service,
  required Future<Map<String, dynamic>> Function(String pin) onPay,
  double fee = 0,
  String? footnote,
  String successTitle = 'Payment Successful!',
  String successSubtitle = 'Your transaction has been completed successfully.',
  List<DPReviewRow>? successRows,
  List<DPReviewRow> Function(Map<String, dynamic> txn)? resultRows,
  bool pinRequired = true,
  String payLabel = '',
}) {
  return Navigator.of(context).push<Map<String, dynamic>>(
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
        onPay: onPay,
        footnote: footnote,
        successTitle: successTitle,
        successSubtitle: successSubtitle,
        successRows: successRows,
        resultRows: resultRows,
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
  final Future<Map<String, dynamic>> Function(String pin) onPay;
  final String? footnote;
  final String successTitle;
  final String successSubtitle;
  final List<DPReviewRow>? successRows;
  final List<DPReviewRow> Function(Map<String, dynamic> txn)? resultRows;
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
    required this.onPay,
    required this.footnote,
    required this.successTitle,
    required this.successSubtitle,
    required this.successRows,
    required this.resultRows,
    required this.pinRequired,
    required this.payLabel,
  });

  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  final _pin = TextEditingController();
  bool _processing = false;
  String? _error;
  Map<String, dynamic>? _txn;

  @override
  void initState() {
    super.initState();
    CommissionRates.load().then((_) {
      if (mounted) setState(() {});
    });
    Session.instance.refreshQuietly();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final txn = await widget.onPay(_pin.text.trim());
      await Session.instance.refreshQuietly();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _txn = txn;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNetwork) {
        // The request may have reached the server: never invite a retry
        // that could pay twice. Send the customer to History instead.
        setState(() => _processing = false);
        await Session.instance.refreshQuietly();
        if (!mounted) return;
        await dpDialog(
          context,
          title: 'We couldn\'t confirm this payment',
          message:
              'Your connection dropped while paying. Please check Transaction History before trying again — if it went through, it\'s there.',
          confirmLabel: 'Open History',
          tone: DPTone.warning,
        );
        if (!mounted) return;
        final nav = Navigator.of(context);
        nav.pop();
        nav.pushNamed('/transactions');
        return;
      }
      if (e.code == 'PIN_NOT_SET') {
        setState(() => _processing = false);
        final go = await dpDialog(
          context,
          title: 'Create your payment PIN',
          message: 'You need a 6-digit payment PIN before you can pay.',
          confirmLabel: 'Create PIN',
          cancelLabel: 'Not now',
          tone: DPTone.info,
        );
        if (go == true && mounted) Navigator.pushNamed(context, '/pin-setup');
        return;
      }
      _pin.clear();
      setState(() {
        _processing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = errorMessage(e);
      });
    }
  }

  void _close() => Navigator.of(context).pop(_txn);

  /// The provider's logo when we have it (MTN, DStv…), else the service icon.
  Widget _providerLogo() {
    final name = '${widget.title} ${widget.serviceLabel}';
    final asset = DPAssets.providerFor(name);
    final icon = Icon(widget.icon, color: DP.navyIcon, size: 30);
    // Sierra Leone providers without a logo file: their name in their colour.
    final lower = name.toLowerCase();
    const named = {
      'orange': ('Orange', Color(0xFFFF7900)),
      'africell': ('Africell', Color(0xFF8E1F7E)),
      'qcell': ('Qcell', Color(0xFFE30613)),
      'edsa': ('EDSA', Color(0xFF0B6E4F)),
    };
    for (final e in named.entries) {
      if (asset == null && lower.contains(e.key)) {
        return FittedBox(
          child: Text(e.value.$1, style: TextStyle(color: e.value.$2, fontWeight: FontWeight.w900, fontSize: 16)),
        );
      }
    }
    if (asset == null) return icon;
    return DPImage(asset, width: 48, height: 48, fallback: icon);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.amount + widget.fee;
    final txn = _txn;

    if (txn != null) {
      final status = str(txn['status']);
      final extraRows = widget.resultRows?.call(txn) ?? const <DPReviewRow>[];
      final rows = [
        ...(widget.successRows ?? widget.rows.where((r) => !r.strong)),
        ...extraRows,
        DPReviewRow('Date & time', dateTimeLabel(parseDate(txn['createdAt']))),
        DPReviewRow('Reference', str(txn['reference'])),
      ];
      if (status == 'failed' || status == 'refunded') {
        return Scaffold(
          backgroundColor: DP.bg,
          body: _FailedPanel(
            title: 'Payment failed',
            message: txn['refunded'] == true
                ? 'The provider couldn\'t complete this payment. ${DP.naira(toDouble(txn['amount']))} has been returned to your wallet.'
                : 'The provider couldn\'t complete this payment.',
            reason: str(asMap(txn['metadata'])['failureReason']),
            reference: str(txn['reference']),
            onDone: _close,
          ),
        );
      }
      final pending = status == 'pending';
      final commission = toDouble(txn['commission']);
      return Scaffold(
        backgroundColor: DP.bg,
        body: DPSuccessPanel(
          title: pending ? 'Payment Pending' : widget.successTitle,
          subtitle: pending
              ? 'We\'re confirming this with the provider. You\'ll get a notification when it\'s done.'
              : widget.successSubtitle,
          serviceLabel: widget.serviceLabel,
          amount: toDouble(txn['amount']) + toDouble(txn['fee']),
          commission: commission > 0 ? commission : null,
          pending: pending,
          rows: rows,
          onDone: _close,
          onShare: () => showReceiptShareOptions(
                context,
                ReceiptData.fromTxn(txn, title: widget.title, extraRows: rows),
                text: receiptText(txn, title: widget.title),
              ),
          provider: _providerLogo(),
        ),
      );
    }

    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        backgroundColor: DP.bg,
        body: ValueListenableBuilder<AppUser?>(
          valueListenable: Session.instance,
          builder: (context, user, _) => DPReviewPanel(
            icon: widget.icon,
            title: widget.title,
            amount: widget.amount,
            rows: widget.rows,
            walletBalance: user?.balance,
            totalDebit: total,
            commission: estimateCommission(widget.service, widget.amount),
            pinController: _pin,
            pinRequired: widget.pinRequired,
            pinError: _error,
            processing: _processing,
            onPay: _pay,
            onClose: () => Navigator.of(context).pop(),
            footnote: widget.footnote,
            payLabel: widget.payLabel,
          ),
        ),
      ),
    );
  }
}

class _FailedPanel extends StatelessWidget {
  final String title;
  final String message;
  final String reason;
  final String reference;
  final VoidCallback onDone;
  const _FailedPanel({
    required this.title,
    required this.message,
    required this.reason,
    required this.reference,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          DPLogoBar(
            onLeading: onDone,
            actionLabel: 'Help',
            onAction: () => Navigator.pushNamed(context, '/help'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              children: [
                const Center(
                    child: DPStatusHero(kind: DPStatusKind.failed, size: 92)),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: DP.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: DP.body.copyWith(color: DP.muted),
                ),
                const SizedBox(height: 20),
                DPCard(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      if (reason.isNotEmpty) DPSummaryRow('Reason', reason),
                      DPSummaryRow('Reference', reference),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DPBottomAction(
            child: DPButton(label: 'Done', onPressed: onDone),
          ),
        ],
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
