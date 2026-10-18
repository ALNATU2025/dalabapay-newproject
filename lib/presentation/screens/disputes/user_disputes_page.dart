// lib/presentation/screens/disputes/user_disputes_page.dart
// My Disputes — UI only. Lists sample disputes and lets you "file" one
// against a sample transaction (kept on screen only).
import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/transaction_widgets.dart';

class _Dispute {
  final String ref;
  final String title;
  final double amount;
  final String type;
  final String reason;
  final String status; // pending, investigating, resolved, rejected
  final Duration ago;
  final String? resolution;
  const _Dispute(
    this.ref,
    this.title,
    this.amount,
    this.type,
    this.reason,
    this.status,
    this.ago, [
    this.resolution,
  ]);
}

class UserDisputesPage extends StatefulWidget {
  const UserDisputesPage({super.key});

  @override
  State<UserDisputesPage> createState() => _UserDisputesPageState();
}

class _UserDisputesPageState extends State<UserDisputesPage> {
  int _tab = 0;
  final List<_Dispute> _disputes = [
    const _Dispute(
      'TXN-240115-0006',
      'Airtel Data 10GB',
      3000,
      'Service not delivered',
      'Data was not credited to my line',
      'investigating',
      Duration(days: 2),
    ),
    const _Dispute(
      'TXN-240102-0021',
      'MTN Airtime',
      1000,
      'Failed transaction',
      'Wallet debited but airtime failed',
      'resolved',
      Duration(days: 16),
      'Refunded ₦1,000.00 to your wallet.',
    ),
  ];

  static const _types = [
    'Service not delivered',
    'Incorrect amount',
    'Failed transaction',
    'Pending transaction',
    'Refund request',
    'Other',
  ];

  (String, Color) _statusStyle(String s) => switch (s) {
        'pending' => ('Pending Review', DP.amber),
        'investigating' => ('Investigating', DP.navyIcon),
        'resolved' => ('Resolved ✓', DP.green),
        'rejected' => ('Rejected ✗', DP.red),
        _ => ('Under Review', DP.amber),
      };

  void _openNewDispute(Map<String, dynamic> tx) {
    String type = _types.first;
    final reason = TextEditingController();
    final details = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DPSheetHandle(),
                  const SizedBox(height: 8),
                  const Text('File a Dispute', style: DP.title),
                  const SizedBox(height: 14),
                  DPCard(
                    color: DP.blueTint,
                    borderColor: null,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transaction Details',
                            style: DP.bodyStrong),
                        const SizedBox(height: 4),
                        Text('Ref: ${tx['id']}', style: DP.caption),
                        Text(
                          'Amount: ${DP.naira((tx['amount'] as num).toDouble())}',
                          style: DP.caption,
                        ),
                        Text(
                          'Date: ${mockDateTime(DateTime.parse(tx['createdAt'] as String))}',
                          style: DP.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const DPLabel('Dispute Type'),
                  DPSelectField(
                    value: type,
                    hint: 'Choose a type',
                    onTap: () async {
                      final v = await dpPickFromList<String>(
                        ctx,
                        title: 'Dispute Type',
                        items: _types,
                        selected: type,
                        labelOf: (x) => x,
                      );
                      if (v != null) setSheet(() => type = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  const DPLabel('Reason *'),
                  DPField(
                    controller: reason,
                    hint: 'Brief explanation of the issue',
                  ),
                  const SizedBox(height: 14),
                  const DPLabel('Detailed Description'),
                  DPField(
                    controller: details,
                    hint: 'Provide more details about what happened',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  const DPLabel('Upload Evidence (Optional)'),
                  DPCard(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    onTap: () => dpSnack(
                      ctx,
                      'Image picking isn\'t set up in this UI build',
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              color: DP.navyIcon, size: 30),
                          SizedBox(height: 6),
                          Text('Click to upload screenshot',
                              style: DP.bodyStrong),
                          SizedBox(height: 2),
                          Text('PNG, JPG, WEBP • Max 1MB',
                              style: DP.caption),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DPButton(
                    label: 'Submit Dispute',
                    onPressed: () {
                      if (reason.text.trim().isEmpty) {
                        dpSnack(ctx, 'Please enter a reason', error: true);
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() {
                        _disputes.insert(
                          0,
                          _Dispute(
                            tx['id'] as String,
                            tx['description'] as String,
                            (tx['amount'] as num).toDouble(),
                            type,
                            reason.text.trim(),
                            'pending',
                            Duration.zero,
                          ),
                        );
                        _tab = 0;
                      });
                      dpSnack(context, 'Dispute created successfully!',
                          success: true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(_Dispute d) {
    final s = _statusStyle(d.status);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 8),
              const Text('Dispute Details', style: DP.title),
              const SizedBox(height: 14),
              DPCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    DPSummaryRow('Status', s.$1, valueColor: s.$2),
                    DPSummaryRow('Amount', DP.naira(d.amount)),
                    DPSummaryRow('Type', d.type),
                    DPSummaryRow('Reason', d.reason),
                    DPSummaryRow('Transaction Ref', d.ref),
                    if (d.resolution != null)
                      DPSummaryRow('Resolution', d.resolution!),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              DPButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _disputes.where((d) => d.status != 'resolved' && d.status != 'rejected').length;
    final resolved = _disputes.where((d) => d.status == 'resolved').length;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'My Disputes'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _stat('Total', '${_disputes.length}', DP.navyIcon),
                      const SizedBox(width: 10),
                      _stat('Pending', '$pending', DP.amber),
                      const SizedBox(width: 10),
                      _stat('Resolved', '$resolved', DP.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DPSegmented(
                    options: const ['My Disputes', 'New Dispute'],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            Expanded(child: _tab == 0 ? _buildList() : _buildNew()),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: DPCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: DP.caption.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_disputes.isEmpty) {
      return const Center(
        child: DPEmptyState(
          icon: Icons.gavel_rounded,
          title: 'No disputes',
          message: 'If something went wrong with a payment, report it here.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _disputes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final d = _disputes[i];
        final s = _statusStyle(d.status);
        return DPCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          onTap: () => _openDetails(d),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(d.title, style: DP.bodyStrong)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.$1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: s.$2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(d.type, style: DP.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    DP.naira(d.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DP.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    mockTimeAgo(DateTime.now().subtract(d.ago)),
                    style: DP.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNew() {
    final debits = kMockTransactions.where((t) => !mockIsCredit(t)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Choose the payment you want to report.',
          style: DP.caption,
        ),
        const SizedBox(height: 10),
        for (final tx in debits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DPCard(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              onTap: () => _openNewDispute(tx),
              child: DPListRow(
                leading: DPIconBadge(
                  transactionIcon(tx['type'] as String),
                  size: 40,
                  iconSize: 19,
                  color: DP.red,
                  background: DP.redBg,
                ),
                title: tx['description'] as String,
                subtitle:
                    '${DP.naira((tx['amount'] as num).toDouble())} · ${DPStatus.labelFor(tx['status'] as String?)}',
                trailing: const DPTextLink(label: 'Dispute'),
              ),
            ),
          ),
      ],
    );
  }
}
