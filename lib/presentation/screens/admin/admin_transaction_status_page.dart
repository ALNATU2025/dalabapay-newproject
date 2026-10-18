// lib/presentation/screens/admin/admin_transaction_status_page.dart
// Status Update — UI only. Pick a transaction, change its status with a note.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminTransactionStatusPage extends StatefulWidget {
  const AdminTransactionStatusPage({super.key});

  @override
  State<AdminTransactionStatusPage> createState() =>
      _AdminTransactionStatusPageState();
}

class _AdminTransactionStatusPageState
    extends State<AdminTransactionStatusPage> {
  String _query = '';
  String _filter = 'All';
  static const _filters = ['All', 'Pending', 'Successful', 'Failed', 'Disputed'];
  static const _statuses = [
    'Pending',
    'Processing',
    'Successful',
    'Failed',
    'Refunded',
    'Disputed',
  ];

  void _change(AdminTxn t) {
    var next = t.status;
    final note = TextEditingController();
    showAdminSheet(
      context,
      title: 'Update Status',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                DPSummaryRow('Reference', t.ref),
                DPSummaryRow('Customer', t.userName),
                DPSummaryRow('Service', t.service),
                DPSummaryRow('Amount', DP.naira(t.amount), strong: true),
                DPSummaryRow(
                  'Current',
                  t.status,
                  valueColor: StatusPill.colorFor(t.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const DPLabel('Change to:'),
          DPChipGrid(
            options: _statuses,
            selected: next,
            columns: 3,
            height: 42,
            onSelect: (s) => setSheet(() => next = s),
          ),
          const SizedBox(height: 14),
          const DPLabel('Admin Note (Optional)'),
          DPField(
            controller: note,
            hint: 'Reason for status change',
            maxLines: 2,
          ),
          if (next == 'Refunded') ...[
            const SizedBox(height: 12),
            DPBanner(
              '${DP.naira(t.amount)} will be returned to ${t.userName}\'s wallet.',
              tone: DPTone.info,
              icon: DPIcons.info,
            ),
          ],
          const SizedBox(height: 18),
          DPButton(
            label: 'Confirm Status Change',
            onPressed: next == t.status
                ? null
                : () {
                    final old = t.status;
                    setState(() {
                      t.status = next;
                      if (note.text.trim().isNotEmpty) t.note = note.text.trim();
                    });
                    Navigator.pop(ctx);
                    dpSnack(context, '${t.ref}: $old → $next', success: true);
                  },
          ),
          if (t.status == 'Disputed') ...[
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Go to Refund System',
              icon: Icons.currency_exchange_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/admin/refunds');
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final items = kAdminTxns.where((t) {
      if (_filter != 'All' && t.status != _filter) return false;
      return q.isEmpty ||
          t.ref.toLowerCase().contains(q) ||
          t.userName.toLowerCase().contains(q) ||
          t.service.toLowerCase().contains(q);
    }).toList();
    int count(String s) => kAdminTxns.where((t) => t.status == s).length;

    return AdminScaffold(
      title: 'Status Update',
      breadcrumb: 'Admin / Status Update',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Pending',
                value: '${count('Pending')}',
                icon: DPIcons.pending,
                color: DP.amber,
              ),
              AdminStat(
                label: 'Disputes',
                value: '${count('Disputed')}',
                icon: Icons.gavel_rounded,
                color: DP.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSearch(
            hint: 'Search by reference, customer, type...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          DPChipScroller(
            options: _filters,
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 8),
          const Text('Tap on a transaction to change its status',
              style: DP.caption),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const DPEmptyState(
              icon: Icons.update_rounded,
              title: 'No Transactions Found',
              message: 'Try another filter.',
            )
          else
            AdminListCard(
              children: [
                for (final t in items)
                  DPListRow(
                    onTap: () => _change(t),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    leading: DPIconBadge(
                      Icons.receipt_long_outlined,
                      size: 40,
                      iconSize: 19,
                      color: StatusPill.colorFor(t.status),
                      background:
                          StatusPill.colorFor(t.status).withValues(alpha: 0.12),
                    ),
                    title: t.ref,
                    subtitle: '${t.userName} · ${t.service} · ${adminAgo(t.minutesAgo)}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DP.naira(t.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DP.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        StatusPill(t.status),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
