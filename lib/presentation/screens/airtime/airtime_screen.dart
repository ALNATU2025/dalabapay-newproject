// lib/presentation/screens/airtime/airtime_screen.dart
// UI only — network, phone, amount → review → success.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedNetwork = 'MTN';

  static const List<int> _quickAmounts = [500, 1000, 2000, 3000, 5000, 10000];
  static const List<Map<String, String>> _recent = [
    {'phone': '08034567890', 'network': 'MTN'},
    {'phone': '08123456789', 'network': 'Airtel'},
    {'phone': '08051112223', 'network': 'Glo'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Guesses the network from the number prefix (UI nicety only).
  void _autoDetectNetwork(String v) {
    if (v.length < 4) return;
    final p = v.substring(0, 4);
    const mtn = ['0803', '0806', '0703', '0706', '0813', '0816', '0810', '0814', '0903', '0906', '0913', '0916'];
    const airtel = ['0802', '0808', '0708', '0812', '0701', '0902', '0901', '0904', '0907', '0912'];
    const glo = ['0805', '0807', '0705', '0815', '0811', '0905', '0915'];
    const nine = ['0809', '0818', '0817', '0909', '0908'];
    String? n;
    if (mtn.contains(p)) n = 'MTN';
    if (airtel.contains(p)) n = 'Airtel';
    if (glo.contains(p)) n = 'Glo';
    if (nine.contains(p)) n = '9mobile';
    if (n != null && n != _selectedNetwork) setState(() => _selectedNetwork = n);
  }

  void _openReview() {
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (_selectedNetwork == null || phone.length != 11) {
      dpSnack(context, 'Enter an 11-digit phone number', error: true);
      return;
    }
    if (amount < 50 || amount > 50000) {
      dpSnack(context, 'Enter an amount between ₦50 and ₦50,000', error: true);
      return;
    }
    final network = _selectedNetwork!;
    showReviewAndPay(
      context,
      icon: DPIcons.phone,
      title: '$network airtime',
      serviceLabel: '$network Airtime',
      amount: amount,
      service: 'airtime',
      rows: [
        DPReviewRow('Phone number', phone),
        DPReviewRow('Network', '$network Nigeria'),
        DPReviewRow('Amount', DP.naira(amount)),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(amount), strong: true),
      ],
      footnote: 'Confirm the number. Delivered airtime can\'t be reversed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final quick =
        _quickAmounts.map((a) => DP.naira(a, decimals: false)).toList();
    final selectedQuick = _quickAmounts.contains(amount.toInt()) &&
            amount == amount.roundToDouble()
        ? DP.naira(amount.toInt(), decimals: false)
        : null;
    final phone = _phoneController.text.trim();

    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Buy airtime',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPHeadline(
                      'Keep the conversation going.',
                      subtitle: 'Top up any Nigerian number in moments.',
                    ),
                    const SectionTitle('Choose network'),
                    DPChipRow(
                      options: kMockNetworks,
                      selected: _selectedNetwork,
                      height: 46,
                      logos: true,
                      onSelect: (name) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedNetwork = name);
                      },
                    ),
                    const SizedBox(height: 22),
                    const DPLabel('Phone number'),
                    DPField(
                      controller: _phoneController,
                      hint: '0803 456 7890',
                      keyboardType: TextInputType.phone,
                      onChanged: (val) {
                        _autoDetectNetwork(val);
                        setState(() {});
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: const TextStyle(
                        fontSize: 17,
                        color: DP.ink,
                        letterSpacing: 0.4,
                      ),
                      suffix: IconButton(
                        tooltip: 'Choose from contacts',
                        icon: const Icon(DPIcons.contact, color: DP.muted),
                        onPressed: () => setState(() {
                          _phoneController.text = MockUser.phone;
                          _autoDetectNetwork(MockUser.phone);
                        }),
                      ),
                    ),
                    if (_selectedNetwork != null && phone.length >= 4)
                      DPHelper('$_selectedNetwork Nigeria'),
                    const SizedBox(height: 14),
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
                            leading: const Icon(
                              DPIcons.history,
                              size: 16,
                              color: DP.muted,
                            ),
                            onTap: () => setState(() {
                              _phoneController.text = c['phone']!;
                              _selectedNetwork = c['network'];
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('Quick amounts'),
                    DPChipGrid(
                      options: quick,
                      selected: selectedQuick,
                      height: 46,
                      onSelect: (label) {
                        final i = quick.indexOf(label);
                        if (i >= 0) {
                          setState(() => _amountController.text =
                              _quickAmounts[i].toString());
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const DPLabel('Amount'),
                    DPField(
                      controller: _amountController,
                      hint: '0.00',
                      prefixText: '₦',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 17, color: DP.ink),
                    ),
                    const DPHelper('Minimum ₦50 · Maximum ₦50,000'),
                    const SizedBox(height: 20),
                    WalletCommissionCard(amount: amount, service: 'airtime'),
                    const SizedBox(height: 14),
                    const DPBanner(
                      'Commission goes to your earnings, not your wallet balance. Review the final amount before paying.',
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
          label: 'Continue to review',
          icon: DPIcons.forward,
          onPressed: _openReview,
        ),
      ),
    );
  }
}
