// lib/presentation/screens/electricity/electricity_screen.dart
// UI only — provider, meter type, meter number ("Verify meter" shows a
// sample customer), amount → review → success.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final _meterController = TextEditingController();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController(text: MockUser.phone);

  String? _selectedProvider;
  String? _selectedMeterType;
  int? _selectedQuickAmount;
  bool _isValidating = false;
  bool _isValidated = false;

  static const List<int> _quickAmounts = [2000, 3000, 5000, 10000, 20000];
  static const _meterLabels = {
    'prepaid': 'Prepaid meter',
    'postpaid': 'Postpaid account',
  };

  @override
  void dispose() {
    _meterController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _validateMeter() async {
    setState(() => _isValidating = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isValidating = false;
      _isValidated = true;
    });
  }

  void _openReview() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_selectedProvider == null || _selectedMeterType == null) {
      dpSnack(context, 'Choose your provider and meter type', error: true);
      return;
    }
    if (!_isValidated) {
      dpSnack(context, 'Verify your meter number first', error: true);
      return;
    }
    if (amount < 2000) {
      dpSnack(context, 'Minimum purchase is ₦2,000', error: true);
      return;
    }
    showReviewAndPay(
      context,
      icon: DPIcons.bolt,
      title: _selectedProvider!,
      serviceLabel: 'Electricity',
      amount: amount,
      service: 'electricity',
      rows: [
        const DPReviewRow('Customer', 'ADAEZE OKAFOR'),
        DPReviewRow('Meter number', _meterController.text.trim()),
        DPReviewRow('Meter type', _meterLabels[_selectedMeterType]!),
        DPReviewRow('Token sent to', _phoneController.text.trim()),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(amount), strong: true),
      ],
      successRows: [
        DPReviewRow('Provider', _selectedProvider!),
        DPReviewRow('Meter number', _meterController.text.trim()),
        if (_selectedMeterType == 'prepaid') ...const [
          DPReviewRow('Token', '1234-5678-9012-3456-7890'),
          DPReviewRow('Units', '48.6 kWh'),
        ],
      ],
      footnote: 'Check the meter number. Electricity tokens can\'t be reversed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final canVerify = !_isValidating &&
        _meterController.text.trim().length >= 11 &&
        _selectedProvider != null &&
        _selectedMeterType != null;
    final quickLabels =
        _quickAmounts.map((a) => DP.naira(a, decimals: false)).toList();

    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Electricity',
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
                      'A brighter day starts here. Top up your meter.',
                      style: DP.body.copyWith(color: DP.muted),
                    ),
                    const SizedBox(height: 20),
                    const DPLabel('Electricity provider'),
                    DPSelectField(
                      value: _selectedProvider,
                      hint: 'Choose your provider',
                      leading:
                          const Icon(DPIcons.bolt, color: DP.green, size: 20),
                      onTap: () async {
                        final picked = await dpPickFromList<String>(
                          context,
                          title: 'Electricity provider',
                          items: kMockDiscos,
                          selected: _selectedProvider,
                          labelOf: (x) => x,
                        );
                        if (picked == null || !mounted) return;
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedProvider = picked;
                          _isValidated = false;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DPChipRow(
                      options: _meterLabels.values.toList(),
                      selected: _selectedMeterType == null
                          ? null
                          : _meterLabels[_selectedMeterType],
                      height: 46,
                      onSelect: (label) {
                        final value = _meterLabels.entries
                            .firstWhere((e) => e.value == label)
                            .key;
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedMeterType = value;
                          _isValidated = false;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    DPLabel(
                      'Meter number',
                      trailing: _isValidated
                          ? null
                          : DPTextLink(
                              label:
                                  _isValidating ? 'Checking…' : 'Verify meter',
                              color: canVerify ? DP.green : DP.faint,
                              onTap: canVerify ? _validateMeter : null,
                            ),
                    ),
                    DPField(
                      controller: _meterController,
                      hint: '11–13 digit meter number',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
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
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(DPIcons.checkCircle,
                                color: DP.green, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ADAEZE OKAFOR',
                                    style: TextStyle(
                                      color: DP.green,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Text(
                                      '12 Admiralty Way, Lekki, Lagos',
                                      style: TextStyle(
                                        color: DP.green,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const DPLabel('Amount'),
                    DPField(
                      controller: _amountController,
                      hint: '0.00',
                      prefixText: '₦',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) =>
                          setState(() => _selectedQuickAmount = null),
                      style: TextStyle(fontSize: 17, color: DP.ink),
                    ),
                    const DPHelper('Minimum purchase: ₦2,000'),
                    const SizedBox(height: 12),
                    DPChipScroller(
                      options: quickLabels,
                      selected: _selectedQuickAmount == null
                          ? null
                          : DP.naira(_selectedQuickAmount, decimals: false),
                      onSelect: (l) {
                        final a = _quickAmounts[quickLabels.indexOf(l)];
                        setState(() {
                          _selectedQuickAmount = a;
                          _amountController.text = a.toString();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const DPLabel('Phone number for token'),
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
                      amount: amount,
                      service: 'electricity',
                    ),
                    const SizedBox(height: 14),
                    const DPBanner(
                      'Your units are set by your provider\'s tariff. Your token will appear on your receipt and arrive by SMS.',
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
          label: 'Review electricity payment',
          icon: DPIcons.forward,
          onPressed: _openReview,
        ),
      ),
    );
  }
}
