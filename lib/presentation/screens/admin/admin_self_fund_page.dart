// lib/presentation/screens/admin/admin_self_fund_page.dart
// Self Fund (Super Admin): top up your own wallet, confirmed with your
// payment PIN (GET/POST /api/admin/payments/self-fund).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminSelfFundPage extends StatefulWidget {
  const AdminSelfFundPage({super.key});

  @override
  State<AdminSelfFundPage> createState() => _AdminSelfFundPageState();
}

class _AdminSelfFundPageState extends State<AdminSelfFundPage> {
  final _amount = TextEditingController();
  double _balance = 0;
  List<Map<String, dynamic>> _history = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = asMap(await api.get('/api/admin/payments/self-fund'));
      if (!mounted) return;
      setState(() {
        _balance = toDouble(r['balance']);
        _history = asList(r['history']);
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    final a = double.tryParse(_amount.text) ?? 0;
    if (a <= 0) {
      dpSnack(context, 'Please enter an amount', error: true);
      return;
    }
    if (a > 1000000) {
      dpSnack(context, 'Amount cannot exceed ₦1,000,000', error: true);
      return;
    }
    final pin = TextEditingController();
    var saving = false;
    String? pinError;
    showAdminSheet(
      context,
      title: 'Enter Transaction PIN',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Please enter your 6-digit PIN to confirm funding ${DP.naira(a)}.',
            style: DP.body.copyWith(color: DP.muted),
          ),
          const SizedBox(height: 16),
          DPCodeInput(
            controller: pin,
            length: 6,
            autofocus: true,
            error: pinError != null,
            onChanged: (_) => setSheet(() {}),
          ),
          if (pinError != null)
            DPHelper(pinError!, color: DP.red, icon: DPIcons.alert),
          const SizedBox(height: 18),
          DPButton(
            label: 'Confirm',
            loading: saving,
            onPressed: pin.text.length < 6 || saving
                ? null
                : () async {
                    setSheet(() {
                      saving = true;
                      pinError = null;
                    });
                    Map<String, dynamic> r;
                    try {
                      r = asMap(await api.post('/api/admin/payments/self-fund',
                          {'amount': a, 'pin': pin.text}));
                    } catch (e) {
                      pin.clear();
                      setSheet(() {
                        saving = false;
                        pinError = errorMessage(e);
                      });
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    _amount.clear();
                    await _load();
                    Session.instance.refreshQuietly();
                    if (!mounted) return;
                    dpDialog(
                      context,
                      title: 'Success',
                      message:
                          '${DP.naira(a)} added. New Balance: ${DP.naira(toDouble(r['balance']))}',
                      confirmLabel: 'Done',
                    );
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Self Fund',
      breadcrumb: 'Admin / Self Fund',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: DP.navyGradient,
              borderRadius: BorderRadius.circular(DP.rXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(DPIcons.wallet, color: Color(0xCCFFFFFF), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Admin Wallet · Available Balance',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DPCountUp(
                  value: _balance,
                  format: (v) => DP.naira(v),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fund your admin wallet instantly',
                  style: TextStyle(color: Color(0xFF7FE3BC), fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const DPLabel('Amount to Fund'),
          DPField(
            controller: _amount,
            hint: 'Enter amount (e.g., 5000.00)',
            prefixText: '₦  ',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const DPHelper('Maximum ₦1,000,000 per top-up'),
          const SizedBox(height: 10),
          QuickAmounts(
            controller: _amount,
            amounts: const [10000, 50000, 100000, 500000],
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 18),
          DPButton(
            label: 'Fund Wallet',
            icon: DPIcons.lock,
            onPressed: _confirm,
          ),
          const SizedBox(height: 24),
          const DPSectionHeader('Recent Self-Funding'),
          if (_loaded && _history.isEmpty)
            const DPEmptyState(icon: DPIcons.wallet, title: 'No self-funding yet'),
          if (_history.isNotEmpty)
          AdminListCard(
            children: [
              for (final h in _history)
                DPListRow(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: const DPIconBadge(DPIcons.downLeft,
                      size: 40, iconSize: 19),
                  title: 'Self-Funding',
                  subtitle: '${agoOf(parseDate(h['createdAt']))} · ${str(h['reference'])}',
                  trailing: Text(
                    '+${DP.naira(toDouble(h['amount']))}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DP.green,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
