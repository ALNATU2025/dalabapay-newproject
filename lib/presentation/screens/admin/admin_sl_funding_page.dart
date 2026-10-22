// lib/presentation/screens/admin/admin_sl_funding_page.dart
// Sierra Leone settings: the accounts customers pay into (Orange Money,
// Afrimoney, bank), top-up limits and referral bonuses — all in Leones.
//   GET   /api/admin/settings
//   PATCH /api/admin/settings { slFunding, slReferral }
// Customers' "I've paid" requests then appear in Status Update as pending
// top-ups to approve.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminSlFundingPage extends StatefulWidget {
  const AdminSlFundingPage({super.key});

  @override
  State<AdminSlFundingPage> createState() => _AdminSlFundingPageState();
}

class _Method {
  final String id;
  final String name;
  final bool bank;
  final TextEditingController account = TextEditingController();
  final TextEditingController accountName = TextEditingController();
  final TextEditingController bankName = TextEditingController();
  _Method(this.id, this.name, {this.bank = false});
}

class _AdminSlFundingPageState extends State<AdminSlFundingPage> {
  final _methods = [
    _Method('orange', 'Orange Money'),
    _Method('afrimoney', 'Afrimoney'),
    _Method('bank', 'Bank transfer', bank: true),
  ];
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _instructions = TextEditingController();
  final _bonus = TextEditingController();
  final _indirect = TextEditingController();
  final _minDeposit = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final m in _methods) {
      m.account.dispose();
      m.accountName.dispose();
      m.bankName.dispose();
    }
    for (final c in [_min, _max, _instructions, _bonus, _indirect, _minDeposit]) {
      c.dispose();
    }
    super.dispose();
  }

  String _n(dynamic v) {
    final d = toDouble(v);
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  Future<Map<String, dynamic>> _load() async {
    final s = asMap(await api.get('/api/admin/settings'));
    if (!_loaded) {
      final f = asMap(s['slFunding']);
      for (final saved in asList(f['methods'])) {
        for (final m in _methods) {
          if (m.id == saved['id']) {
            m.account.text = str(saved['account']);
            m.accountName.text = str(saved['accountName']);
            m.bankName.text = str(saved['bankName']);
          }
        }
      }
      _min.text = _n(f['minAmount']);
      _max.text = _n(f['maxAmount']);
      _instructions.text = str(f['instructions']);
      final r = asMap(s['slReferral']);
      _bonus.text = _n(r['bonus']);
      _indirect.text = _n(r['indirectBonus']);
      _minDeposit.text = _n(r['minFirstDeposit']);
      _loaded = true;
    }
    return s;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => api.patch('/api/admin/settings', {
        'slFunding': {
          'minAmount': double.tryParse(_min.text) ?? 0,
          'maxAmount': double.tryParse(_max.text) ?? 0,
          'instructions': _instructions.text.trim(),
          'methods': [
            for (final m in _methods)
              {
                'id': m.id,
                'name': m.name,
                'account': m.account.text.trim(),
                'accountName': m.accountName.text.trim(),
                if (m.bank) 'bankName': m.bankName.text.trim(),
              },
          ],
        },
        'slReferral': {
          'bonus': double.tryParse(_bonus.text) ?? 0,
          'indirectBonus': double.tryParse(_indirect.text) ?? 0,
          'minFirstDeposit': double.tryParse(_minDeposit.text) ?? 0,
        },
      }),
      success: 'Sierra Leone settings saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _num(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DPLabel(label),
            DPField(
              controller: c,
              prefixText: 'Le ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final canEdit = adminCan('settings:write');
    return AdminScaffold(
      title: 'Sierra Leone',
      breadcrumb: 'Admin / Sierra Leone',
      body: AsyncView<Map<String, dynamic>>(
        load: _load,
        builder: (context, _, __) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            const DPBanner(
              'Customers pay into these accounts, then tap "I\'ve paid". Their requests appear in Status Update as pending top-ups — approve each one after you see the money arrive. Leave an account empty to hide it.',
              tone: DPTone.info,
              icon: DPIcons.info,
            ),
            const SizedBox(height: 18),
            const DPSectionHeader('Payment accounts'),
            for (final m in _methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DPCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: DP.section),
                      const SizedBox(height: 10),
                      DPField(
                        controller: m.account,
                        hint: m.bank ? 'Account number' : 'Mobile money number',
                        keyboardType: TextInputType.number,
                        enabled: canEdit,
                      ),
                      const SizedBox(height: 8),
                      DPField(controller: m.accountName, hint: 'Account name', enabled: canEdit),
                      if (m.bank) ...[
                        const SizedBox(height: 8),
                        DPField(controller: m.bankName, hint: 'Bank name', enabled: canEdit),
                      ],
                    ],
                  ),
                ),
              ),
            const DPLabel('Instructions shown to customers'),
            DPField(controller: _instructions, maxLines: 3, enabled: canEdit),
            const SizedBox(height: 18),
            const DPSectionHeader('Top-up limits'),
            _num('Minimum top-up', _min),
            _num('Maximum top-up', _max),
            const SizedBox(height: 6),
            const DPSectionHeader('Referral bonuses'),
            _num('Bonus to referrer and new user (0 = off)', _bonus),
            _num('Indirect bonus', _indirect),
            _num('First deposit needed', _minDeposit),
            const SizedBox(height: 8),
            if (canEdit) DPButton(label: 'Save', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
