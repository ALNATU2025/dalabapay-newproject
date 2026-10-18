// lib/presentation/screens/international_airtime/international_airtime_screen.dart
// UI only — country → type → network → amount with a sample exchange rate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class InternationalAirtimeScreen extends StatefulWidget {
  const InternationalAirtimeScreen({super.key});

  @override
  State<InternationalAirtimeScreen> createState() =>
      _InternationalAirtimeScreenState();
}

class _InternationalAirtimeScreenState
    extends State<InternationalAirtimeScreen> {
  static const _types = ['Mobile Top Up', 'Mobile Data'];
  static const _operatorsByCountry = {
    'Ghana': ['MTN Ghana', 'Vodafone Ghana', 'AirtelTigo'],
    'Kenya': ['Safaricom', 'Airtel Kenya'],
    'Sierra Leone': ['Orange Sierra Leone', 'Africell Sierra Leone'],
    'United Kingdom': ['EE', 'O2', 'Vodafone UK', 'Three'],
    'United States': ['AT&T', 'T-Mobile', 'Verizon'],
    'South Africa': ['Vodacom', 'MTN South Africa', 'Cell C'],
    'Cameroon': ['MTN Cameroon', 'Orange Cameroon'],
  };

  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _email = TextEditingController();
  MockCountry? _country;
  String? _type;
  String? _operator;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    _email.dispose();
    super.dispose();
  }

  double get _foreign => double.tryParse(_amount.text.trim()) ?? 0;
  double get _naira => _foreign * (_country?.rate ?? 0);

  String _money(String cur, double v) => '$cur ${v.toStringAsFixed(2)}';

  void _openReview() {
    if (_country == null || _type == null || _operator == null) {
      dpSnack(context, 'Choose a country, type and network', error: true);
      return;
    }
    if (_phone.text.trim().length < 5 || _foreign <= 0) {
      dpSnack(context, 'Enter the phone number and amount', error: true);
      return;
    }
    final c = _country!;
    showReviewAndPay(
      context,
      icon: DPIcons.globe,
      title: '$_operator · ${c.name}',
      serviceLabel: 'International Airtime',
      amount: _naira,
      service: 'international',
      rows: [
        DPReviewRow('Phone number', '${c.dialCode} ${_phone.text.trim()}'),
        DPReviewRow('Network', _operator!),
        DPReviewRow('Recipient receives', _money(c.currency, _foreign)),
        DPReviewRow('Exchange rate', '1 ${c.currency} ≈ ${DP.naira(c.rate)}'),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('You pay', DP.naira(_naira), strong: true),
      ],
      footnote: 'International airtime can\'t be reversed once delivered.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _country;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'International airtime',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPHeadline(
                      'Send a little connection.',
                      subtitle: 'Top up a loved one\'s number abroad.',
                    ),
                    const DPLabel('Destination country'),
                    DPSelectField(
                      value: c == null ? null : '${c.flag}  ${c.name}',
                      hint: 'Choose a country',
                      leading: c == null
                          ? const Icon(DPIcons.globe,
                              color: DP.navyIcon, size: 20)
                          : null,
                      onTap: () async {
                        final picked = await dpPickFromList<MockCountry>(
                          context,
                          title: 'Destination country',
                          items: kMockCountries,
                          selected: c,
                          labelOf: (x) => '${x.flag}  ${x.name}',
                          subtitleOf: (x) => '${x.dialCode} · ${x.currency}',
                          searchable: true,
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          _country = picked;
                          _type = null;
                          _operator = null;
                        });
                      },
                    ),
                    if (c != null) ...[
                      const SizedBox(height: 16),
                      const DPLabel('Top-up type'),
                      DPChipRow(
                        options: _types,
                        selected: _type,
                        height: 46,
                        onSelect: (t) => setState(() => _type = t),
                      ),
                    ],
                    if (c != null && _type != null) ...[
                      const SizedBox(height: 16),
                      const DPLabel('Mobile network'),
                      DPSelectField(
                        value: _operator,
                        hint: 'Choose a network',
                        leading: const Icon(DPIcons.smartphone,
                            color: DP.navyIcon, size: 20),
                        onTap: () async {
                          final picked = await dpPickFromList<String>(
                            context,
                            title: 'Mobile network',
                            items: _operatorsByCountry[c.name] ?? const [],
                            selected: _operator,
                            labelOf: (x) => x,
                          );
                          if (picked == null || !mounted) return;
                          setState(() => _operator = picked);
                        },
                      ),
                    ],
                    if (_operator != null && c != null) ...[
                      const SizedBox(height: 16),
                      const DPLabel('Recipient\'s phone number'),
                      DPField(
                        controller: _phone,
                        hint: 'Phone number',
                        keyboardType: TextInputType.phone,
                        prefixText: '${c.dialCode}  ',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DPLabel('Amount (${c.currency})'),
                      DPField(
                        controller: _amount,
                        hint: 'Enter amount',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                      ),
                      DPHelper(
                        'Minimum ${_money(c.currency, 1)} · Maximum ${_money(c.currency, 500)}',
                      ),
                      const SizedBox(height: 16),
                      const DPLabel('Email for receipt (optional)'),
                      DPField(
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      DPCard(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                        child: Column(
                          children: [
                            DPSummaryRow(
                              'Recipient receives',
                              _money(c.currency, _foreign),
                            ),
                            DPSummaryRow(
                              'Estimated exchange rate',
                              '1 ${c.currency} ≈ ${DP.naira(c.rate)}',
                            ),
                            DPSummaryRow('Airtime value', DP.naira(_naira)),
                            const DPSummaryRow('Service fee', '₦0.00'),
                            DPSummaryRow(
                              'You pay',
                              DP.naira(_naira),
                              strong: true,
                            ),
                            DPSummaryRow(
                              'Wallet balance',
                              DP.naira(MockUser.walletBalance),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const DPBanner(
                        'Indicative quote. Rates may change before payment. Confirm the country and network; airtime can\'t be reversed once delivered.',
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
          label: 'Review international top-up',
          icon: DPIcons.forward,
          onPressed: _openReview,
        ),
      ),
    );
  }
}
