// lib/presentation/screens/admin/admin_fund_wallet_page.dart
// Fund Wallet: find a user (GET /api/admin/users) and credit their wallet
// as a manual deposit (POST /api/admin/users/:id/wallet).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminFundWalletPage extends StatefulWidget {
  const AdminFundWalletPage({super.key});

  @override
  State<AdminFundWalletPage> createState() => _AdminFundWalletPageState();
}

class _AdminFundWalletPageState extends State<AdminFundWalletPage> {
  String _query = '';
  String _filter = 'All';
  static const _filters = ['All', 'Active', 'Low Balance', 'Admins'];
  static const _filterValues = {
    'All': 'all',
    'Active': 'active',
    'Low Balance': 'low_balance',
    'Admins': 'admins',
  };

  List<AdminUser> _users = [];
  Map<String, dynamic> _totals = {};
  bool _loading = true;
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

  Future<void> _load() async {
    final id = ++_req;
    try {
      final r = asMap(await api.get('/api/admin/users', query: {
        'q': _query.trim(),
        'filter': _filterValues[_filter],
        'limit': 50,
      }));
      if (!mounted || id != _req) return;
      setState(() {
        _users = itemsOf(r).map(AdminUser.fromJson).toList();
        _totals = asMap(r['totals']);
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

  void _fund(AdminUser u) {
    final amount = TextEditingController();
    final note = TextEditingController();
    var saving = false;
    showAdminSheet(
      context,
      title: 'Fund Wallet',
      builder: (ctx, setSheet) {
        final a = double.tryParse(amount.text) ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DPAvatar(name: u.name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: DP.bodyStrong),
                      Text('Current Balance ${u.money(u.balance)}',
                          style: DP.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const DPLabel('Funding Amount'),
            DPField(
              controller: amount,
              hint: 'Enter amount (e.g., 1000.00)',
              prefixText: '₦  ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setSheet(() {}),
            ),
            const SizedBox(height: 10),
            Text('Quick Amounts', style: DP.caption),
            const SizedBox(height: 6),
            QuickAmounts(controller: amount, onChanged: () => setSheet(() {})),
            const SizedBox(height: 14),
            const DPLabel('Note (Optional)'),
            DPField(
              controller: note,
              hint: 'Add a note for this transaction...',
            ),
            const SizedBox(height: 14),
            DPCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: DPSummaryRow('New Balance', u.money(u.balance + a),
                  strong: true),
            ),
            const SizedBox(height: 18),
            DPButton(
              label: 'Confirm Funding',
              loading: saving,
              onPressed: a <= 0 || saving
                  ? null
                  : () async {
                      setSheet(() => saving = true);
                      try {
                        await api.post('/api/admin/users/${u.id}/wallet', {
                          'action': 'credit',
                          'amount': a,
                          'reason': 'Manual Deposit',
                          if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
                        });
                      } catch (e) {
                        setSheet(() => saving = false);
                        if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      dpSnack(context, 'Funded ${u.money(a)} · ${u.name}',
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
    final users = _users;
    final totalWallet = toDouble(_totals['walletBalance']);
    final totalCommission = toDouble(_totals['commissionBalance']);

    return AdminScaffold(
      title: 'Fund Wallet',
      breadcrumb: 'Admin / Fund Wallet',
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
                label: 'Total Wallet',
                value: DP.naira(totalWallet, decimals: false),
                icon: DPIcons.wallet,
                color: DP.green,
              ),
              AdminStat(
                label: 'Total Commission',
                value: DP.naira(totalCommission, decimals: false),
                icon: DPIcons.sparkle,
                color: DP.amber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSearch(
            hint: 'Search by name, email or phone...',
            onChanged: (v) {
              _query = v;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _load);
            },
          ),
          const SizedBox(height: 12),
          DPChipScroller(
            options: _filters,
            selected: _filter,
            onSelect: (f) {
              setState(() => _filter = f);
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (_loading)
            const DPLoading()
          else if (_error != null && users.isEmpty)
            DPLoadError(error: _error, onRetry: _load)
          else if (users.isEmpty)
            const DPEmptyState(
              icon: Icons.group_outlined,
              title: 'No Users Found',
              message: 'Try adjusting your search or filters',
            )
          else
            AdminListCard(
              children: [
                for (final u in users)
                  AdminUserRow(
                    name: u.name,
                    subtitle: '${u.email} · ${u.money(u.balance)}',
                    onTap: () => _fund(u),
                    trailing: SizedBox(
                      height: 34,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DP.green,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DP.rSm),
                          ),
                        ),
                        onPressed: () => _fund(u),
                        child: const Text('Fund'),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      ),
    );
  }
}
