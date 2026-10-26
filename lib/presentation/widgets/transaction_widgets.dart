// lib/presentation/widgets/transaction_widgets.dart
// Transaction list helpers and the receipt sheet. Rows take the
// transaction JSON returned by the API.
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../ui/ui.dart';
import 'payment_flow.dart';
import 'receipt_share.dart';

bool txIsCredit(Map<String, dynamic> t) =>
    t['isCredit'] == true || t['direction'] == 'credit';

/// The transaction's currency ("NGN"/"SLE"), for formatting its amounts.
String txCurrency(Map<String, dynamic> t) =>
    t['currency']?.toString() ?? DP.currency;

/// Formats an amount of [t] in its own currency.
String txMoney(Map<String, dynamic> t, num? v) => DP.moneyIn(v, txCurrency(t));

bool txIsCommissionWallet(Map<String, dynamic> t) => t['wallet'] == 'commission';

IconData transactionIcon(String type) {
  final t = type.toLowerCase();
  if (t.contains('airtime')) return DPIcons.smartphone;
  if (t.contains('data')) return DPIcons.wifi;
  if (t.contains('electric')) return DPIcons.bolt;
  if (t.contains('cable') || t.contains('tv')) return DPIcons.tv;
  if (t.contains('education')) return DPIcons.school;
  if (t.contains('insurance')) return DPIcons.shield;
  if (t.contains('commission') || t.contains('referral')) {
    return DPIcons.sparkle;
  }
  if (t == 'transfer_in' || t == 'refund' || t == 'admin_credit') {
    return DPIcons.downLeft;
  }
  if (t.contains('transfer') || t == 'admin_debit') return DPIcons.upRight;
  if (t.contains('international')) return DPIcons.smartphone;
  if (t.contains('fund') || t.contains('wallet')) return DPIcons.downLeft;
  return DPIcons.receipt;
}

String transactionTypeLabel(String type) {
  switch (type) {
    case 'airtime':
      return 'Airtime Purchase';
    case 'data':
      return 'Data Purchase';
    case 'cable':
      return 'Cable TV Purchase';
    case 'electricity':
      return 'Electricity Purchase';
    case 'education':
      return 'Education Purchase';
    case 'insurance':
      return 'Insurance Purchase';
    case 'international':
      return 'International Airtime';
    case 'transfer':
    case 'transfer_out':
      return 'Money Sent';
    case 'transfer_in':
      return 'Money Received';
    case 'wallet_funding':
      return 'Fund Wallet';
    case 'commission':
      return 'Commission Credit';
    case 'commission_withdrawal':
      return 'Commission to Wallet';
    case 'referral_bonus':
      return 'Referral Bonus';
    case 'refund':
      return 'Refund';
    case 'admin_credit':
      return 'Wallet Credit';
    case 'admin_debit':
      return 'Wallet Debit';
    case 'sl_airtime':
      return 'Airtime Purchase';
    case 'sl_data':
      return 'Data Purchase';
    case 'sl_electricity':
      return 'EDSA Electricity';
    case 'sl_cable':
      return 'Cable TV Purchase';
  }
  return 'Transaction';
}

