// lib/presentation/screens/sierra_leone/sl_topup_screen.dart
// Sierra Leone airtime and data (Africell, Orange, Qcell):
//   GET  /api/services/sl/networks
//   GET  /api/services/sl/data/plans?network=
//   POST /api/services/sl/airtime | /api/services/sl/data
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';
import 'sl_common.dart';

class SlTopUpScreen extends StatefulWidget {
  /// true: data bundles; false: airtime.
  final bool data;
  const SlTopUpScreen({super.key, this.data = false});

  @override
  State<SlTopUpScreen> createState() => _SlTopUpScreenState();
}

class _SlTopUpScreenState extends State<SlTopUpScreen> with SlAvailability {
  final _phone = TextEditingController();
  final _amount = TextEditingController();

  // Shown until the server answers (and if it can't).
  List<Map<String, dynamic>> _networks = const [
    {'id': 'africell', 'name': 'Africell'},
    {'id': 'orange', 'name': 'Orange'},
    {'id': 'qcell', 'name': 'Qcell'},
  ];
  String _network = 'africell';
  List<Plan> _plans = [];
  bool _plansLoading = false;
  Object? _plansError;
  Plan? _plan;
  ServiceLimit _limit = const ServiceLimit(minimum: 1);

  static const _quick = [5, 10, 20, 50, 100, 200];

  String get _service => widget.data ? 'sl_data' : 'sl_airtime';

  @override
  void initState() {
    super.initState();
    checkAvailability(_service);
    _load();
  }

  Future<void> _load() async {
    try {
      final nets = asList(await api.get('/api/services/sl/networks'));
      if (nets.isNotEmpty && mounted) {
        setState(() {
          _networks = nets;
          _network = str(nets.first['id']);
        });
      }
    } catch (_) {}
    final limit = await Catalog.limitFor(_service);
    if (mounted) setState(() => _limit = limit);
    if (widget.data) _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _plansLoading = true;
      _plansError = null;
      _plan = null;
    });
    try {
      final r = await api.get('/api/services/sl/data/plans', query: {'network': _network});
      if (!mounted) return;
      setState(() {
        _plans = Plan.listFrom(r);
        _plansLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plansError = e;
        _plansLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  String get _networkName =>
      str(_networks.firstWhere((n) => n['id'] == _network, orElse: () => {'name': _network})['name']);

  double get _price => widget.data ? (_plan?.price ?? 0) : (double.tryParse(_amount.text) ?? 0);

  void _review() {
    final phone = slPhone(_phone.text);
    if (phone == null) {
      dpSnack(context, DPCountry.sierraLeone.phoneError, error: true);
      return;
    }
    if (widget.data && _plan == null) {
      dpSnack(context, 'Choose a data plan', error: true);
      return;
    }
    if (!widget.data) {
      final err = _limit.check(_price, DP.naira);
      if (err != null) {
        dpSnack(context, err, error: true);
        return;
      }
    }
    final name = _networkName;
    showReviewAndPay(
      context,
      icon: widget.data ? DPIcons.wifi : DPIcons.phone,
      title: widget.data ? '$name data' : '$name airtime',
      serviceLabel: widget.data ? '$name Data' : '$name Airtime',
      amount: _price,
      service: _service,
      rows: [
        DPReviewRow('Phone number', phone),
        DPReviewRow('Network', '$name Sierra Leone'),
        if (widget.data) DPReviewRow('Plan', _plan!.name),
        DPReviewRow('Amount', DP.naira(_price)),
        DPReviewRow('Total to pay', DP.naira(_price), strong: true),
      ],
      footnote: 'Confirm the number. Delivered top-ups can\'t be reversed.',
      onPay: (pin) async {
        final r = await api.post(
          widget.data ? '/api/services/sl/data' : '/api/services/sl/airtime',
          {
            'network': _network,
            'phone': phone,
            if (widget.data) 'planCode': _plan!.code else 'amount': _price,
            'pin': pin,
          },
        );
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quick = _quick.map((a) => DP.naira(a, decimals: false)).toList();
    final amount = double.tryParse(_amount.text) ?? 0;
    final selectedQuick = _quick.contains(amount.toInt()) && amount == amount.roundToDouble()
        ? DP.naira(amount.toInt(), decimals: false)
        : null;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: widget.data ? 'Buy data' : 'Buy airtime',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DPServiceBanner(
                      title: widget.data ? 'Buy data bundles in seconds.' : 'Top up airtime in seconds.',
                      subtitle: 'Africell, Orange and Qcell — any Sierra Leone number.',
                      icon: widget.data ? DPIcons.wifi : DPIcons.smartphone,
                      image: widget.data ? DPAssets.svcData : DPAssets.svcAirtime,
                      style: widget.data ? DPBannerStyle.ocean : DPBannerStyle.navy,
                      tag: widget.data ? 'Data' : 'Airtime',
                    ),
                    const SizedBox(height: 20),
                    if (!slConnected) SlComingSoon(widget.data ? 'Data' : 'Airtime'),
                    const SectionTitle('Choose network'),
                    DPChipRow(
                      options: [for (final n in _networks) str(n['name'])],
                      selected: _networkName,
                      height: 46,
                      onSelect: (name) {
                        HapticFeedback.selectionClick();
                        final id = str(_networks.firstWhere((n) => n['name'] == name)['id']);
                        setState(() => _network = id);
                        if (widget.data) _loadPlans();
                      },
                    ),
                    const SizedBox(height: 22),
                    const DPLabel('Phone number'),
                    DPField(
                      controller: _phone,
                      hint: DPCountry.sierraLeone.phoneHint,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      onChanged: (_) => setState(() {}),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 6),
                        child: DPFlag('SL', width: 24),
                      ),
                      suffix: IconButton(
                        tooltip: 'Use my number',
                        icon: Icon(DPIcons.contact, color: DP.muted),
                        onPressed: () => setState(() => _phone.text = Session.instance.user?.phone ?? ''),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (widget.data) ...[
                      const SectionTitle('Choose a plan'),
                      if (_plansLoading)
                        const DPSkeletonList(rows: 3)
                      else if (_plansError != null)
                        DPLoadError(error: _plansError, onRetry: _loadPlans)
                      else if (_plans.isEmpty)
                        const DPEmptyState(icon: DPIcons.wifi, title: 'No plans available right now')
                      else
                        for (final p in _plans) _planTile(p),
                    ] else ...[
                      const SectionTitle('Quick amounts'),
                      DPChipGrid(
                        options: quick,
                        selected: selectedQuick,
                        height: 46,
                        onSelect: (label) {
                          final i = quick.indexOf(label);
                          if (i >= 0) setState(() => _amount.text = _quick[i].toString());
                        },
                      ),
                      const SizedBox(height: 20),
                      const DPLabel('Amount'),
                      DPField(
                        controller: _amount,
                        hint: '0.00',
                        prefixText: '${DP.currencySymbol} ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      ),
                      DPHelper(_limit.describe(DP.naira)),
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
          label: 'Continue to review',
          icon: DPIcons.forward,
          onPressed: slConnected ? _review : null,
        ),
      ),
    );
  }

  Widget _planTile(Plan p) {
    final on = _plan == p;
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
                  if (p.validity != null) Text(p.validity!, style: DP.caption),
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
