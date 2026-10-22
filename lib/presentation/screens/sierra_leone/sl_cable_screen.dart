// lib/presentation/screens/sierra_leone/sl_cable_screen.dart
// DStv / GOtv / StarTimes in Sierra Leone: provider → smartcard → verify
// (details shown) → package → amount to pay → review.
//   GET  /api/services/sl/cable/providers | /api/services/sl/cable/plans?provider=
//   POST /api/services/sl/cable/verify    { provider, smartcardNumber }
//   POST /api/services/sl/cable           { provider, smartcardNumber, planCode, pin }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';
import 'sl_common.dart';

class SlCableScreen extends StatefulWidget {
  const SlCableScreen({super.key});

  @override
  State<SlCableScreen> createState() => _SlCableScreenState();
}

class _SlCableScreenState extends State<SlCableScreen> with SlAvailability {
  final _card = TextEditingController();
  List<Map<String, dynamic>> _providers = const [
    {'id': 'dstv', 'name': 'DStv'},
    {'id': 'gotv', 'name': 'GOtv'},
    {'id': 'startimes', 'name': 'StarTimes'},
  ];
  String _provider = 'dstv';
  Map<String, dynamic>? _customer;
  bool _verifying = false;
  List<Plan> _plans = [];
  bool _plansLoading = false;
  Object? _plansError;
  Plan? _plan;

  @override
  void initState() {
    super.initState();
    checkAvailability('sl_cable');
    _loadProviders();
  }

  @override
  void dispose() {
    _card.dispose();
    super.dispose();
  }

  String get _providerName =>
      str(_providers.firstWhere((p) => p['id'] == _provider, orElse: () => {'name': _provider})['name']);

