// lib/presentation/screens/transactions/transactions_screen.dart
// "My Wallet" / Transactions tab — UI only, filters the sample list.
import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return kMockTransactions.where((tx) {
      final status = DPStatus.labelFor(tx['status'] as String?);
      final type = transactionTypeLabel(tx['type'] as String);
      final date = DateTime.parse(tx['createdAt'] as String);
      if (_statusChips.contains(_selectedFilter) &&
          _selectedFilter != 'All' &&
          status != _selectedFilter) {
        return false;
      }
      if (_typeChips.contains(_selectedFilter) && type != _selectedFilter) {
        return false;
      }
      if (_range != null &&
          (date.isBefore(_range!.start) ||
              date.isAfter(_range!.end.add(const Duration(days: 1))))) {
        return false;
      }
      if (q.isNotEmpty &&
          !(tx['description'] as String).toLowerCase().contains(q) &&
          !(tx['id'] as String).toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  void _onNavTap(int i) {
    if (i == 1) return;
    Navigator.of(context).maybePop(
      const ['home', 'transactions', 'services', 'profile'][i],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DPTopBar(
              title: 'My Wallet',
              actionLabel: 'Export',
              onAction: () =>
                  dpSnack(context, 'CSV export isn\'t set up in this UI build'),
            ),
            Expanded(
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
                  if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: DPEmptyState(
                          icon: DPIcons.receipt,
                          title: 'No matching transactions',
                          message: 'Try a different search or filter.',
                          actionLabel: 'Clear filters',
                          onAction: () => setState(() {
                            _selectedFilter = 'All';
                            _searchController.clear();
                            _range = null;
                          }),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Column(
                            children: [
                              if (i > 0)
                                Divider(
                                    height: 1, color: DP.borderSoft),
                              TransactionRow(tx: items[i], detailed: true),
                            ],
                          ),
                          childCount: items.length,
                        ),
                      ),
                    ),
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
          ],
        ),
      ),
      bottomNavigationBar: DPBottomNav(
        index: 1,
        items: kDPTabs,
        onCenter: () => Navigator.pushNamed(context, '/send-money'),
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
                    ? const Text('₦ ••••••', style: balanceStyle)
                    : DPCountUp(
                        value: MockUser.walletBalance,
                        format: (v) => DP.naira(v),
                        style: balanceStyle,
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
                  onPressed: () => Navigator.pushNamed(context, '/wallet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DPButton(
                  label: 'Send Money',
                  leadingIcon: DPIcons.upRight,
                  height: 46,
                  background: DP.blue,
                  onPressed: () => Navigator.pushNamed(context, '/send-money'),
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
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: DPField.decoration(
            hint: 'Search name or reference',
            prefix: const Icon(DPIcons.search, size: 20),
            suffix: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(DPIcons.close),
                    onPressed: () => setState(_searchController.clear),
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
          onSelect: (f) => setState(() => _selectedFilter = f),
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
                          onTap: () => setState(() {
                            _selectedFilter =
                                _selectedFilter == f ? 'All' : f;
                          }),
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
                onTap: () => setState(() => _range = null),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
