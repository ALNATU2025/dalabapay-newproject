// lib/presentation/screens/internet/internet_screen.dart
// Network, phone, plan (GET /api/services/data/plans) → review →
// POST /api/services/data.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';

class InternetScreen extends StatefulWidget {
  const InternetScreen({super.key});

  @override
  State<InternetScreen> createState() => _InternetScreenState();
}

class _InternetScreenState extends State<InternetScreen> {
  final _phoneController = TextEditingController();
  String? _selectedNetwork;
  Plan? _selectedPlan;
  String _planFilter = 'All plans';

  Map<String, String> _networkIds = const {
    'MTN': 'mtn',
    'Airtel': 'airtel',
    'Glo': 'glo',
    '9mobile': '9mobile',
  };
  List<Map<String, String>> _recent = [];
  List<Plan> _plans = [];
  bool _plansLoading = false;
  Object? _plansError;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final nets = await Catalog.networks();
      if (nets.isNotEmpty && mounted) {
        setState(() => _networkIds = {
              for (final n in nets) str(n['name']): str(n['id']),
            });
      }
    } catch (_) {}
    final recent = await Catalog.recentRecipients('data');
    if (!mounted) return;
    setState(() => _recent = [
          for (final t in recent)
            {
              'phone': str(t['recipient']),
              'network': str(asMap(t['metadata'])['network']),
            },
        ]);
  }

  Future<void> _loadPlans() async {
    final network = _selectedNetwork;
    if (network == null) return;
    setState(() {
      _plansLoading = true;
      _plansError = null;
      _plans = [];
    });
    try {
      final r = await api.get('/api/services/data/plans',
          query: {'network': _networkIds[network] ?? network.toLowerCase()});
      if (!mounted || network != _selectedNetwork) return;
      setState(() {
        _plans = Plan.listFrom(r);
        _plansLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plansLoading = false;
        _plansError = e;
      });
    }
  }

  void _selectNetwork(String? name) {
    if (name == null || name == _selectedNetwork) return;
    setState(() {
      _selectedNetwork = name;
      _selectedPlan = null;
    });
    _loadPlans();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  int _days(Plan p) {
    final v = (p.validity ?? '').toLowerCase();
    final n = int.tryParse(v.split(' ').first) ?? 30;
    if (v.contains('week')) return n * 7;
    if (v.contains('month')) return n * 30;
    return n;
  }

  bool _matches(Plan p) {
    final d = _days(p);
    switch (_planFilter) {
      case 'Daily':
        return d <= 3;
      case 'Weekly':
        return d > 3 && d <= 14;
      case 'Monthly':
        return d > 14;
    }
    return true;
  }

  void _openReview() {
    final phone = _phoneController.text.trim();
    if (_selectedNetwork == null || _selectedPlan == null) {
      dpSnack(context, 'Choose a network and a plan', error: true);
      return;
    }
    if (phone.length != 11) {
      dpSnack(context, 'Enter an 11-digit phone number', error: true);
      return;
    }
    final plan = _selectedPlan!;
    final network = _selectedNetwork!;
    showReviewAndPay(
      context,
      icon: DPIcons.wifi,
      title: '$network ${plan.name} data',
      serviceLabel: '$network Data',
      amount: plan.price,
      service: 'data',
      rows: [
        DPReviewRow('Phone number', phone),
        DPReviewRow('Network', '$network Nigeria'),
        DPReviewRow('Plan', '${plan.name}${plan.validity != null ? ' · ${plan.validity}' : ''}'),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(plan.price), strong: true),
      ],
      footnote: 'Data activates on the number above and can\'t be moved.',
      onPay: (pin) async {
        final r = await api.post('/api/services/data', {
          'network': _networkIds[network] ?? network.toLowerCase(),
          'phone': phone,
          'planCode': plan.code,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phoneController.text.trim();
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Buy data',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'More streaming, scrolling and staying close.',
                      style: DP.body.copyWith(color: DP.muted),
                    ),
                    const SizedBox(height: 18),
                    DPChipRow(
                      options: _networkIds.keys.toList(),
                      selected: _selectedNetwork,
                      height: 46,
                      logos: true,
                      onSelect: (name) {
                        HapticFeedback.selectionClick();
                        _selectNetwork(name);
                      },
                    ),
                    const SizedBox(height: 20),
                    const DPLabel('Phone number'),
                    DPField(
                      controller: _phoneController,
                      hint: '0803 456 7890',
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: TextStyle(
                        fontSize: 17,
                        color: DP.ink,
                        letterSpacing: 0.4,
                      ),
                      suffix: IconButton(
                        tooltip: 'Use my number',
                        icon: Icon(DPIcons.contact, color: DP.muted),
                        onPressed: () => setState(
                          () => _phoneController.text =
                              Session.instance.user?.phone ?? '',
                        ),
                      ),
                    ),
                    if (_recent.isNotEmpty) const SizedBox(height: 12),
                    if (_recent.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recent.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final c = _recent[i];
                          return DPChip(
                            label: c['phone']!,
                            selected: phone == c['phone'],
                            height: 40,
                            leading: Icon(
                              DPIcons.history,
                              size: 16,
                              color: DP.muted,
                            ),
                            onTap: () {
                              setState(() => _phoneController.text = c['phone']!);
                              if (_networkIds.containsKey(c['network'])) {
                                _selectNetwork(c['network']);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_selectedNetwork != null)
                      _buildPlanSection()
                    else
                      const DPCard(
                        child: DPEmptyState(
                          icon: DPIcons.wifi,
                          title: 'Choose a network',
                          message:
                              'Pick your network above to see available data plans.',
                        ),
                      ),
                    if (_selectedPlan != null) ...[
                      const SizedBox(height: 16),
                      DPSummaryRow(
                        'Selected plan',
                        '${_selectedPlan!.name} · ${DP.naira(_selectedPlan!.price)}',
                      ),
                      const SizedBox(height: 8),
                      WalletCommissionCard(
                        amount: _selectedPlan!.price,
                        service: 'data',
                      ),
                      const DPHelper(
                        'Plans activate on the number entered. Double-check before continuing.',
                      ),
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
          label: _selectedPlan == null
              ? 'Continue'
              : 'Continue with ${_selectedPlan!.name}',
          icon: DPIcons.forward,
          onPressed: _openReview,
        ),
      ),
    );
  }

  Widget _buildPlanSection() {
    const filters = ['All plans', 'Daily', 'Weekly', 'Monthly'];
    final plans = _plans.where(_matches).toList();
    final rows = <Widget>[];
    for (var i = 0; i < plans.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _planCard(plans[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < plans.length
                      ? _planCard(plans[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Find your perfect plan'),
        DPChipRow(
          options: filters,
          selected: _planFilter,
          height: 40,
          spacing: 8,
          onSelect: (f) => setState(() => _planFilter = f),
        ),
        const SizedBox(height: 14),
        if (_plansLoading)
          const DPLoading(padding: 24)
        else if (_plansError != null)
          DPLoadError(error: _plansError, onRetry: _loadPlans)
        else if (plans.isEmpty)
          DPEmptyState(
            icon: DPIcons.wifi,
            title: 'No ${_planFilter.toLowerCase()} plans',
            message: 'Try another filter.',
          )
        else
          ...rows,
      ],
    );
  }

  Widget _planCard(Plan plan) {
    final isSelected = _selectedPlan == plan;
    return Material(
      color: isSelected ? DP.mint : DP.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DP.rLg),
        side: BorderSide(
          color: isSelected ? DP.green : DP.border,
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DP.rLg),
        onTap: () => setState(() => _selectedPlan = plan),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: DP.ink,
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: DP.green,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                plan.validity ?? '',
                style: DP.caption.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                DP.naira(plan.price, decimals: false),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DP.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
