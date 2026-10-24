// lib/presentation/screens/sierra_leone/sl_electricity_screen.dart
// EDSA prepaid electricity: meter → verify → amount → review.
//   POST /api/services/sl/electricity/verify   { meterNumber }
//   POST /api/services/sl/electricity          { meterNumber, amount, phone?, pin }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';
import 'sl_common.dart';

class SlElectricityScreen extends StatefulWidget {
  const SlElectricityScreen({super.key});

  @override
  State<SlElectricityScreen> createState() => _SlElectricityScreenState();
}

class _SlElectricityScreenState extends State<SlElectricityScreen> with SlAvailability {
  final _meter = TextEditingController();
  final _amount = TextEditingController();
  Map<String, dynamic>? _customer;
  bool _verifying = false;
  ServiceLimit _limit = const ServiceLimit(minimum: 20);

  static const _quick = [50, 100, 200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    checkAvailability('sl_electricity');
    Catalog.limitFor('sl_electricity').then((l) {
      if (mounted) setState(() => _limit = l);
    });
  }

  @override
  void dispose() {
    _meter.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);
    try {
      final r = asMap(await api.post('/api/services/sl/electricity/verify', {'meterNumber': _meter.text.trim()}));
      if (!mounted) return;
      setState(() {
        _customer = r;
        _verifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  double get _value => double.tryParse(_amount.text) ?? 0;

  void _review() {
    if (_customer == null) {
      dpSnack(context, 'Verify the meter number first', error: true);
      return;
    }
    final err = _limit.check(_value, DP.naira);
    if (err != null) {
      dpSnack(context, err, error: true);
      return;
    }
    final meter = _meter.text.trim();
    showReviewAndPay(
      context,
      icon: DPIcons.bolt,
      title: 'EDSA electricity',
      serviceLabel: 'EDSA Prepaid',
      amount: _value,
      service: 'sl_electricity',
      rows: [
        DPReviewRow('Meter number', meter),
        DPReviewRow('Customer', str(_customer!['customerName'])),
        if (_customer!['address'] != null) DPReviewRow('Address', str(_customer!['address'])),
        DPReviewRow('Amount', DP.naira(_value)),
        DPReviewRow('Total to pay', DP.naira(_value), strong: true),
      ],
      footnote: 'Your token appears on the receipt and in History.',
      resultRows: (txn) {
        final meta = asMap(txn['metadata']);
        return [
          if (meta['token'] != null) DPReviewRow('Token', str(meta['token']), strong: true),
          if (meta['units'] != null) DPReviewRow('Units', str(meta['units'])),
        ];
      },
      onPay: (pin) async {
        final r = await api.post('/api/services/sl/electricity', {
          'meterNumber': meter,
          'amount': _value,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quick = _quick.map((a) => DP.naira(a, decimals: false)).toList();
    final selectedQuick = _quick.contains(_value.toInt()) && _value == _value.roundToDouble()
        ? DP.naira(_value.toInt(), decimals: false)
        : null;
    final canVerify = _meter.text.trim().length >= 6 && !_verifying;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'EDSA electricity',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPServiceBanner(
                      title: 'Buy EDSA units and get your token instantly.',
                      subtitle: 'Prepaid electricity, any time of day — in Leones.',
                      icon: DPIcons.bolt,
                      image: DPAssets.svcElectricity,
                      style: DPBannerStyle.green,
                      tag: 'EDSA Electricity',
                    ),
                    const SizedBox(height: 20),
                    if (!slConnected) const SlComingSoon('EDSA electricity'),
                    DPLabel(
                      'Meter number',
                      trailing: _customer != null
                          ? null
                          : DPTextLink(
                              label: _verifying ? 'Checking…' : 'Verify',
                              color: canVerify ? DP.green : DP.faint,
                              onTap: canVerify ? _verify : null,
                            ),
                    ),
                    DPField(
                      controller: _meter,
                      hint: 'EDSA meter number',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      onChanged: (_) => setState(() => _customer = null),
                      suffix: Icon(
                        _customer != null ? DPIcons.checkCircle : DPIcons.bolt,
                        color: _customer != null ? DP.green : DP.muted,
                      ),
                    ),
                    if (_customer != null) ...[
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
                                Text('Meter verified', style: DP.bodyStrong.copyWith(color: DP.green)),
                              ]),
                              const SizedBox(height: 6),
                              DPSummaryRow('Customer name', str(_customer!['customerName'])),
                              DPSummaryRow('Meter number', _meter.text.trim()),
                              if (_customer!['address'] != null) DPSummaryRow('Address', str(_customer!['address'])),
                              const DPSummaryRow('Distributor', 'EDSA'),
                            ],
                          ),
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
                      if (_value > 0) ...[
                        const SizedBox(height: 16),
                        DPCard(
                          color: DP.mint,
                          borderColor: DP.mintLine,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: DPSummaryRow('Amount to pay', DP.naira(_value), strong: true, valueColor: DP.green),
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
          label: 'Continue to review',
          icon: DPIcons.forward,
          onPressed: slConnected && _customer != null ? _review : null,
        ),
      ),
    );
  }
}
