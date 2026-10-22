// lib/presentation/screens/admin/admin_users_page.dart
// Manage Users: GET /api/admin/users with search and filters; approve,
// activate/deactivate, credit/debit wallet, edit and history.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_edit_user_page.dart';
import 'admin_models.dart';
import 'admin_user_history_page.dart';
import 'admin_widgets.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _query = '';
  String _filter = 'All Users';
  static const _filters = [
    'All Users',
    'Active',
    'Inactive',
    'Admins',
    'Awaiting Approval',
  ];

  static const _filterValues = {
    'All Users': 'all',
    'Active': 'active',
    'Inactive': 'inactive',
    'Admins': 'admins',
    'Awaiting Approval': 'pending',
  };

  List<AdminUser> _users = [];
  Map<String, dynamic> _counts = {};
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

  Future<void> _load({bool more = false}) async {
    final id = ++_req;
    if (!more && _users.isEmpty) setState(() => _loading = true);
    try {
      final r = asMap(await api.get('/api/admin/users', query: {
        'q': _query.trim(),
        'filter': _filterValues[_filter],
        'page': more ? _page + 1 : 1,
      }));
      if (!mounted || id != _req) return;
      final items = itemsOf(r).map(AdminUser.fromJson).toList();
      setState(() {
        _users = more ? [..._users, ...items] : items;
        _page = more ? _page + 1 : 1;
        _hasMore = r['hasMore'] == true;
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

  void _search(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<bool> _call(Future<dynamic> Function() f, String done) async {
    final r = await runWithFeedback(context, () async {
      await f();
      return true;
    }, success: done);
    if (r == true) _load();
    return r == true;
  }

  void _openUser(AdminUser u) {
    showAdminSheet(
      context,
      title: 'User Details',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DPAvatar(name: u.name, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u.name}  ${u.flag}', style: DP.bodyStrong),
                    Text(u.email, style: DP.caption),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        StatusPill(u.active ? 'Active' : 'Inactive'),
                        if (!u.approved) const StatusPill('Awaiting Approval'),
                        if (u.isAdmin) StatusPill(roleLabel(u.role)),
                        if (u.pinLocked) const StatusPill('PIN Locked'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                DPSummaryRow('User ID', u.id),
                DPSummaryRow('Phone', u.phone),
                DPSummaryRow('Wallet balance', u.money(u.balance), strong: true),
                DPSummaryRow('Commission', u.money(u.commission)),
                DPSummaryRow('KYC', u.kycStatus == 'none' ? 'Not started' : statusLabel(u.kycStatus)),
                DPSummaryRow('Payment PIN', u.pinLocked ? 'Locked' : (u.pinSet ? 'Set' : 'Not set')),
                DPSummaryRow('Joined', dateLabel(u.joined)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!u.approved && adminCan('users:approve')) ...[
            DPButton(
              label: 'Approve User',
              icon: DPIcons.checkCircle,
              onPressed: () {
                Navigator.pop(ctx);
                _call(() => api.post('/api/admin/users/${u.id}/approve'),
                    '${u.name} approved');
              },
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: DPOutlineButton(
                  label: 'Edit',
                  icon: DPIcons.edit,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminEditUserPage(user: u),
                      ),
                    ).then((_) => _load());
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DPOutlineButton(
                  label: 'History',
                  icon: DPIcons.history,
                  color: DP.navyIcon,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminUserHistoryPage(user: u),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (adminCan('wallet:fund')) ...[
          const SizedBox(height: 10),
          DPButton.mint(
            label: 'Credit / Debit Wallet',
            leadingIcon: DPIcons.wallet,
            onPressed: () {
              Navigator.pop(ctx);
              _creditDebit(u);
            },
          ),
          ],
          if (adminCan('users:write')) ...[
          const SizedBox(height: 10),
          DPOutlineButton(
            label: u.active ? 'Deactivate User' : 'Activate User',
            color: u.active ? DP.red : DP.green,
            icon: u.active ? Icons.block_rounded : DPIcons.checkCircle,
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await dpDialog(
                context,
                title: u.active ? 'Deactivate User' : 'Activate User',
                message: u.active
                    ? '${u.name} won\'t be able to log in or pay until reactivated.'
                    : '${u.name} will be able to log in and pay again.',
                confirmLabel: u.active ? 'Deactivate' : 'Activate',
                cancelLabel: 'Cancel',
                tone: u.active ? DPTone.error : DPTone.success,
                destructive: u.active,
              );
              if (ok == true && mounted) {
                _call(
                  () => api.patch('/api/admin/users/${u.id}', {'isActive': !u.active}),
                  u.active ? 'User deactivated' : 'User activated',
                );
              }
            },
          ),
          ],
        ],
      ),
    );
  }

  void _creditDebit(AdminUser u) {
    final amount = TextEditingController();
    final note = TextEditingController();
    var credit = true;
    var reason = 'Manual Deposit';
    var saving = false;
    const reasons = [
      'Manual Deposit',
      'Bonus / Goodwill',
      'Correcting undercharged amount',
      'Correcting overcharged amount',
      'Fraud / Suspicious Activity',
      'Custom Reason',
    ];
    showAdminSheet(
      context,
      title: 'Credit / Debit Wallet',
      builder: (ctx, setSheet) {
        final a = double.tryParse(amount.text) ?? 0;
        final after = credit ? u.balance + a : u.balance - a;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${u.name} · Balance ${u.money(u.balance)}',
                style: DP.caption),
            const SizedBox(height: 14),
            DPSegmented(
              options: const ['Credit', 'Debit'],
              index: credit ? 0 : 1,
              onChanged: (i) => setSheet(() => credit = i == 0),
            ),
            const SizedBox(height: 16),
            const DPLabel('Amount (₦)'),
            DPField(
              controller: amount,
              hint: '0.00',
              prefixText: '₦  ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setSheet(() {}),
            ),
            const SizedBox(height: 10),
            QuickAmounts(controller: amount, onChanged: () => setSheet(() {})),
            const SizedBox(height: 14),
            const DPLabel('Reason'),
            DPSelectField(
              value: reason,
              hint: 'Choose a reason',
              onTap: () async {
                final v = await dpPickFromList<String>(
                  ctx,
                  title: 'Reason',
                  items: reasons,
                  selected: reason,
                  labelOf: (x) => x,
                );
                if (v != null) setSheet(() => reason = v);
              },
            ),
            const SizedBox(height: 14),
            const DPLabel('Note (optional)'),
            DPField(controller: note, hint: 'Additional details...'),
            const SizedBox(height: 14),
            DPCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: DPSummaryRow(
                'New balance',
                u.money(after),
                strong: true,
                valueColor: after < 0 ? DP.red : null,
              ),
            ),
            const SizedBox(height: 18),
            DPButton(
              label: credit ? 'Credit Wallet' : 'Debit Wallet',
              background: credit ? DP.green : DP.red,
              loading: saving,
              onPressed: a <= 0 || after < 0 || saving
                  ? null
                  : () async {
                      setSheet(() => saving = true);
                      try {
                        await api.post('/api/admin/users/${u.id}/wallet', {
                          'action': credit ? 'credit' : 'debit',
                          'amount': a,
                          'reason': reason,
                          if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
                        });
                      } catch (e) {
                        setSheet(() => saving = false);
                        if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      dpSnack(
                        context,
                        '${credit ? 'Credited' : 'Debited'} ${u.money(a)} · ${u.name}',
                        success: true,
                      );
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
    final awaiting = toInt(_counts['pending']);
    return AdminScaffold(
      title: 'Manage Users',
      breadcrumb: 'Admin / Users',
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
                label: 'All Users',
                value: '${toInt(_counts['all'])}',
                icon: Icons.group_outlined,
              ),
              AdminStat(
                label: 'Active',
                value: '${toInt(_counts['active'])}',
                icon: DPIcons.checkCircle,
                color: DP.green,
              ),
              AdminStat(
                label: 'Admins',
                value: '${toInt(_counts['admins'])}',
                icon: Icons.admin_panel_settings_outlined,
                color: DP.navyInk,
              ),
              AdminStat(
                label: 'Awaiting Approval',
                value: '$awaiting',
                icon: DPIcons.pending,
                color: DP.amber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSearch(
            hint: 'Search by name, email, phone or ID...',
            onChanged: _search,
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
            const DPLoading.list(rows: 6, padding: 0)
          else if (_error != null && users.isEmpty)
            DPLoadError(error: _error, onRetry: _load)
          else if (users.isEmpty)
            const DPEmptyState(
              icon: Icons.group_outlined,
              title: 'No Users Found',
              message: 'Try adjusting your search or filters.',
            )
          else
            AdminListCard(
              children: [
                for (final u in users)
                  AdminUserRow(
                    name: u.name,
                    subtitle: '${u.flag} ${u.email} · ${u.phone}',
                    onTap: () => _openUser(u),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          u.money(u.balance, decimals: false),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DP.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        StatusPill(
                          !u.approved
                              ? 'Pending'
                              : (u.active ? 'Active' : 'Inactive'),
                        ),
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
