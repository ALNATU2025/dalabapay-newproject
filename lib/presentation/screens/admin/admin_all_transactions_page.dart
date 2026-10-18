// lib/presentation/screens/admin/admin_all_transactions_page.dart
// All Transactions — UI only. Search, filter, sort, details and export.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminAllTransactionsPage extends StatefulWidget {
  const AdminAllTransactionsPage({super.key});

  @override
  State<AdminAllTransactionsPage> createState() =>
      _AdminAllTransactionsPageState();
}

class _AdminAllTransactionsPageState extends State<AdminAllTransactionsPage> {
  String _query = '';
  String _status = 'All';
  String? _service;
  String _sort = 'Newest';

  static const _statuses = ['All', 'Successful', 'Pending', 'Failed', 'Refunded'];
  static const _sorts = ['Newest', 'Oldest', 'Highest Amount', 'Lowest Amount'];

  List<AdminTxn> get _items {
    final q = _query.toLowerCase();
    final list = kAdminTxns.where((t) {
      if (_status != 'All' && t.status != _status) return false;
      if (_service != null && t.service != _service) return false;
      return q.isEmpty ||
          t.userName.toLowerCase().contains(q) ||
          t.userEmail.toLowerCase().contains(q) ||
          t.ref.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case 'Oldest':
        list.sort((a, b) => b.minutesAgo.compareTo(a.minutesAgo));
        break;
      case 'Highest Amount':
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Lowest Amount':
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      default:
        list.sort((a, b) => a.minutesAgo.compareTo(b.minutesAgo));
    }
    return list;
  }

  void _details(AdminTxn t) {
    showAdminSheet(
      context,
      title: 'Transaction Details',
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              DP.naira(t.amount),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: DP.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: StatusPill(t.status)),
          const SizedBox(height: 16),
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                DPSummaryRow('Reference', t.ref),
                DPSummaryRow('User', t.userName),
                DPSummaryRow('Email', t.userEmail),
                DPSummaryRow('Service', t.service),
                DPSummaryRow('Description', t.description),
                DPSummaryRow('Type', t.credit ? 'Credit' : 'Debit'),
                DPSummaryRow('Date', adminAgo(t.minutesAgo)),
                if (t.note != null) DPSummaryRow('Admin Note', t.note!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DPButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _export() {
    showAdminSheet(
      context,
      title: 'Export Options',
      builder: (ctx, _) => Column(
        children: [
          DPMenuRow(
            icon: Icons.table_chart_outlined,
            title: 'Export as Excel',
            subtitle: 'Download in Excel/CSV format',
            onTap: () {
              Navigator.pop(ctx);
              dpSnack(context, 'Export isn\'t set up in this UI build');
            },
          ),
          DPMenuRow(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export as PDF',
            subtitle: 'Download all as PDF report',
            onTap: () {
              Navigator.pop(ctx);
              dpSnack(context, 'Export isn\'t set up in this UI build');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = items.fold<double>(0, (a, t) => a + t.amount);
    return AdminScaffold(
      title: 'All Transactions',
      breadcrumb: 'Admin / Transactions',
      actions: [
        DPTextLink(label: 'Export', onTap: _export),
        const SizedBox(width: 8),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Showing total',
                value: DP.naira(total, decimals: false),
                icon: Icons.payments_outlined,
                color: DP.green,
              ),
              AdminStat(
                label: 'Transactions',
                value: '${items.length}',
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSearch(
            hint: 'Search by name, email, ID, phone...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          DPChipScroller(
            options: _statuses,
            selected: _status,
            onSelect: (s) => setState(() => _status = s),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DPSelectField(
                  value: _service ?? 'All Services',
                  hint: 'Service',
                  onTap: () async {
                    final v = await dpPickFromList<String>(
                      context,
                      title: 'Service',
                      items: ['All Services', ...kAdminServices, 'Fund Wallet', 'Commission'],
                      selected: _service ?? 'All Services',
                      labelOf: (x) => x,
                    );
                    if (v != null) {
                      setState(() => _service = v == 'All Services' ? null : v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DPSelectField(
                  value: _sort,
                  hint: 'Sort By',
                  leading: const Icon(Icons.sort_rounded,
                      size: 20, color: DP.muted),
                  onTap: () async {
                    final v = await dpPickFromList<String>(
                      context,
                      title: 'Sort By',
                      items: _sorts,
                      selected: _sort,
                      labelOf: (x) => x,
                    );
                    if (v != null) setState(() => _sort = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            DPEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Transactions Found',
              message: 'Try adjusting your filters or search.',
              actionLabel: 'Clear All Filters',
              onAction: () => setState(() {
                _status = 'All';
                _service = null;
                _query = '';
              }),
            )
          else
            AdminListCard(
              children: [
                for (final t in items)
                  DPListRow(
                    onTap: () => _details(t),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    subtitleMaxLines: 2,
                    leading: DPIconBadge(
                      t.credit ? DPIcons.downLeft : DPIcons.upRight,
                      size: 40,
                      iconSize: 19,
                      color: t.credit ? DP.green : DP.navyIcon,
                      background: t.credit ? DP.mint : DP.blueTint,
                    ),
                    title: '${t.userName} · ${t.service}',
                    subtitle: '${t.description}\n${t.ref} · ${adminAgo(t.minutesAgo)}',
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
