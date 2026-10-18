// lib/presentation/screens/admin/admin_control_page.dart
// Admin Control (RBAC) — UI only. Add admins, change roles, activate.
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminControlPage extends StatefulWidget {
  const AdminControlPage({super.key});

  @override
  State<AdminControlPage> createState() => _AdminControlPageState();
}

class _AdminControlPageState extends State<AdminControlPage> {
  int _tab = 0;
  String _query = '';

  static const _roles = ['admin', 'finance', 'support', 'super'];

  static const _roleInfo = {
    'super': 'Full access to everything, including roles',
    'admin': 'Users, transactions, refunds and settings',
    'finance': 'Funding, refunds, verification and revenue',
    'support': 'View users and transactions, handle disputes',
  };

  void _manage(AdminUser u) {
    var role = u.isAdmin ? u.role : 'admin';
    showAdminSheet(
      context,
      title: 'User Details',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminUserRow(
            name: u.name,
            subtitle: '${u.email} · ${u.id}',
            trailing: StatusPill(u.active ? 'Active' : 'Inactive'),
          ),
          const SizedBox(height: 12),
          const DPLabel('Role'),
          for (final r in _roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DPCard(
                color: role == r ? DP.mint : DP.surface,
                borderColor: role == r ? DP.green : DP.border,
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                onTap: () => setSheet(() => role = r),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(roleLabel(r), style: DP.bodyStrong),
                          Text(_roleInfo[r]!, style: DP.caption),
                        ],
                      ),
                    ),
                    Icon(
                      role == r
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: DP.green,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          DPButton(
            label: u.isAdmin ? 'Save Role' : 'Make ${roleLabel(role)}',
            onPressed: () {
              setState(() => u.role = role);
              Navigator.pop(ctx);
              dpSnack(context, '${u.name} is now ${roleLabel(role)}',
                  success: true);
            },
          ),
          if (u.isAdmin && u.role != 'super') ...[
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Remove Admin Access',
              color: DP.red,
              onPressed: () {
                setState(() => u.role = 'user');
                Navigator.pop(ctx);
                dpSnack(context, 'Admin access removed for ${u.name}');
              },
            ),
          ],
          const SizedBox(height: 10),
          DPOutlineButton(
            label: u.active ? 'Deactivate' : 'Activate',
            color: u.active ? DP.amber : DP.green,
            onPressed: u.role == 'super'
                ? null
                : () {
                    setState(() => u.active = !u.active);
                    Navigator.pop(ctx);
                  },
          ),
          if (u.role == 'super')
            const DPHelper('You cannot deactivate your own account'),
        ],
      ),
    );
  }

  void _addByEmail() {
    final email = TextEditingController();
    showAdminSheet(
      context,
      title: 'Add User as Admin',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DPLabel('By Email Address'),
          DPField(
            controller: email,
            hint: 'Enter user email',
            keyboardType: TextInputType.emailAddress,
            prefix: const Icon(DPIcons.mail, size: 20),
          ),
          const SizedBox(height: 16),
          DPButton(
            label: 'Find User',
            onPressed: () {
              final e = email.text.trim().toLowerCase();
              if (!e.contains('@')) {
                dpSnack(ctx, 'Please enter a valid email address', error: true);
                return;
              }
              final match =
                  kAdminUsers.where((u) => u.email.toLowerCase() == e);
              if (match.isEmpty) {
                dpSnack(ctx, 'User with this email not found', error: true);
                return;
              }
              final u = match.first;
              if (u.isAdmin) {
                dpSnack(ctx, 'This user is already an admin', error: true);
                return;
              }
              Navigator.pop(ctx);
              _manage(u);
            },
          ),
          const SizedBox(height: 8),
          Text('Try: chidi.eze@example.com', style: DP.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final admins = kAdminUsers.where((u) => u.isAdmin).toList();
    final regular = kAdminUsers.where((u) => !u.isAdmin).toList();
    final list = (_tab == 0 ? admins : regular)
        .where((u) =>
            q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
    return AdminScaffold(
      title: 'Admin Control',
      breadcrumb: 'Admin / Control · RBAC - Manage roles & permissions',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Admins',
                value: '${admins.length}',
                icon: Icons.admin_panel_settings_outlined,
                color: DP.navyInk,
              ),
              AdminStat(
                label: 'Regular Users',
                value: '${regular.length}',
                icon: Icons.group_outlined,
                color: DP.green,
              ),
            ],
          ),
          const SizedBox(height: 14),
          DPButton.mint(
            label: 'Add User as Admin',
            leadingIcon: Icons.person_add_alt_1_rounded,
            onPressed: _addByEmail,
          ),
          const SizedBox(height: 16),
          DPSegmented(
            options: const ['Admins', 'All Users'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          AdminSearch(
            hint: 'Search users...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            DPEmptyState(
              icon: Icons.group_outlined,
              title: _tab == 0 ? 'No Admin Users' : 'No users found',
            )
          else
            AdminListCard(
              children: [
                for (final u in list)
                  AdminUserRow(
                    name: u.name,
                    subtitle: u.email,
                    onTap: () => _manage(u),
                    trailing: StatusPill(
                      u.isAdmin ? roleLabel(u.role) : 'USER',
                      color: switch (u.role) {
                        'super' => DP.green,
                        'finance' => DP.amber,
                        'support' => DP.navyIcon,
                        'admin' => DP.navy,
                        _ => DP.muted,
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
