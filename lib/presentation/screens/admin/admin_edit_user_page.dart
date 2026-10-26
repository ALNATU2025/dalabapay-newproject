// lib/presentation/screens/admin/admin_edit_user_page.dart
// Edit User: profile fields and account status (PATCH /api/admin/users/:id)
// and PIN unlock / reset. The balance changes only through Credit / Debit
// Wallet, so every change is recorded.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'admin_models.dart';
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
  late bool _pinLocked = widget.user.pinLocked;
  late bool _pinSet = widget.user.pinSet;
  DateTime? _lockedUntil;
  bool _saving = false;
  bool _pinBusy = false;

  bool get _canEdit => adminCan('users:write');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final j = asMap(await api.get('/api/admin/users/${widget.user.id}'));
      if (!mounted) return;
      setState(() {
        _pinLocked = j['pinLocked'] == true;
        _pinSet = j['pinSet'] == true;
        _lockedUntil = j['pinLockedUntil'] == null ? null : parseDate(j['pinLockedUntil']);
        _balance.text = toDouble(j['balance']).toStringAsFixed(2);
      });
    } catch (_) {}
  }

  Future<void> _pinAction(String action, String done) async {
    setState(() => _pinBusy = true);
    try {
      final j = asMap(await api.post('/api/admin/users/${widget.user.id}/pin/$action'));
      if (!mounted) return;
      setState(() {
        _pinBusy = false;
        _pinLocked = j['pinLocked'] == true;
        _pinSet = j['pinSet'] == true;
        _lockedUntil = null;
      });
      dpSnack(context, done, success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pinBusy = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

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
    final u = widget.user;
    final body = <String, dynamic>{
      if (_name.text.trim() != u.name) 'fullName': _name.text.trim(),
      if (_email.text.trim().toLowerCase() != u.email) 'email': _email.text.trim().toLowerCase(),
      if (_phone.text.trim() != u.phone) 'phone': _phone.text.trim(),
      if (_active != u.active) 'isActive': _active,
    };
    if (body.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await api.patch('/api/admin/users/${u.id}', body);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    dpSnack(context, 'User updated', success: true);
    Navigator.pop(context, true);
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
          DPBanner(
            _canEdit
                ? 'You can edit this user\'s details. Every change is logged.'
                : 'View only — your role can\'t edit users.',
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
                    Text('${roleLabel(u.role)} · Joined ${dateLabel(u.joined)}',
                        style: DP.caption),
                    Text(
                      u.online
                          ? 'Online now'
                          : 'Last seen ${u.lastSeen == null ? 'never' : timeAgo(u.lastSeen!).toLowerCase()} · Last sign-in ${u.lastLogin == null ? 'never' : timeAgo(u.lastLogin!).toLowerCase()}',
                      style: DP.caption.copyWith(color: u.online ? DP.green : DP.muted),
                    ),
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
            hint: 'Wallet balance',
            prefixText: '₦  ',
            readOnly: true,
          ),
          const DPHelper('Use Credit / Debit Wallet on the user to change the balance.'),
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
                  (v) {
                    if (_canEdit) setState(() => _active = v);
                  },
                  DPIcons.user,
                ),
                Divider(height: 1, color: DP.borderSoft),
                DPMenuRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Role',
                  subtitle: 'Change roles in Admin Control (Super Admin)',
                  trailing: StatusPill(roleLabel(u.role)),
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
                    Text('Lock Status', style: DP.body),
                    const Spacer(),
                    StatusPill(
                        _pinLocked ? 'LOCKED' : (_pinSet ? 'UNLOCKED' : 'NOT SET'),
                        color: _pinLocked ? DP.red : (_pinSet ? DP.green : DP.amber)),
                  ],
                ),
                if (_pinLocked && _lockedUntil != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Lock Remaining', style: DP.caption),
                      const Spacer(),
                      Text(
                        '${_lockedUntil!.difference(DateTime.now()).inMinutes.clamp(0, 9999)} min',
                        style: DP.bodyStrong,
                      ),
                    ],
                  ),
                ],
                if (_pinBusy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(color: DP.green),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DPOutlineButton(
                        label: 'Unlock PIN',
                        icon: Icons.lock_open_rounded,
                        height: 46,
                        onPressed: _pinLocked && !_pinBusy && adminCan('users:pin')
                            ? () => _pinAction('unlock', 'PIN unlocked')
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
                        onPressed: !_pinSet || _pinBusy || !adminCan('users:pin')
                            ? null
                            : () async {
                          final ok = await dpDialog(
                            context,
                            title: 'Reset PIN?',
                            message:
                                'This removes ${u.name}\'s payment PIN. They\'ll create a new one before their next payment.',
                            confirmLabel: 'Reset',
                            cancelLabel: 'Cancel',
                            tone: DPTone.warning,
                          );
                          if (ok == true && mounted) {
                            _pinAction('reset', 'PIN reset — the user will create a new one');
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
          onPressed: _canEdit && !_saving ? _save : null,
        ),
      ),
    );
  }
}