/// One row in a transaction list. Credits are green, debits stay in the
/// ink colour (calmer than red for everyday spending), failed payments are
/// struck through, and anything not yet successful gets a status pill.
class TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool detailed;
  const TransactionRow({super.key, required this.tx, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final isCredit = txIsCredit(tx);
    final amount = toDouble(tx['amount']);
    final type = str(tx['type']);
    final date = parseDate(tx['createdAt']);
    final status = DPStatus.labelFor(tx['status'] as String?);
    final failed = status == 'Failed';
    final settled = status == 'Successful';
    final amountColor = failed ? DP.muted : (isCredit ? DP.green : DP.ink);
    final earnings = txIsCommissionWallet(tx);

    return Semantics(
      button: true,
      label:
          '${str(tx['description'], transactionTypeLabel(type))}, ${isCredit ? 'received' : 'paid'} ${txMoney(tx, amount)}, $status, ${dateTimeLabel(date)}',
      excludeSemantics: true,
      child: DPListRow(
        onTap: () => showTransactionReceipt(context, tx),
        padding: const EdgeInsets.symmetric(vertical: 12),
        subtitleMaxLines: 1,
        leading: DPIconBadge(
          transactionIcon(type),
          size: detailed ? 46 : 44,
          iconSize: 21,
          color: failed ? DP.muted : (isCredit ? DP.green : DP.navyInk),
          background: failed ? DP.borderSoft : (isCredit ? DP.mint : DP.blueTint),
        ),
        title: str(tx['description'], transactionTypeLabel(type)),
        subtitle: detailed
            ? '${transactionTypeLabel(type)} · ${_time(date)}'
            : '${timeAgo(date)}${earnings ? '  •  Earnings' : ''}',
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${failed ? '' : (isCredit ? '+ ' : '- ')}${txMoney(tx, amount)}',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: amountColor,
                decoration: failed ? TextDecoration.lineThrough : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (!settled) ...[
              const SizedBox(height: 4),
              DPStatusPill(failed ? 'Failed · no debit' : status),
            ],
          ],
        ),
      ),
    );
  }

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Small coloured pill for a status word ("Pending", "Failed").
class DPStatusPill extends StatelessWidget {
  final String label;
  const DPStatusPill(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = DPStatus.colorFor(label.split(' ').first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: DP.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(DP.rPill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

/// Day heading inside a transaction list ("Today", "Yesterday"…).
class TransactionDayHeader extends StatelessWidget {
  final DateTime day;
  const TransactionDayHeader(this.day, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
        child: Text(
          dayLabel(day).toUpperCase(),
          style: DP.tiny.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
      ),
    );
  }
}

/// Receipt bottom sheet for a transaction.
Future<void> showTransactionReceipt(
  BuildContext context,
  Map<String, dynamic> tx,
) {
  final amount = toDouble(tx['amount']);
  final fee = toDouble(tx['fee']);
  final commission = toDouble(tx['commission']);
  final status = DPStatus.labelFor(tx['status'] as String?);
  final kind = DPStatusHero.kindFor(status);
  final date = parseDate(tx['createdAt']);
  final meta = asMap(tx['metadata']);
  final target = tx['recipient']?.toString();
  final token = meta['token']?.toString();
  final pins = asList(meta['pins']);
  final description = str(tx['description'], transactionTypeLabel(str(tx['type'])));

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: DP.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => SafeArea(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const DPSheetHandle(),
            const SizedBox(height: 8),
            const Center(child: DPWordmark(height: 26)),
            const SizedBox(height: 18),
            Center(child: DPStatusHero(kind: kind, size: 76)),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: DP.body.copyWith(color: DP.muted),
            ),
            const SizedBox(height: 4),
            Text(
              txMoney(tx, amount),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: DP.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: DPStatus.colorFor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DPStatus.colorFor(status),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DPCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  DPSummaryRow(
                    'Type',
                    transactionTypeLabel(str(tx['type'])),
                  ),
                  if (target != null && target.isNotEmpty)
                    DPSummaryRow('Recipient', target),
                  if (meta['customerName'] != null)
                    DPSummaryRow('Customer', str(meta['customerName'])),
                  if (meta['plan'] != null) DPSummaryRow('Plan', str(meta['plan'])),
                  if (token != null) DPSummaryRow('Token', token),
                  if (meta['units'] != null) DPSummaryRow('Units', str(meta['units'])),
                  for (final p in pins)
                    DPSummaryRow('PIN', '${p['pin']}${p['serial'] != null ? ' (S/N ${p['serial']})' : ''}'),
                  if (meta['certificateNumber'] != null)
                    DPSummaryRow('Certificate', str(meta['certificateNumber'])),
                  if (meta['note'] != null && str(meta['note']).isNotEmpty)
                    DPSummaryRow('Note', str(meta['note'])),
                  DPSummaryRow('Date & time', dateTimeLabel(date)),
                  DPSummaryRow('Reference', str(tx['reference'])),
                  DPSummaryRow('Fee', txMoney(tx, fee)),
                  if (commission > 0)
                    DPSummaryRow('Commission earned', txMoney(tx, commission),
                        valueColor: DP.green),
                  if (tx['refunded'] == true)
                    const DPSummaryRow('Refund', 'Returned to wallet'),
                  DPSummaryRow('Total', txMoney(tx, txIsCredit(tx) ? amount : amount + fee), strong: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DPButton(
              label: 'Share Receipt',
              icon: DPIcons.share,
              onPressed: () => showReceiptShareOptions(ctx, ReceiptData.fromTxn(tx), text: receiptText(tx, title: description)),
            ),
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Report an issue',
              icon: DPIcons.flag,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/user-disputes',
                    arguments: tx['id']);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
