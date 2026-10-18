// lib/presentation/widgets/transaction_widgets.dart
// Transaction list helpers and the receipt sheet (UI only).
import 'package:flutter/material.dart';

import '../../mock/mock_data.dart';
import '../../ui/ui.dart';

IconData transactionIcon(String type) {
  final t = type.toLowerCase();
  if (t.contains('airtime')) return DPIcons.smartphone;
  if (t.contains('data')) return DPIcons.wifi;
  if (t.contains('electric')) return DPIcons.bolt;
  if (t.contains('cable') || t.contains('tv')) return DPIcons.tv;
  if (t.contains('education')) return DPIcons.school;
  if (t.contains('insurance')) return DPIcons.shield;
  if (t.contains('commission')) return DPIcons.sparkle;
  if (t.contains('transfer')) return DPIcons.upRight;
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
    case 'transfer':
      return 'Transfer';
    case 'wallet_funding':
      return 'Fund Wallet';
    case 'commission':
      return 'Commission Credit';
  }
  return 'Transaction';
}

/// One row in a transaction list.
class TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool detailed;
  const TransactionRow({super.key, required this.tx, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final isCredit = mockIsCredit(tx);
    final amount = (tx['amount'] as num).toDouble();
    final type = tx['type'] as String;
    final date = DateTime.parse(tx['createdAt'] as String);
    final status = DPStatus.labelFor(tx['status'] as String?);
    final failed = status == 'Failed';
    final amountColor = failed ? DP.muted : (isCredit ? DP.green : DP.red);
    final label = tx['isCommission'] == true ? 'Commission' : status;

    return DPListRow(
      onTap: () => showTransactionReceipt(context, tx),
      padding: const EdgeInsets.symmetric(vertical: 12),
      subtitleMaxLines: detailed ? 2 : 1,
      leading: DPIconBadge(
        transactionIcon(type),
        size: detailed ? 46 : 44,
        iconSize: 21,
        color: failed ? DP.muted : (isCredit ? DP.green : DP.red),
        background: failed ? DP.borderSoft : (isCredit ? DP.mint : DP.redBg),
      ),
      title: tx['description'] as String,
      subtitle: detailed
          ? '${transactionTypeLabel(type)}${status != 'Successful' ? ' · $status' : ''}\n${mockDateTime(date)}'
          : '${mockTimeAgo(date)}  •  $label',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${failed ? '' : (isCredit ? '+ ' : '- ')}${DP.naira(amount)}',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: amountColor,
              decoration: failed ? TextDecoration.lineThrough : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (detailed && status != 'Successful')
            Text(
              failed ? 'No debit' : status,
              style: TextStyle(
                fontSize: 11.5,
                color: DPStatus.colorFor(status),
              ),
            ),
        ],
      ),
    );
  }
}

/// Receipt bottom sheet for a transaction.
Future<void> showTransactionReceipt(
  BuildContext context,
  Map<String, dynamic> tx,
) {
  final amount = (tx['amount'] as num).toDouble();
  final status = DPStatus.labelFor(tx['status'] as String?);
  final kind = DPStatusHero.kindFor(status);
  final date = DateTime.parse(tx['createdAt'] as String);
  final target = (tx['phone'] ?? tx['meterNumber'] ?? tx['smartcardNumber'])
      ?.toString();

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
              tx['description'] as String,
              textAlign: TextAlign.center,
              style: DP.body.copyWith(color: DP.muted),
            ),
            const SizedBox(height: 4),
            Text(
              DP.naira(amount),
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
                    transactionTypeLabel(tx['type'] as String),
                  ),
                  if (target != null) DPSummaryRow('Recipient', target),
                  DPSummaryRow('Date & time', mockDateTime(date)),
                  DPSummaryRow('Reference', tx['id'] as String),
                  const DPSummaryRow('Fee', '₦0.00'),
                  DPSummaryRow('Total', DP.naira(amount), strong: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DPButton(
              label: 'Share Receipt',
              icon: DPIcons.share,
              onPressed: () => dpSnack(
                ctx,
                'Sharing isn\'t set up in this UI build',
              ),
            ),
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Report an issue',
              icon: DPIcons.flag,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/user-disputes');
              },
            ),
          ],
        ),
      ),
    ),
  );
}
