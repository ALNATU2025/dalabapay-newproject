// lib/presentation/screens/admin/admin_all_transactions_page.dart
// All Transactions: GET /api/admin/transactions with search, status,
// service and sort; details; CSV export (GET .../export.csv).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
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

  static const _statuses = ['All', 'Successful', 'Pending', 'Failed', 'Refunded', 'Disputed'];
  static const _sorts = ['Newest', 'Oldest', 'Highest Amount', 'Lowest Amount'];
  static const _sortValues = {
    'Newest': 'newest',
    'Oldest': 'oldest',
    'Highest Amount': 'highest',
    'Lowest Amount': 'lowest',
  };

  List<AdminTxn> _items = [];
  int _total = 0;
  double _totalAmount = 0;
  bool _loading = true;
  bool _hasMore = false;
  int _page = 1;
  Object? _error;
  Timer? _debounce;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _query0 => {
        'q': _query.trim(),
        'status': kStatusValues[_status],
        'service': _service == null ? null : kAdminServiceTypes[_service],
        'sort': _sortValues[_sort],
      };

  Future<void> _load({bool more = false}) async {
    final id = ++_req;
    if (!more && _items.isEmpty) setState(() => _loading = true);
    try {
      final r = asMap(await api.get('/api/admin/transactions',
          query: {..._query0, 'page': more ? _page + 1 : 1}));
      if (!mounted || id != _req) return;
      final list = itemsOf(r).map(AdminTxn.fromJson).toList();
      setState(() {
        _items = more ? [..._items, ...list] : list;
        _page = more ? _page + 1 : 1;
        _hasMore = r['hasMore'] == true;
        _total = toInt(r['total']);
        _totalAmount = toDouble(r['totalAmount']);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _req) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _search(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
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
              t.money(t.amount),
              style: TextStyle(
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
                if (t.json['recipient'] != null)
                  DPSummaryRow('Recipient', str(t.json['recipient'])),
                DPSummaryRow('Type', t.credit ? 'Credit' : 'Debit'),
                if (t.fee > 0) DPSummaryRow('Fee', t.money(t.fee)),
                if (toDouble(t.json['commission']) > 0)
                  DPSummaryRow('User commission', t.money(toDouble(t.json['commission']))),
                if (toDouble(t.json['platformRevenue']) > 0)
                  DPSummaryRow('Platform revenue', t.money(toDouble(t.json['platformRevenue']))),
                if (t.json['providerReference'] != null)
                  DPSummaryRow('Provider ref', str(t.json['providerReference'])),
                if (asMap(t.json['actor'])['fullName'] != null)
                  DPSummaryRow('Handled by', str(asMap(t.json['actor'])['fullName'])),
                DPSummaryRow('Date', dateTimeLabel(t.date)),
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

  Future<void> _exportCsv() async {
    dpSnack(context, 'Preparing export…');
    try {
      final csv = await api.getText('/api/admin/transactions/export.csv',
          query: _query0);
      final name = 'dalabapay-transactions-${isoDay(DateTime.now())}.csv';
      try {
        await Share.shareXFiles([
          XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: name),
        ], subject: name);
      } catch (_) {
        await Share.share(csv, subject: name);
      }
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  void _export() {
    if (!adminCan('transactions:export')) {
      dpSnack(context, 'Your role can\'t export transactions.', error: true);
      return;
    }
    showAdminSheet(
      context,
      title: 'Export Options',
      builder: (ctx, _) => Column(
        children: [
          DPMenuRow(
            icon: Icons.table_chart_outlined,
            title: 'Export as Excel / CSV',
            subtitle: 'Uses the filters on this page',
            onTap: () {
              Navigator.pop(ctx);
              _exportCsv();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = _totalAmount;
    return AdminScaffold(
      title: 'All Transactions',
      breadcrumb: 'Admin / Transactions',
      actions: [
        DPTextLink(label: 'Export', onTap: _export),
        const SizedBox(width: 8),
      ],
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
                label: 'Matching total',
                value: DP.naira(total, decimals: false),
                icon: Icons.payments_outlined,
                color: DP.green,
              ),
              AdminStat(
                label: 'Transactions',
                value: '$_total',
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSearch(
            hint: 'Search by name, email, ID, phone...',
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          DPChipScroller(
            options: _statuses,
            selected: _status,
            onSelect: (s) {
              setState(() => _status = s);
              _load();
            },
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
                      items: ['All Services', ...kAdminServiceTypes.keys],
                      selected: _service ?? 'All Services',
                      labelOf: (x) => x,
                    );
                    if (v != null) {
                      setState(() => _service = v == 'All Services' ? null : v);
                      _load();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DPSelectField(
                  value: _sort,
                  hint: 'Sort By',
                  leading: Icon(Icons.sort_rounded,
                      size: 20, color: DP.muted),
                  onTap: () async {
                    final v = await dpPickFromList<String>(
                      context,
                      title: 'Sort By',
                      items: _sorts,
                      selected: _sort,
                      labelOf: (x) => x,
                    );
                    if (v != null) {
                      setState(() => _sort = v);
                      _load();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const DPLoading.list(rows: 6, padding: 0)
          else if (_error != null && items.isEmpty)
            DPLoadError(error: _error, onRetry: _load)
          else if (items.isEmpty)
            DPEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Transactions Found',
              message: 'Try adjusting your filters or search.',
              actionLabel: 'Clear All Filters',
              onAction: () {
                setState(() {
                  _status = 'All';
                  _service = null;
                  _query = '';
                });
                _load();
              },
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
                    subtitle: '${t.description}\n${t.ref} · ${agoOf(t.date)}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          t.money(t.amount),
                          style: TextStyle(
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
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: DPTextLink(
                  label: 'Load more',
                  onTap: () => _load(more: true),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
