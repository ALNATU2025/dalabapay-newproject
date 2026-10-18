// lib/presentation/screens/admin/admin_refund_system_page.dart
// Refund & Dispute: resolve user disputes (GET/POST /api/admin/disputes)
// and refund pending or disputed payments
// (GET /api/admin/transactions/refund-queue, POST .../:id/refund).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminRefundSystemPage extends StatefulWidget {
  const AdminRefundSystemPage({super.key});

  @override
  State<AdminRefundSystemPage> createState() => _AdminRefundSystemPageState();
}

class _AdminRefundSystemPageState extends State<AdminRefundSystemPage> {
  int _tab = 0;
  List<AdminDispute> _disputes = [];
  List<AdminTxn> _queue = [];
  List<AdminTxn> _refundedList = [];
  bool _loading = true;
  Object? _error;

  bool get _canRefund => adminCan('refunds:process');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = asMap(await api.get('/api/admin/disputes', query: {'status': 'all'}));
      Map<String, dynamic> q = {};
      if (_canRefund) {
        q = asMap(await api.get('/api/admin/transactions/refund-queue'));
      }
      if (!mounted) return;
      setState(() {
        _disputes = itemsOf(d).map(AdminDispute.fromJson).toList();
        _queue = asList(q['queue']).map(AdminTxn.fromJson).toList();
        _refundedList = asList(q['refunded']).map(AdminTxn.fromJson).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _resolveCall(AdminDispute d, String action, String resolution,
      BuildContext ctx) async {
    try {
      await api.post('/api/admin/disputes/${d.id}/resolve', {
        'action': action,
        'resolution': resolution,
      });
    } catch (e) {
      if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
      return;
    }
    if (ctx.mounted) Navigator.pop(ctx);
    if (!mounted) return;
    dpSnack(context,
        action == 'approve' ? 'Dispute approved and refunded' : 'Dispute rejected',
        success: action == 'approve');
    _load();
  }

  void _resolve(AdminDispute d) {
    final notes = TextEditingController();
    showAdminSheet(
      context,
      title: 'Resolve Dispute',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                DPSummaryRow('Reference', d.ref),
                DPSummaryRow('Customer', d.user),
                DPSummaryRow('Dispute Type', d.type),
                DPSummaryRow('Reason', d.reason),
                if (d.description.isNotEmpty)
                  DPSummaryRow('Details', d.description),
                DPSummaryRow('Amount', DP.naira(d.amount), strong: true),
                DPSummaryRow('Opened', dateTimeLabel(d.date)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const DPLabel('Resolution'),
          DPField(
            controller: notes,
            hint: 'Enter resolution details',
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          DPButton(
            label: 'Approve & Refund ${DP.naira(d.amount)}',
            onPressed: () => _resolveCall(
              d,
              'approve',
              notes.text.trim().length < 3
                  ? 'Refunded ${DP.naira(d.amount)} to your wallet'
                  : notes.text.trim(),
              ctx,
            ),
          ),
          const SizedBox(height: 10),
          DPOutlineButton(
            label: 'Reject Dispute',
            color: DP.red,
            icon: DPIcons.failed,
            onPressed: () {
              if (notes.text.trim().length < 3) {
                dpSnack(ctx, 'Please enter resolution details', error: true);
                return;
              }
              _resolveCall(d, 'reject', notes.text.trim(), ctx);
            },
          ),
        ],
      ),
    );
  }

  void _refund(AdminTxn t) {
    final amount = TextEditingController(text: t.amount.toStringAsFixed(0));
    final reason = TextEditingController();
    var saving = false;
    showAdminSheet(
      context,
      title: 'Process Refund',
      builder: (ctx, setSheet) {
        final a = double.tryParse(amount.text) ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DPCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  DPSummaryRow('Reference', t.ref),
                  DPSummaryRow('Customer', t.userName),
                  DPSummaryRow('Service', t.description),
                  DPSummaryRow('Status', t.status,
                      valueColor: StatusPill.colorFor(t.status)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const DPLabel('Refund Amount'),
            DPField(
              controller: amount,
              prefixText: '₦  ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setSheet(() {}),
            ),
            const SizedBox(height: 14),
            const DPLabel('Reason'),
            DPField(controller: reason, hint: 'Additional notes (optional)'),
            const SizedBox(height: 18),
            DPButton(
              label: 'Refund ${DP.naira(a)}',
              loading: saving,
              onPressed: a <= 0 || a > t.amount || saving
                  ? null
                  : () async {
                      setSheet(() => saving = true);
                      try {
                        await api.post('/api/admin/transactions/${t.id}/refund', {
                          'amount': a,
                          if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim(),
                        });
                      } catch (e) {
                        setSheet(() => saving = false);
                        if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      dpSnack(context, 'Refunded ${DP.naira(a)} to ${t.userName}',
                          success: true);
                      _load();
                    },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = _disputes.where((d) => d.open).toList();
    final closed = _disputes.where((d) => !d.open).toList();
    final refundable = _queue;
    final refunded = _refundedList;

    if (_loading) {
      return const AdminScaffold(
        title: 'Refund & Dispute',
        breadcrumb: 'Admin / Refund System',
        body: DPLoading(),
      );
    }
    if (_error != null && _disputes.isEmpty) {
      return AdminScaffold(
        title: 'Refund & Dispute',
        breadcrumb: 'Admin / Refund System',
        body: DPLoadError(error: _error, onRetry: _load),
      );
    }

    return AdminScaffold(
      title: 'Refund & Dispute',
      breadcrumb: 'Admin / Refund System',
      body: RefreshIndicator(
        color: DP.green,
        onRefresh: _load,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Open Disputes',
                value: '${open.length}',
                icon: Icons.gavel_rounded,
                color: DP.red,
              ),
              AdminStat(
                label: 'Pending Txs',
                value: '${refundable.length}',
                icon: DPIcons.pending,
                color: DP.amber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_canRefund)
            DPSegmented(
              options: const ['Disputes', 'Refund Queue', 'Refunded'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          const SizedBox(height: 14),
          if (_tab == 0) ...[
            if (open.isEmpty)
              const DPEmptyState(
                icon: Icons.gavel_rounded,
                title: 'No Disputes Found',
                message: 'All disputes have been resolved',
              )
            else
              for (final d in open) _disputeCard(d),
            if (closed.isNotEmpty) ...[
              const SizedBox(height: 10),
              const DPSectionHeader('Resolved'),
              for (final d in closed) _disputeCard(d),
            ],
          ] else if (_tab == 1) ...[
            if (refundable.isEmpty)
              const DPEmptyState(
                icon: Icons.currency_exchange_rounded,
                title: 'No Refunds Found',
                message: 'All refunds have been processed',
              )
            else
              AdminListCard(
                children: [
                  for (final t in refundable)
                    DPListRow(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      leading: DPAvatar(name: t.userName, size: 40),
                      title: t.description,
                      subtitle: '${t.userName} · ${t.ref}',
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(DP.naira(t.amount),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: DP.ink)),
                          const SizedBox(height: 3),
                          StatusPill(t.status),
                          const SizedBox(height: 3),
                          DPTextLink(
                            label: 'Refund',
                            fontSize: 13,
                            onTap: () => _refund(t),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ] else ...[
            if (refunded.isEmpty)
              const DPEmptyState(
                icon: Icons.currency_exchange_rounded,
                title: 'Nothing refunded yet',
              )
            else
              AdminListCard(
                children: [
                  for (final t in refunded)
                    DPListRow(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      leading: DPAvatar(name: t.userName, size: 40),
                      title: t.description,
                      subtitle: '${t.userName} · ${t.ref}',
                      trailing: const StatusPill('Refunded'),
                    ),
                ],
              ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _disputeCard(AdminDispute d) {
    final open = d.open;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DPCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: open ? () => _resolve(d) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(d.user, style: DP.bodyStrong)),
                StatusPill(open
                    ? (d.status == 'investigating' ? 'Under Review' : 'Pending')
                    : (d.status == 'resolved' ? 'Resolved' : 'Rejected')),
              ],
            ),
            const SizedBox(height: 4),
            Text('${d.type} · ${d.ref}', style: DP.caption),
            const SizedBox(height: 6),
            Text(d.reason, style: DP.body.copyWith(fontSize: 14)),
            if (d.resolution != null) ...[
              const SizedBox(height: 6),
              Text('Resolution: ${d.resolution}',
                  style: DP.caption.copyWith(color: DP.green)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  DP.naira(d.amount),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: DP.ink),
                ),
                const Spacer(),
                Text(agoOf(d.date),
                    style: DP.caption.copyWith(fontSize: 12)),
                if (open) ...[
                  const SizedBox(width: 10),
                  DPTextLink(
                    label: 'Resolve',
                    fontSize: 13,
                    onTap: () => _resolve(d),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
