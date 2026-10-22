// lib/presentation/screens/admin/admin_transaction_status_page.dart
// Status Update: pick a transaction and change its status with a note
// (PATCH /api/admin/transactions/:id/status). Failing or refunding a payment
// returns the money; approving a pending top-up credits the wallet. Pending
// bill payments can be re-checked with the provider.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
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
    'Successful',
    'Failed',
    'Refunded',
    'Disputed',
  ];
  static const _billTypes = {
    'airtime', 'data', 'electricity', 'cable', 'education', 'insurance', 'international',
  };

  List<AdminTxn> _items = [];
  Map<String, dynamic> _counts = {};
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
      final r = asMap(await api.get('/api/admin/transactions', query: {
        'q': _query.trim(),
        'status': kStatusValues[_filter],
        'limit': 60,
      }));
      if (!mounted || id != _req) return;
      setState(() {
        _items = itemsOf(r).map(AdminTxn.fromJson).toList();
        _counts = asMap(r['counts']);
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

  Future<void> _requery(AdminTxn t) async {
    final r = await runWithFeedback(
        context, () => api.post('/api/admin/transactions/${t.id}/requery'));
    if (r == null || !mounted) return;
    final res = str(asMap(r)['result']);
    dpSnack(
      context,
      res == 'success'
          ? 'Provider confirmed it — marked successful'
          : res == 'failed'
              ? 'Provider says it failed — the user was refunded'
              : 'Still pending at the provider',
      success: res == 'success',
    );
    _load();
  }

  void _change(AdminTxn t) {
    var next = t.status;
    var saving = false;
    final note = TextEditingController();
    final isFunding = t.type == 'wallet_funding';
    final options = isFunding
        ? const ['Pending', 'Successful', 'Failed']
        : _statuses;
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
                DPSummaryRow('Amount', t.money(t.amount), strong: true),
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
            options: options,
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
          if (!isFunding && (next == 'Refunded' || next == 'Failed') && !t.refunded) ...[
            const SizedBox(height: 12),
            DPBanner(
              '${t.money(t.amount)} will be returned to ${t.userName}\'s wallet.',
              tone: DPTone.info,
              icon: DPIcons.info,
            ),
          ],
          if (isFunding && next == 'Successful') ...[
            const SizedBox(height: 12),
            DPBanner(
              '${t.money(t.amount)} will be added to ${t.userName}\'s wallet. Only do this once the money has arrived.',
              tone: DPTone.warning,
              icon: DPIcons.info,
            ),
          ],
          const SizedBox(height: 18),
          DPButton(
            label: 'Confirm Status Change',
            loading: saving,
            onPressed: next == t.status || saving
                ? null
                : () async {
                    final old = t.status;
                    setSheet(() => saving = true);
                    try {
                      await api.patch('/api/admin/transactions/${t.id}/status', {
                        'status': kStatusValues[next],
                        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
                      });
                    } catch (e) {
                      setSheet(() => saving = false);
                      if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    dpSnack(context, '${t.ref}: $old → $next', success: true);
                    _load();
                  },
          ),
          if (t.status == 'Pending' && _billTypes.contains(t.type)) ...[
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Check with provider',
              icon: DPIcons.refresh,
              onPressed: () {
                Navigator.pop(ctx);
                _requery(t);
              },
            ),
          ],
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
    final items = _items;
    int count(String s) => toInt(_counts[kStatusValues[s]]);

    return AdminScaffold(
      title: 'Status Update',
      breadcrumb: 'Admin / Status Update',
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
          const SizedBox(height: 8),
          Text('Tap on a transaction to change its status',
              style: DP.caption),
          const SizedBox(height: 10),
          if (_loading)
            const DPLoading()
          else if (_error != null && items.isEmpty)
            DPLoadError(error: _error, onRetry: _load)
          else if (items.isEmpty)
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
                    subtitle: '${t.userName} · ${t.service} · ${agoOf(t.date)}',
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
        ],
      ),
      ),
    );
  }
}
