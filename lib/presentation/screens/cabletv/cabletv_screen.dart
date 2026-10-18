// lib/presentation/screens/cabletv/cabletv_screen.dart
// UI only — provider, smartcard ("Verify" shows a sample customer), renew
// or change package, months → review → success.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class CableTvScreen extends StatefulWidget {
  const CableTvScreen({super.key});

  @override
  State<CableTvScreen> createState() => _CableTvScreenState();
}

class _CableTvScreenState extends State<CableTvScreen> {
  final _smartCardController = TextEditingController();
  final _phoneController = TextEditingController(text: MockUser.phone);

  String? _selectedProvider;
  bool _isValidating = false;
  bool _isValidated = false;
  String? _selectedAction; // 'renew' | 'change'
  MockPlan? _selectedPlan;
  int _quantity = 1;

  static const _actions = {
    'renew': 'Renew current',
    'change': 'Change package',
  };

  List<MockPlan> get _plans => kMockCablePlans[_selectedProvider] ?? const [];

  /// The sample customer's current package (2nd plan of the provider).
  MockPlan? get _currentPlan => _plans.length > 1 ? _plans[1] : null;

  double get _amount {
    if (_selectedAction == 'renew') return _currentPlan?.price ?? 0;
    return _selectedPlan?.price ?? 0;
  }

  @override
  void dispose() {
    _smartCardController.dispose();
    _phoneController.dispose();
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
    setState(() => _isValidating = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isValidating = false;
      _isValidated = true;
    });
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
    final plan = _selectedAction == 'renew' ? _currentPlan! : _selectedPlan!;
    final total = _amount * _quantity;
    showReviewAndPay(
      context,
      icon: DPIcons.tv,
      title: '$_selectedProvider ${plan.name}',
      serviceLabel: '$_selectedProvider Subscription',
      amount: total,
      service: 'cable',
      rows: [
        const DPReviewRow('Customer', 'ADAEZE OKAFOR'),
        DPReviewRow('Smartcard', _smartCardController.text.trim()),
        DPReviewRow('Package', plan.name),
        DPReviewRow('Months', '$_quantity'),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(total), strong: true),
      ],
      footnote:
          'Check the smartcard number. Subscriptions can\'t be reversed once activated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _smartCardController.text.trim();
    final canValidate = _selectedProvider != null &&
        card.length >= 10 &&
        card.length <= 11 &&
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
                          items: kMockCableProviders,
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
                        });
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
                      hint: '10–11 digit number',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
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
                      DPCard(
                        color: DP.mint,
                        borderColor: null,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(DPIcons.checkCircle,
                                color: DP.green, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ADAEZE OKAFOR',
                                    style: TextStyle(
                                      color: DP.green,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_currentPlan != null)
                                    Text(
                                      'Current: ${_currentPlan!.name}',
                                      style: const TextStyle(
                                        color: DP.green,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  const Text(
                                    'Due: 28 Feb 2026',
                                    style: TextStyle(
                                      color: DP.green,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionTitle('What do you want to do?'),
                      DPChipRow(
                        options: _actions.values.toList(),
                        selected: _selectedAction == null
                            ? null
                            : _actions[_selectedAction],
                        height: 46,
                        onSelect: (label) => setState(() {
                          _selectedAction = _actions.entries
                              .firstWhere((e) => e.value == label)
                              .key;
                          _selectedPlan = null;
                          _quantity = 1;
                        }),
                      ),
                    ],
                    if (_isValidated && _selectedAction == 'change') ...[
                      const SizedBox(height: 18),
                      const SectionTitle('Choose a package'),
                      for (final p in _plans) _planCard(p),
                    ],
                    if (_isValidated &&
                        _selectedAction != null &&
                        _amount > 0) ...[
                      const SizedBox(height: 16),
                      _buildMonths(),
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

  Widget _planCard(MockPlan plan) {
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
            step(DPIcons.plus, _quantity < 12,
                () => setState(() => _quantity++)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Max 12 months',
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
