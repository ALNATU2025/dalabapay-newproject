// lib/presentation/screens/admin/admin_edit_user_page.dart
// Edit User — UI only. Profile fields, account controls and PIN management.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminEditUserPage extends StatefulWidget {
  final AdminUser user;
  const AdminEditUserPage({super.key, required this.user});

  @override
  State<AdminEditUserPage> createState() => _AdminEditUserPageState();
}

class _AdminEditUserPageState extends State<AdminEditUserPage> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _balance =
      TextEditingController(text: widget.user.balance.toStringAsFixed(2));
  late bool _active = widget.user.active;
  late bool _admin = widget.user.isAdmin;
  late bool _pinLocked = widget.user.pinLocked;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _balance]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      dpSnack(context, 'Enter a full name and a valid email address',
          error: true);
      return;
    }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final u = widget.user
      ..name = _name.text.trim()
      ..email = _email.text.trim()
      ..phone = _phone.text.trim()
      ..balance = double.tryParse(_balance.text) ?? widget.user.balance
      ..active = _active
      ..pinLocked = _pinLocked;
    if (!_admin) u.role = 'user';
    if (_admin && u.role == 'user') u.role = 'admin';
    setState(() => _saving = false);
    dpSnack(context, 'User updated', success: true);
    Navigator.pop(context);
  }

  Widget _switch(String title, String sub, bool v, ValueChanged<bool> on,
      IconData icon) {
    return DPMenuRow(
      icon: icon,
      title: title,
      subtitle: sub,
      trailing: Switch(value: v, onChanged: on),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return AdminScaffold(
      title: 'Edit User Profile',
      breadcrumb: 'Admin / Users / Edit',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          const DPBanner(
            'Super Admin Mode - Full Edit Access',
            tone: DPTone.info,
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DPAvatar(name: u.name, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name, style: DP.bodyStrong),
                    Text('${u.id} · Joined ${adminAgo(u.joinedDaysAgo * 1440)}',
                        style: DP.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const DPSectionHeader('User Information'),
          const DPLabel('Full Name'),
          DPField(
            controller: _name,
            hint: 'Full name',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          const DPLabel('Email Address'),
          DPField(
            controller: _email,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          const DPLabel('Phone Number'),
          DPField(
            controller: _phone,
            hint: 'Phone',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
          ),
          const SizedBox(height: 14),
          const DPLabel('Wallet Balance (₦)'),
          DPField(
            controller: _balance,
            hint: 'Enter wallet balance',
            prefixText: '₦  ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('Account Controls'),
          DPCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _switch(
                  'Account Status',
                  _active
                      ? 'User can access the system'
                      : 'User account is disabled',
                  _active,
                  (v) => setState(() => _active = v),
                  DPIcons.user,
                ),
                const Divider(height: 1, color: DP.borderSoft),
                _switch(
                  'Admin Privileges',
                  _admin ? 'User has admin access' : 'User has regular access',
                  _admin,
                  (v) => setState(() => _admin = v),
                  Icons.admin_panel_settings_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const DPSectionHeader('PIN Management'),
          DPCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Lock Status', style: DP.body),
                    const Spacer(),
                    StatusPill(_pinLocked ? 'LOCKED' : 'UNLOCKED',
                        color: _pinLocked ? DP.red : DP.green),
                  ],
                ),
                if (_pinLocked) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Text('Lock Remaining', style: DP.caption),
                      Spacer(),
                      Text('24 min', style: DP.bodyStrong),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DPOutlineButton(
                        label: 'Unlock PIN',
                        icon: Icons.lock_open_rounded,
                        height: 46,
                        onPressed: _pinLocked
                            ? () {
                                setState(() => _pinLocked = false);
                                dpSnack(context, 'PIN unlocked',
                                    success: true);
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DPOutlineButton(
                        label: 'Reset PIN',
                        icon: DPIcons.refresh,
                        color: DP.amber,
                        height: 46,
                        onPressed: () async {
                          final ok = await dpDialog(
                            context,
                            title: 'Reset PIN?',
                            message:
                                'Reset ${u.name}\'s PIN to the default (123456). They\'ll be asked to change it.',
                            confirmLabel: 'Reset',
                            cancelLabel: 'Cancel',
                            tone: DPTone.warning,
                          );
                          if (ok == true && mounted) {
                            dpSnack(context, 'PIN reset to default',
                                success: true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: DPBottomAction(
        child: DPButton(
          label: _saving ? 'Saving...' : 'Save Changes',
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
