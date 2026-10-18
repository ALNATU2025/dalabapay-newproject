// lib/presentation/screens/admin/admin_users_page.dart
// Manage Users — UI only. Search, filter, approve, activate, credit/debit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import 'admin_edit_user_page.dart';
import 'admin_mock.dart';
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

  List<AdminUser> get _users {
    final q = _query.toLowerCase();
    return kAdminUsers.where((u) {
      final f = switch (_filter) {
        'Active' => u.active,
        'Inactive' => !u.active,
        'Admins' => u.isAdmin,
        'Awaiting Approval' => !u.approved,
        _ => true,
      };
      return f &&
          (q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.phone.contains(q) ||
              u.id.toLowerCase().contains(q));
    }).toList();
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
                    Text(u.name, style: DP.bodyStrong),
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
                DPSummaryRow('Wallet balance', DP.naira(u.balance), strong: true),
                DPSummaryRow('Commission', DP.naira(u.commission)),
                DPSummaryRow('Transactions', '${u.transactions}'),
                DPSummaryRow('Joined', adminAgo(u.joinedDaysAgo * 1440)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!u.approved) ...[
            DPButton(
              label: 'Approve User',
              icon: DPIcons.checkCircle,
              onPressed: () {
                setState(() => u.approved = true);
                Navigator.pop(ctx);
                dpSnack(context, '${u.name} approved', success: true);
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
                    ).then((_) => setState(() {}));
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
          const SizedBox(height: 10),
          DPButton.mint(
            label: 'Credit / Debit Wallet',
            leadingIcon: DPIcons.wallet,
            onPressed: () {
              Navigator.pop(ctx);
              _creditDebit(u);
            },
          ),
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
                setState(() => u.active = !u.active);
                dpSnack(
                  context,
                  u.active ? 'User activated' : 'User deactivated',
                  success: true,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _creditDebit(AdminUser u) {
    final amount = TextEditingController();
    final note = TextEditingController();
    var credit = true;
    var reason = 'Manual Deposit';
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
            Text('${u.name} · Balance ${DP.naira(u.balance)}',
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
                DP.naira(after),
                strong: true,
                valueColor: after < 0 ? DP.red : null,
              ),
            ),
            const SizedBox(height: 18),
            DPButton(
              label: credit ? 'Credit Wallet' : 'Debit Wallet',
              background: credit ? DP.green : DP.red,
              onPressed: a <= 0 || after < 0
                  ? null
                  : () {
                      setState(() => u.balance = after);
                      Navigator.pop(ctx);
                      dpSnack(
                        context,
                        '${credit ? 'Credited' : 'Debited'} ${DP.naira(a)} · ${u.name}',
                        success: true,
                      );
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
    final awaiting = kAdminUsers.where((u) => !u.approved).length;
    return AdminScaffold(
      title: 'Manage Users',
      breadcrumb: 'Admin / Users',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'All Users',
                value: '${kAdminUsers.length}',
                icon: Icons.group_outlined,
              ),
              AdminStat(
                label: 'Active',
                value: '${kAdminUsers.where((u) => u.active).length}',
                icon: DPIcons.checkCircle,
                color: DP.green,
              ),
              AdminStat(
                label: 'Admins',
                value: '${kAdminUsers.where((u) => u.isAdmin).length}',
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
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          DPChipScroller(
            options: _filters,
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 14),
          if (users.isEmpty)
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
                    subtitle: '${u.email} · ${u.phone}',
                    onTap: () => _openUser(u),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DP.naira(u.balance, decimals: false),
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
        ],
      ),
    );
  }
}
