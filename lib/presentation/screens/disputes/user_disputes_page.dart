// lib/presentation/screens/disputes/user_disputes_page.dart
// My Disputes: GET /api/disputes, and filing one against a recent payment
// (GET /api/disputes/eligible → POST /api/disputes). Opening this page with
// a transaction id as the route argument jumps straight to filing it.
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/transaction_widgets.dart';

class _Dispute {
  final String id;
  final String ref;
  final String title;
  final double amount;
  final String type;
  final String reason;
  final String status; // pending, investigating, resolved, rejected
  final DateTime date;
  final String? resolution;
  _Dispute(Map<String, dynamic> j)
      : id = str(j['id']),
        ref = str(asMap(j['transaction'])['reference']),
        title = str(asMap(j['transaction'])['description'], 'Payment'),
        amount = toDouble(asMap(j['transaction'])['amount']),
        type = _UserDisputesPageState.typeLabel(str(j['type'])),
        reason = str(j['reason']),
        status = str(j['status']),
        date = parseDate(j['createdAt']),
        resolution = (j['resolution'] == null || str(j['resolution']).isEmpty)
            ? null
            : str(j['resolution']);
}

class UserDisputesPage extends StatefulWidget {
  const UserDisputesPage({super.key});

  @override
  State<UserDisputesPage> createState() => _UserDisputesPageState();
}

class _UserDisputesPageState extends State<UserDisputesPage> {
  int _tab = 0;
  final List<_Dispute> _disputes = [];
  List<Map<String, dynamic>> _eligible = [];
  bool _loading = true;
  Object? _error;
  bool _openedFromArgs = false;

  /// API value → label.
  static const _types = {
    'service_not_delivered': 'Service not delivered',
    'incorrect_amount': 'Incorrect amount',
    'failed_transaction': 'Failed transaction',
    'pending_transaction': 'Pending transaction',
    'refund_request': 'Refund request',
    'other': 'Other',
  };

  static String typeLabel(String v) => _types[v] ?? 'Other';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.get('/api/disputes'),
        api.get('/api/disputes/eligible'),
      ]);
      if (!mounted) return;
      setState(() {
        _disputes
          ..clear()
          ..addAll(itemsOf(results[0]).map(_Dispute.new));
        _eligible = asList(results[1]);
        _loading = false;
        _error = null;
      });
      _openFromArgs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  /// "Report an issue" on a receipt passes the transaction id.
  void _openFromArgs() {
    if (_openedFromArgs) return;
    _openedFromArgs = true;
    final id = ModalRoute.of(context)?.settings.arguments?.toString();
    if (id == null || id.isEmpty) return;
    final tx = _eligible.where((t) => t['id'] == id).toList();
    if (tx.isNotEmpty) {
      setState(() => _tab = 1);
      _openNewDispute(tx.first);
    } else {
      dpSnack(context,
          'This payment can\'t be disputed (it may be refunded or already under review).');
    }
  }

  (String, Color) _statusStyle(String s) => switch (s) {
        'pending' => ('Pending Review', DP.amber),
        'investigating' => ('Investigating', DP.navyIcon),
        'resolved' => ('Resolved ✓', DP.green),
        'rejected' => ('Rejected ✗', DP.red),
        _ => ('Under Review', DP.amber),
      };

  void _openNewDispute(Map<String, dynamic> tx) {
    String type = _types.keys.first;
    bool submitting = false;
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
                  Text('File a Dispute', style: DP.title),
                  const SizedBox(height: 14),
                  DPCard(
                    color: DP.blueTint,
                    borderColor: null,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transaction Details',
                            style: DP.bodyStrong),
                        const SizedBox(height: 4),
                        Text(str(tx['description']), style: DP.caption),
                        Text('Ref: ${tx['reference']}', style: DP.caption),
                        Text(
                          'Amount: ${DP.naira(toDouble(tx['amount']))}',
                          style: DP.caption,
                        ),
                        Text(
                          'Date: ${dateTimeLabel(parseDate(tx['createdAt']))}',
                          style: DP.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const DPLabel('Dispute Type'),
                  DPSelectField(
                    value: _types[type],
                    hint: 'Choose a type',
                    onTap: () async {
                      final v = await dpPickFromList<String>(
                        ctx,
                        title: 'Dispute Type',
                        items: _types.keys.toList(),
                        selected: type,
                        labelOf: (x) => _types[x]!,
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
                  const SizedBox(height: 20),
                  DPButton(
                    label: 'Submit Dispute',
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            if (reason.text.trim().length < 3) {
                              dpSnack(ctx, 'Please enter a reason', error: true);
                              return;
                            }
                            setSheet(() => submitting = true);
                            try {
                              await api.post('/api/disputes', {
                                'transactionId': tx['id'],
                                'type': type,
                                'reason': reason.text.trim(),
                                if (details.text.trim().isNotEmpty)
                                  'description': details.text.trim(),
                              });
                            } catch (e) {
                              setSheet(() => submitting = false);
                              if (ctx.mounted) {
                                dpSnack(ctx, errorMessage(e), error: true);
                              }
                              return;
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!mounted) return;
                            setState(() => _tab = 0);
                            dpSnack(context, 'Dispute created successfully!',
                                success: true);
                            _load();
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
              Text('Dispute Details', style: DP.title),
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
                    DPSummaryRow('Opened', dateTimeLabel(d.date)),
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
    final pending = _disputes
        .where((d) => d.status != 'resolved' && d.status != 'rejected')
        .length;
    final resolved = _disputes.where((d) => d.status == 'resolved').length;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: _loading
            ? const Column(children: [DPTopBar(title: 'My Disputes'), Expanded(child: DPLoading())])
            : _error != null && _disputes.isEmpty
            ? Column(children: [
                const DPTopBar(title: 'My Disputes'),
                Expanded(child: DPLoadError(error: _error, onRetry: _load)),
              ])
            : Column(
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
    return RefreshIndicator(
      color: DP.green,
      onRefresh: _load,
      child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DP.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo(d.date),
                    style: DP.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _buildNew() {
    final debits = _eligible;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Choose the payment you want to report.',
          style: DP.caption,
        ),
        const SizedBox(height: 10),
        if (debits.isEmpty)
          const DPEmptyState(
            icon: DPIcons.receipt,
            title: 'No payments to report',
            message: 'Payments from the last 90 days show here.',
          ),
        for (final tx in debits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DPCard(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              onTap: () => _openNewDispute(tx),
              child: DPListRow(
                leading: DPIconBadge(
                  transactionIcon(str(tx['type'])),
                  size: 40,
                  iconSize: 19,
                  color: DP.red,
                  background: DP.redBg,
                ),
                title: str(tx['description'], transactionTypeLabel(str(tx['type']))),
                subtitle:
                    '${DP.naira(toDouble(tx['amount']))} · ${DPStatus.labelFor(tx['status'] as String?)} · ${timeAgo(parseDate(tx['createdAt']))}',
                trailing: const DPTextLink(label: 'Dispute'),
              ),
            ),
          ),
      ],
    );
  }
}