  Future<void> _loadProviders() async {
    try {
      final list = asList(await api.get('/api/services/sl/cable/providers'));
      if (list.isNotEmpty && mounted) setState(() => _providers = list);
    } catch (_) {}
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _plansLoading = true;
      _plansError = null;
    });
    try {
      final r = await api.get('/api/services/sl/cable/plans', query: {'provider': _provider});
      if (!mounted) return;
      setState(() {
        _plans = Plan.listFrom(r);
        _plansLoading = false;
        _preselect();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plansError = e;
        _plansLoading = false;
      });
    }
  }

  /// After verifying, the customer's current package is chosen so the
  /// amount to pay shows straight away.
  void _preselect() {
    final code = _customer?['currentPlanCode'];
    if (code == null) return;
    for (final p in _plans) {
      if (p.code == code) _plan = p;
    }
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);
    try {
      final r = asMap(await api.post('/api/services/sl/cable/verify', {
        'provider': _provider,
        'smartcardNumber': _card.text.trim(),
      }));
      if (!mounted) return;
      setState(() {
        _customer = r;
        _verifying = false;
        _preselect();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  void _review() {
    if (_customer == null || _plan == null) {
      dpSnack(context, _customer == null ? 'Verify the smartcard number first' : 'Choose a package', error: true);
      return;
    }
    final plan = _plan!;
    final card = _card.text.trim();
    showReviewAndPay(
      context,
      icon: DPIcons.tv,
      title: '$_providerName subscription',
      serviceLabel: '$_providerName · ${plan.name}',
      amount: plan.price,
      service: 'sl_cable',
      rows: [
        DPReviewRow('Provider', _providerName),
        DPReviewRow('Smartcard / IUC', card),
        DPReviewRow('Customer', str(_customer!['customerName'])),
        DPReviewRow('Package', plan.name),
        DPReviewRow('Total to pay', DP.naira(plan.price), strong: true),
      ],
      footnote: 'Subscriptions can\'t be reversed once activated.',
      onPay: (pin) async {
        final r = await api.post('/api/services/sl/cable', {
          'provider': _provider,
          'smartcardNumber': card,
          'planCode': plan.code,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _card.text.trim().length >= 6 && !_verifying;
    final c = _customer;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Cable TV',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPHeadline('Your shows, right on time.', subtitle: 'Renew DStv, GOtv or StarTimes in Leones.'),
                    if (!slConnected) const SlComingSoon('Cable TV'),
                    const SectionTitle('TV provider'),
                    DPChipRow(
                      options: [for (final p in _providers) str(p['name'])],
                      selected: _providerName,
                      height: 46,
                      logos: true,
                      onSelect: (name) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _provider = str(_providers.firstWhere((p) => p['name'] == name)['id']);
                          _customer = null;
                          _plan = null;
                        });
                        _loadPlans();
                      },
                    ),
                    const SizedBox(height: 20),
                    DPLabel(
                      'Smartcard / IUC number',
                      trailing: c != null
                          ? null
                          : DPTextLink(
                              label: _verifying ? 'Checking…' : 'Verify',
                              color: canVerify ? DP.green : DP.faint,
                              onTap: canVerify ? _verify : null,
                            ),
                    ),
                    DPField(
                      controller: _card,
                      hint: 'Smartcard / IUC number',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(14),
                      ],
                      onChanged: (_) => setState(() {
                        _customer = null;
                      }),
                      suffix: Icon(
                        c != null ? DPIcons.checkCircle : DPIcons.scan,
                        color: c != null ? DP.green : DP.muted,
                      ),
                    ),
                    if (c != null) ...[
                      const SizedBox(height: 12),
                      DPAppear(
                        child: DPCard(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(DPIcons.checkCircle, color: DP.green, size: 20),
                                const SizedBox(width: 8),
                                Text('Smartcard verified', style: DP.bodyStrong.copyWith(color: DP.green)),
                              ]),
                              const SizedBox(height: 6),
                              DPSummaryRow('Customer name', str(c['customerName'])),
                              DPSummaryRow('Smartcard / IUC', _card.text.trim()),
                              DPSummaryRow('Provider', _providerName),
                              if (c['currentPlan'] != null) DPSummaryRow('Current package', str(c['currentPlan'])),
                              if (c['dueDate'] != null) DPSummaryRow('Due date', dateLabel(parseDate(c['dueDate']))),
                              if (c['renewalAmount'] != null)
                                DPSummaryRow('Renewal amount', DP.naira(toDouble(c['renewalAmount'])),
                                    strong: true, valueColor: DP.green),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionTitle('Choose a package'),
                      if (_plansLoading)
                        const DPSkeletonList(rows: 3)
                      else if (_plansError != null)
                        DPLoadError(error: _plansError, onRetry: _loadPlans)
                      else
                        for (final p in _plans) _planTile(p),
                      if (_plan != null) ...[
                        const SizedBox(height: 8),
                        DPAppear(
                          child: DPCard(
                            color: DP.mint,
                            borderColor: DP.mintLine,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Column(children: [
                              DPSummaryRow('Package', _plan!.name),
                              DPSummaryRow('Amount to pay', DP.naira(_plan!.price), strong: true, valueColor: DP.green),
                            ]),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DPBottomAction(
        child: DPButton(
          label: 'Review TV payment',
          icon: DPIcons.forward,
          onPressed: slConnected && c != null && _plan != null ? _review : null,
        ),
      ),
    );
  }

  Widget _planTile(Plan p) {
    final on = _plan == p;
    final current = _customer?['currentPlanCode'] == p.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DPCard(
        onTap: () => setState(() => _plan = p),
        color: on ? DP.mint : DPAuto.surface,
        borderColor: on ? DP.green : DPAuto.border,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: DP.bodyStrong),
                  Text(current ? 'Your current package' : (p.validity ?? '1 month'), style: DP.caption),
                ],
              ),
            ),
            Text(DP.naira(p.price), style: DP.money.copyWith(color: DP.green, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: on ? DP.green : DP.faint, size: 20),
          ],
        ),
      ),
    );
  }
}
