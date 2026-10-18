// lib/presentation/screens/admin/admin_refund_system_page.dart
// Refund & Dispute — UI only. Resolve disputes and process refunds.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminRefundSystemPage extends StatefulWidget {
  const AdminRefundSystemPage({super.key});

  @override
  State<AdminRefundSystemPage> createState() => _AdminRefundSystemPageState();
}

class _AdminRefundSystemPageState extends State<AdminRefundSystemPage> {
  int _tab = 0;

  List<AdminTxn> get _refundable => kAdminTxns
      .where((t) => t.status == 'Failed' || t.status == 'Pending')
      .where((t) => !t.credit)
      .toList();

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
                DPSummaryRow('Amount', DP.naira(d.amount), strong: true),
                DPSummaryRow('Evidence', d.hasEvidence ? 'Attached' : 'None'),
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
            onPressed: () {
              setState(() {
                d.status = 'resolved';
                d.resolution = notes.text.trim().isEmpty
                    ? 'Refunded ${DP.naira(d.amount)}'
                    : notes.text.trim();
              });
              Navigator.pop(ctx);
              dpSnack(context, 'Dispute approved and resolved', success: true);
            },
          ),
          const SizedBox(height: 10),
          DPOutlineButton(
            label: 'Reject Dispute',
            color: DP.red,
            icon: DPIcons.failed,
            onPressed: () {
              if (notes.text.trim().isEmpty) {
                dpSnack(ctx, 'Please enter resolution details', error: true);
                return;
              }
              setState(() {
                d.status = 'rejected';
                d.resolution = notes.text.trim();
              });
              Navigator.pop(ctx);
              dpSnack(context, 'Dispute rejected');
            },
          ),
        ],
      ),
    );
  }

  void _refund(AdminTxn t) {
    final amount = TextEditingController(text: t.amount.toStringAsFixed(0));
    final reason = TextEditingController();
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
              onPressed: a <= 0 || a > t.amount
                  ? null
                  : () {
                      setState(() => t.status = 'Refunded');
                      Navigator.pop(ctx);
                      dpSnack(context, 'Refunded ${DP.naira(a)} to ${t.userName}',
                          success: true);
                    },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = kAdminDisputes.where((d) => d.status == 'pending').toList();
    final closed = kAdminDisputes.where((d) => d.status != 'pending').toList();
    final refundable = _refundable;
    final refunded = kAdminTxns.where((t) => t.status == 'Refunded').toList();

    return AdminScaffold(
      title: 'Refund & Dispute',
      breadcrumb: 'Admin / Refund System',
      body: ListView(
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
    );
  }

  Widget _disputeCard(AdminDispute d) {
    final open = d.status == 'pending';
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
                if (d.hasEvidence) ...[
                  const StatusPill('HAS EVIDENCE', color: DP.navyIcon),
                  const SizedBox(width: 6),
                ],
                StatusPill(open
                    ? 'Pending'
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
                Text(adminAgo(d.hoursAgo * 60),
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
