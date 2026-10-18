// lib/presentation/screens/admin/admin_control_page.dart
// Admin Control (RBAC, Super Admin): who has which staff role
// (GET/POST /api/admin/roles), add admins by email, activate/deactivate.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminControlPage extends StatefulWidget {
  const AdminControlPage({super.key});

  @override
  State<AdminControlPage> createState() => _AdminControlPageState();
}

class _AdminControlPageState extends State<AdminControlPage> {
  int _tab = 0;
  String _query = '';
  List<AdminUser> _admins = [];
  List<AdminUser> _users = [];
  int _regularCount = 0;
  bool _loading = true;
  Object? _error;
  Timer? _debounce;

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
    try {
      final r = asMap(await api.get('/api/admin/roles'));
      final u = await api.get('/api/admin/users',
          query: {'q': _query.trim(), 'limit': 50});
      if (!mounted) return;
      setState(() {
        _admins = asList(r['admins']).map(AdminUser.fromJson).toList();
        _regularCount = toInt(r['regularUsers']);
        _users = itemsOf(u).map(AdminUser.fromJson).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _setRole(AdminUser u, String role, BuildContext ctx) async {
    try {
      await api.post('/api/admin/roles', {'userId': u.id, 'role': role});
    } catch (e) {
      if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
      return;
    }
    if (ctx.mounted) Navigator.pop(ctx);
    if (!mounted) return;
    dpSnack(
      context,
      role == 'user'
          ? 'Admin access removed for ${u.name}'
          : '${u.name} is now ${roleLabel(role)}',
      success: true,
    );
    _load();
  }

  static const _roles = ['admin', 'finance', 'support', 'super'];

  static const _roleInfo = {
    'super': 'Full access to everything, including roles',
    'admin': 'Users, transactions, refunds and settings',
    'finance': 'Funding, refunds, verification and revenue',
    'support': 'View users and transactions, handle disputes',
  };

  void _manage(AdminUser u) {
    var role = u.isAdmin ? u.role : 'admin';
    final isMe = u.id == Session.instance.user?.id;
    showAdminSheet(
      context,
      title: 'User Details',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminUserRow(
            name: u.name,
            subtitle: u.email,
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
            onPressed: isMe || role == u.role ? null : () => _setRole(u, role, ctx),
          ),
          if (u.isAdmin && !isMe) ...[
            const SizedBox(height: 10),
            DPOutlineButton(
              label: 'Remove Admin Access',
              color: DP.red,
              onPressed: () => _setRole(u, 'user', ctx),
            ),
          ],
          const SizedBox(height: 10),
          DPOutlineButton(
            label: u.active ? 'Deactivate' : 'Activate',
            color: u.active ? DP.amber : DP.green,
            onPressed: isMe
                ? null
                : () async {
                    try {
                      await api.patch('/api/admin/users/${u.id}', {'isActive': !u.active});
                    } catch (e) {
                      if (ctx.mounted) dpSnack(ctx, errorMessage(e), error: true);
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
          ),
          if (isMe)
            const DPHelper('You can\'t change your own role or deactivate yourself'),
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
            onPressed: () async {
              final e = email.text.trim().toLowerCase();
              if (!e.contains('@')) {
                dpSnack(ctx, 'Please enter a valid email address', error: true);
                return;
              }
              List<AdminUser> match;
              try {
                final r = await api.get('/api/admin/users', query: {'q': e});
                match = itemsOf(r)
                    .map(AdminUser.fromJson)
                    .where((u) => u.email.toLowerCase() == e)
                    .toList();
              } catch (err) {
                if (ctx.mounted) dpSnack(ctx, errorMessage(err), error: true);
                return;
              }
              if (!ctx.mounted) return;
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
          Text('The person must already have a Dalabapay account.',
              style: DP.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final admins = _admins;
    final list = _tab == 0
        ? admins
            .where((u) =>
                q.isEmpty ||
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q))
            .toList()
        : _users;
    if (!adminCan('roles:manage')) {
      return const AdminScaffold(
        title: 'Admin Control',
        breadcrumb: 'Admin / Control',
        body: DPEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Super Admin only',
          message: 'Only a Super Admin can manage roles.',
        ),
      );
    }
    return AdminScaffold(
      title: 'Admin Control',
      breadcrumb: 'Admin / Control · RBAC - Manage roles & permissions',
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
                label: 'Admins',
                value: '${admins.length}',
                icon: Icons.admin_panel_settings_outlined,
                color: DP.navyInk,
              ),
              AdminStat(
                label: 'Regular Users',
                value: '$_regularCount',
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
            onChanged: (v) {
              setState(() => _query = v);
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _load);
            },
          ),
          const SizedBox(height: 14),
          if (_loading)
            const DPLoading()
          else if (_error != null && admins.isEmpty)
            DPLoadError(error: _error, onRetry: _load)
          else if (list.isEmpty)
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
      ),
    );
  }
}
