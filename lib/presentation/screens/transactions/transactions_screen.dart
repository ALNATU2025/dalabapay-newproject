// lib/presentation/screens/transactions/transactions_screen.dart
// "My Wallet" / Transactions tab: GET /api/transactions with status, type,
// date and search filters, loaded a page at a time.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/transaction_widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _balanceHidden = false;
  DateTimeRange? _range;

  static const _statusChips = ['All', 'Successful', 'Pending', 'Failed'];
  static const _typeChips = [
    'Airtime Purchase',
    'Data Purchase',
    'Cable TV Purchase',
    'Electricity Purchase',
    'Education Purchase',
    'Insurance Purchase',
    'Transfer',
    'Fund Wallet',
    'Commission Credit',
  ];

  /// Filter chip → API query.
  static const _statusQuery = {
    'Successful': 'success',
    'Pending': 'pending',
    'Failed': 'failed',
  };
  static const _typeQuery = {
    'Airtime Purchase': 'airtime,international',
    'Data Purchase': 'data',
    'Cable TV Purchase': 'cable',
    'Electricity Purchase': 'electricity',
    'Education Purchase': 'education',
    'Insurance Purchase': 'insurance',
    'Transfer': 'transfer_out,transfer_in',
    'Fund Wallet': 'wallet_funding',
    'Commission Credit': 'commission,commission_withdrawal,referral_bonus',
  };

  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    Session.instance.refreshQuietly();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _query(int page, {int limit = 20}) {
    final type = _typeQuery[_selectedFilter];
    return {
      'page': page,
      'limit': limit,
      'status': _statusQuery[_selectedFilter],
      'type': type,
      if (_selectedFilter == 'Commission Credit') 'wallet': 'all',
      'q': _searchController.text.trim(),
      if (_range != null) 'from': isoDay(_range!.start),
      if (_range != null) 'to': isoDay(_range!.end),
    };
  }

  Future<void> _reload() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = asMap(await api.get('/api/transactions', query: _query(1)));
      if (!mounted || id != _requestId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(itemsOf(r));
        _page = 1;
        _hasMore = r['hasMore'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final r = asMap(await api.get('/api/transactions', query: _query(_page + 1)));
      if (!mounted || id != _requestId) return;
      setState(() {
        _items.addAll(itemsOf(r));
        _page += 1;
        _hasMore = r['hasMore'] == true;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  void _setFilter(String f) {
    setState(() => _selectedFilter = f);
    _reload();
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _export() async {
    try {
      final r = await api.get('/api/transactions', query: _query(1, limit: 100));
      final rows = itemsOf(r);
      if (rows.isEmpty) {
        if (mounted) dpSnack(context, 'Nothing to export');
        return;
      }
      String esc(Object? v) => '"${'${v ?? ''}'.replaceAll('"', '""')}"';
      final b = StringBuffer('Date,Reference,Description,Type,Status,Amount,Direction\n');
      for (final t in rows) {
        b.writeln([
          dateTimeLabel(parseDate(t['createdAt'])),
          t['reference'],
          t['description'],
          transactionTypeLabel(str(t['type'])),
          DPStatus.labelFor(str(t['status'])),
          toDouble(t['amount']).toStringAsFixed(2),
          t['direction'],
        ].map(esc).join(','));
      }
      await Share.share(b.toString(), subject: 'Dalabapay transactions');
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) {
      setState(() => _range = r);
      _reload();
    }
  }

  void _onNavTap(int i) {
    if (i == 1) return;
    Navigator.of(context).maybePop(
      const ['home', 'transactions', 'services', 'profile'][i],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DPTopBar(
              title: 'My Wallet',
              actionLabel: 'Export',
              onAction: _export,
            ),
            Expanded(
              child: RefreshIndicator(
                color: DP.green,
                onRefresh: () async {
                  await Session.instance.refreshQuietly();
                  await _reload();
                },
                child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                    _loadMore();
                  }
                  return false;
                },
                child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DPAppear(scaleFrom: 0.97, child: _buildBalanceCard()),
                          const SizedBox(height: 22),
                          const DPSectionHeader('Recent Transactions'),
                          _buildSearchAndFilters(),
                        ],
                      ),
                    ),
                  ),
                  if (_loading && items.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: DPSkeletonList(rows: 6, card: false),
                      ),
                    )
                  else if (_error != null && items.isEmpty)
                    SliverToBoxAdapter(
                      child: DPLoadError(error: _error, onRetry: _reload),
                    )
                  else if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: DPEmptyState(
                          icon: DPIcons.receipt,
                          title: 'No matching transactions',
                          message: 'Try a different search or filter.',
                          actionLabel: 'Clear filters',
                          onAction: () {
                            setState(() {
                              _selectedFilter = 'All';
                              _searchController.clear();
                              _range = null;
                            });
                            _reload();
                          },
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final day = parseDate(items[i]['createdAt']);
                            final newDay = i == 0 ||
                                !sameDay(day, parseDate(items[i - 1]['createdAt']));
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (newDay)
                                  TransactionDayHeader(day)
                                else
                                  Divider(height: 1, color: DP.borderSoft),
                                TransactionRow(tx: items[i], detailed: true),
                              ],
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(child: DPLoading(padding: 16)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Only completed payments affect your balance.',
                        textAlign: TextAlign.center,
                        style: DP.caption,
                      ),
                    ),
                  ),
                ],
              ),
              ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DPBottomNav(
        index: 1,
        items: kDPTabs,
        onCenter: () => Navigator.pushNamed(context, '/send-money').then((_) {
          if (mounted) _reload();
        }),
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildBalanceCard() {
    const balanceStyle = TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: DP.greenGradient,
        borderRadius: BorderRadius.circular(DP.rXl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33079A68),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Wallet Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              InkResponse(
                radius: 20,
                onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _balanceHidden ? DPIcons.eyeOff : DPIcons.eye,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _balanceHidden
                    ? Text('${DP.currencySymbol} ••••••', style: balanceStyle)
                    : ValueListenableBuilder(
                        valueListenable: Session.instance,
                        builder: (context, user, _) => DPCountUp(
                          value: user?.balance ?? 0,
                          format: (v) => DP.naira(v),
                          style: balanceStyle,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DPButton(
                  label: 'Add Money',
                  leadingIcon: DPIcons.plus,
                  height: 46,
                  background: Colors.white,
                  foreground: DP.green,
                  onPressed: () => Navigator.pushNamed(context, '/wallet').then((_) {
          if (mounted) _reload();
        }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DPButton(
                  label: 'Send Money',
                  leadingIcon: DPIcons.upRight,
                  height: 46,
                  background: DP.blue,
                  onPressed: () => Navigator.pushNamed(context, '/send-money').then((_) {
          if (mounted) _reload();
        }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    String fmt(DateTime d) {
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => _onSearchChanged(),
          textInputAction: TextInputAction.search,
          decoration: DPField.decoration(
            hint: 'Search name or reference',
            prefix: const Icon(DPIcons.search, size: 20),
            suffix: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(DPIcons.close),
                    onPressed: () {
                      setState(_searchController.clear);
                      _reload();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        DPChipRow(
          options: _statusChips,
          selected:
              _statusChips.contains(_selectedFilter) ? _selectedFilter : null,
          spacing: 8,
          height: 40,
          onSelect: _setFilter,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in _typeChips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DPChip(
                          label: f
                              .replaceAll(' Purchase', '')
                              .replaceAll(' Credit', ''),
                          selected: _selectedFilter == f,
                          height: 36,
                          onTap: () =>
                              _setFilter(_selectedFilter == f ? 'All' : f),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            DPIconSquare(
              icon: DPIcons.calendar,
              size: 36,
              color: _range != null ? DP.green : DP.ink,
              semanticLabel: 'Filter by date',
              onTap: _selectDateRange,
            ),
          ],
        ),
        if (_range != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fmt(_range!.start)} – ${fmt(_range!.end)}',
                  style: DP.caption,
                ),
              ),
              DPTextLink(
                label: 'Clear dates',
                onTap: () {
                  setState(() => _range = null);
                  _reload();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
