// lib/presentation/screens/cabletv/cabletv_screen.dart
// Provider, smartcard (POST /api/services/cable/verify), renew or change
// package (GET /api/services/cable/plans), months → review →
// POST /api/services/cable.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';

class CableTvScreen extends StatefulWidget {
  const CableTvScreen({super.key});

  @override
  State<CableTvScreen> createState() => _CableTvScreenState();
}

class _CableTvScreenState extends State<CableTvScreen> {
  final _smartCardController = TextEditingController();
  final _phoneController =
      TextEditingController(text: Session.instance.user?.phone ?? '');

  String? _selectedProvider;
  bool _isValidating = false;
  bool _isValidated = false;
  String? _selectedAction; // 'renew' | 'change'
  final _customAmount = TextEditingController();
  Plan? _selectedPlan;
  int _quantity = 1;

  /// name ("DSTV") → id ("dstv").
  Map<String, String> _providers = {};
  List<Plan> _plans = [];
  bool _plansLoading = false;
  Object? _plansError;
  Map<String, dynamic> _customer = {};

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final list = asList(await api.get('/api/services/cable/providers'));
      if (!mounted) return;
      setState(() => _providers = {
            for (final p in list) str(p['name']): str(p['id']),
          });
      if (_selectedProvider != null) _loadPlans();
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _loadPlans() async {
    final provider = _selectedProvider;
    final id = _providers[provider];
    if (id == null) return;
    setState(() {
      _plansLoading = true;
      _plansError = null;
      _plans = [];
    });
    try {
      final r = await api.get('/api/services/cable/plans', query: {'provider': id});
      if (!mounted || provider != _selectedProvider) return;
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

  static const _actions = {
    'renew': 'Renew current',
    'change': 'Change package',
  };

  /// DStv renewals can be paid with an edited amount (credited to the
  /// decoder's account).
  static const _anyAmountProviders = {'dstv'};
  static const _minCustom = 500.0;
  bool get _allowsCustom => _anyAmountProviders.contains(_providers[_selectedProvider]);

  /// Renew with an editable amount (DStv).
  bool get _editableRenew => _selectedAction == 'renew' && _allowsCustom;

  void _resetRenewAmount() {
    final r = toDouble(_customer['renewalAmount']);
    _customAmount.text = r > 0 ? (r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2)) : '';
  }

  /// Whether this decoder can be renewed at the provider's renewal price
  /// (StarTimes can't; it is always "choose a package").
  bool get _canRenew =>
      _customer['canRenew'] != false && toDouble(_customer['renewalAmount']) > 0;

  /// Most months that can be paid at once (StarTimes: 1).
  int get _maxMonths {
    final m = toInt(_customer['maxMonths']);
    return m <= 0 ? 12 : m;
  }

  Map<String, String> get _availableActions => {
        if (_canRenew) 'renew': _actions['renew']!,
        'change': _actions['change']!,
      };

  /// The customer's current package, from the smartcard check.
  Plan? get _currentPlan => !_canRenew || _customer['currentPlanCode'] == null
      ? null
      : Plan(
          str(_customer['currentPlanCode']),
          str(_customer['currentPlan']),
          toDouble(_customer['renewalAmount']),
          '1 month',
        );

  double get _amount {
    if (_editableRenew) return double.tryParse(_customAmount.text) ?? 0;
    if (_selectedAction == 'renew') return _currentPlan?.price ?? 0;
    return _selectedPlan?.price ?? 0;
  }

  @override
  void dispose() {
    _smartCardController.dispose();
    _phoneController.dispose();
    _customAmount.dispose();
    super.dispose();
  }

  Widget _providerLogo(String? name, {double size = 28}) {
    final fallback = Icon(DPIcons.tv, color: DP.navyIcon, size: size * 0.75);
    if (name == null) return fallback;
    final asset = DPAssets.providerFor(name);
    if (asset == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: DPImage(asset, width: size, height: size, fallback: fallback),
    );
  }

  Future<void> _validate() async {
    FocusScope.of(context).unfocus();
    setState(() => _isValidating = true);
    try {
      final r = asMap(await api.post('/api/services/cable/verify', {
        'provider': _providers[_selectedProvider],
        'smartcardNumber': _smartCardController.text.trim(),
      }));
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isValidated = true;
        _customer = r;
        _selectedPlan = null;
        _selectedAction = _canRenew ? 'renew' : 'change';
        if (_quantity > _maxMonths) _quantity = _maxMonths;
        _resetRenewAmount();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  void _openReview() {
    if (!_isValidated || _selectedAction == null || _amount <= 0) {
      dpSnack(
        context,
        _isValidated
            ? 'Choose what you want to do and a package'
            : 'Verify your smartcard number first',
        error: true,
      );
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      dpSnack(context, 'Enter an 11-digit phone number', error: true);
      return;
    }
    final action = _selectedAction!;
    final edited = _editableRenew;
    if (edited && _amount < _minCustom) {
      dpSnack(context, 'Enter at least ${DP.naira(_minCustom, decimals: false)}', error: true);
      return;
    }
    final plan = action == 'renew' ? _currentPlan! : _selectedPlan!;
    final months = edited ? 1 : _quantity;
    final total = _amount * months;
    final customAmount = _amount;
    final providerId = _providers[_selectedProvider]!;
    final card = _smartCardController.text.trim();
    showReviewAndPay(
      context,
      icon: DPIcons.tv,
      title: '$_selectedProvider ${plan.name}',
      serviceLabel: '$_selectedProvider Subscription',
      amount: total,
      service: 'cable',
      rows: [
        DPReviewRow('Customer', str(_customer['customerName'])),
        DPReviewRow('Smartcard', _smartCardController.text.trim()),
        DPReviewRow('Package', plan.name),
        if (!edited) DPReviewRow('Months', '$_quantity'),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(total), strong: true),
      ],
      footnote:
          'Check the smartcard number. Subscriptions can\'t be reversed once activated.',
      onPay: (pin) async {
        final r = await api.post('/api/services/cable', {
          'provider': providerId,
          'smartcardNumber': card,
          'action': action,
          if (action == 'change') 'planCode': plan.code,
          if (edited) 'amount': customAmount,
          'months': months,
          'phone': phone,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _smartCardController.text.trim();
    final canValidate = _selectedProvider != null &&
        card.length >= 8 &&
        !_isValidating;

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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPServiceBanner(
                      title: 'Pay, renew or activate your subscription in seconds.',
                      subtitle: 'DStv, GOtv, StarTimes and Showmax.',
                      icon: DPIcons.tv,
                      image: DPAssets.svcTv,
                      style: DPBannerStyle.navy,
                      tag: 'Cable TV',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your shows, right on time. Renew or change your package.',
                      style: DP.body.copyWith(color: DP.muted),
                    ),
                    const SizedBox(height: 20),
                    const DPLabel('TV provider'),
                    DPSelectField(
                      value: _selectedProvider,
                      hint: 'Choose your provider',
                      leading: _providerLogo(_selectedProvider),
                      onTap: () async {
                        final picked = await dpPickFromList<String>(
                          context,
                          title: 'TV provider',
                          items: _providers.keys.toList(),
                          selected: _selectedProvider,
                          labelOf: (x) => x,
                          leadingOf: (x) => _providerLogo(x),
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          _selectedProvider = picked;
                          _isValidated = false;
                          _selectedAction = null;
                          _selectedPlan = null;
                          _quantity = 1;
                          _customer = {};
                        });
                        _loadPlans();
                      },
                    ),
                    const SizedBox(height: 20),
                    DPLabel(
                      'Smartcard / IUC number',
                      trailing: _isValidated
                          ? null
                          : DPTextLink(
                              label: _isValidating ? 'Checking…' : 'Verify',
                              color: canValidate ? DP.green : DP.faint,
                              onTap: canValidate ? _validate : null,
                            ),
                    ),
                    DPField(
                      controller: _smartCardController,
                      hint: 'Smartcard / IUC number',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onChanged: (_) => setState(() => _isValidated = false),
                      style: TextStyle(
                        fontSize: 17,
                        color: DP.ink,
                        letterSpacing: 0.6,
                      ),
                      suffix: _isValidating
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Icon(
                              _isValidated ? DPIcons.checkCircle : DPIcons.scan,
                              color: _isValidated ? DP.green : DP.muted,
                            ),
                    ),
                    if (_isValidated) ...[
                      const SizedBox(height: 12),
                      DPAppear(child: _buildCustomerDetails()),
                      const SizedBox(height: 20),
                      const SectionTitle('What do you want to do?'),
                      DPChipRow(
                        options: _availableActions.values.toList(),
                        selected: _selectedAction == null
                            ? null
                            : _actions[_selectedAction],
                        height: 46,
                        onSelect: (label) => setState(() {
                          _selectedAction = _availableActions.entries
                              .firstWhere((e) => e.value == label)
                              .key;
                          _selectedPlan = null;
                          _quantity = 1;
                          if (_selectedAction == 'renew') _resetRenewAmount();
                        }),
                      ),
                    ],
                    if (_isValidated && _editableRenew) ...[
                      const SizedBox(height: 18),
                      const DPLabel('Amount to pay'),
                      DPField(
                        controller: _customAmount,
                        hint: '0',
                        prefixText: '₦ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        onChanged: (_) => setState(() {}),
                        suffix: IconButton(
                          tooltip: 'Use the renewal price',
                          icon: Icon(DPIcons.refresh, color: DP.muted),
                          onPressed: () => setState(_resetRenewAmount),
                        ),
                      ),
                      DPHelper(
                        'Renewal price: ${DP.naira(toDouble(_customer['renewalAmount']))}. You can change the amount '
                        '(at least ${DP.naira(_minCustom, decimals: false)}); it\'s added to your DStv account.',
                        icon: DPIcons.info,
                      ),
                    ],
                    if (_isValidated && _selectedAction == 'change') ...[
                      const SizedBox(height: 18),
                      const SectionTitle('Choose a package'),
                      if (_plansLoading)
                        const DPLoading(padding: 24)
                      else if (_plansError != null)
                        DPLoadError(error: _plansError, onRetry: _loadPlans)
                      else
                        for (final p in _plans) _planCard(p),
                    ],
                    if (_isValidated &&
                        _selectedAction != null &&
                        _amount > 0) ...[
                      const SizedBox(height: 16),
                      if (!_editableRenew) ...[
                        _buildMonths(),
                        const SizedBox(height: 16),
                      ],
                      DPAppear(child: _buildAmountToPay()),
                    ],
                    const SizedBox(height: 20),
                    const DPLabel('Phone number'),
                    DPField(
                      controller: _phoneController,
                      hint: '0803 456 7890',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      suffix: Icon(DPIcons.phone, color: DP.muted),
                    ),
                    const SizedBox(height: 20),
                    WalletCommissionCard(
                      amount: _amount * _quantity,
                      service: 'cable',
                    ),
                    const SizedBox(height: 14),
                    const DPBanner(
                      'Check the smartcard number before paying. Subscriptions can\'t be reversed once activated.',
                    ),
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
          onPressed: _openReview,
        ),
      ),
    );
  }

  Widget _planCard(Plan plan) {
    final selected = _selectedPlan == plan;
    final current = _currentPlan == plan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DPCard(
        color: selected ? DP.mint : DP.surface,
        borderColor: selected ? DP.green : DP.border,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: current
            ? () => dpSnack(context, 'You\'re already on this package')
            : () => setState(() {
                  _selectedPlan = plan;
                  _quantity = 1;
                }),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.name,
                          style: DP.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (current) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DP.mint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: DP.greenDeep,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(plan.validity ?? '', style: DP.caption),
                ],
              ),
            ),
            Text(
              DP.naira(plan.price, decimals: false),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DP.green,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: current ? DP.faint : DP.green,
            ),
          ],
        ),
      ),
    );
  }

  /// Everything the smartcard check returned, so the customer can confirm
  /// it's the right decoder before choosing what to pay.
  Widget _buildCustomerDetails() {
    final c = _customer;
    final renewal = toDouble(c['renewalAmount']);
    return DPCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(DPIcons.checkCircle, color: DP.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Smartcard verified',
                    style: DP.bodyStrong.copyWith(color: DP.green)),
              ),
              _providerLogo(_selectedProvider, size: 24),
            ],
          ),
          const SizedBox(height: 6),
          DPSummaryRow('Customer name', str(c['customerName'])),
          DPSummaryRow('Smartcard / IUC', _smartCardController.text.trim()),
          DPSummaryRow('Provider', _selectedProvider ?? ''),
          if (c['currentPlan'] != null)
            DPSummaryRow('Current package', str(c['currentPlan'])),
          if (c['status'] != null && str(c['status']).isNotEmpty)
            DPSummaryRow('Status', str(c['status'])),
          if (c['dueDate'] != null)
            DPSummaryRow('Due date', dateLabel(parseDate(c['dueDate']))),
          if (c['balance'] != null)
            DPSummaryRow('Decoder balance', DP.naira(toDouble(c['balance']))),
          if (_canRenew && renewal > 0)
            DPSummaryRow('Renewal amount', DP.naira(renewal),
                strong: true, valueColor: DP.green),
        ],
      ),
    );
  }

  /// What will be paid: package, months and the total, before review.
  Widget _buildAmountToPay() {
    final plan = _selectedAction == 'renew' ? _currentPlan : _selectedPlan;
    return DPCard(
      color: DP.mint,
      borderColor: DP.mintLine,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          if (_editableRenew) ...[
            DPSummaryRow('Renew', plan?.name.isNotEmpty == true ? plan!.name : 'Current package'),
            DPSummaryRow('Amount to pay', DP.naira(_amount), strong: true, valueColor: DP.green),
          ] else ...[
            DPSummaryRow(
              _selectedAction == 'renew' ? 'Renew' : 'New package',
              plan?.name.isNotEmpty == true ? plan!.name : 'Current package',
            ),
            DPSummaryRow('Price per month', DP.naira(_amount)),
            DPSummaryRow('Months', '$_quantity'),
            DPSummaryRow('Amount to pay', DP.naira(_amount * _quantity),
                strong: true, valueColor: DP.green),
          ],
        ],
      ),
    );
  }

  Widget _buildMonths() {
    Widget step(IconData icon, bool enabled, VoidCallback onTap) => DPIconSquare(
          icon: icon,
          size: 44,
          color: enabled ? DP.ink : DP.faint,
          onTap: enabled ? onTap : null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Months', style: DP.section)),
            Text(
              'Total: ${DP.naira(_amount * _quantity)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DP.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            step(Icons.remove_rounded, _quantity > 1,
                () => setState(() => _quantity--)),
            SizedBox(
              width: 56,
              child: Text(
                '$_quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: DP.ink,
                ),
              ),
            ),
            step(DPIcons.plus, _quantity < _maxMonths,
                () => setState(() => _quantity++)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _maxMonths == 1 ? 'One period at a time' : 'Max $_maxMonths months',
                textAlign: TextAlign.right,
                style: DP.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
