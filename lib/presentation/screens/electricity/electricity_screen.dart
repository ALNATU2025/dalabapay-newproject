// lib/presentation/screens/electricity/electricity_screen.dart
// Provider, meter type, meter number (POST /api/services/electricity/verify),
// amount → review → POST /api/services/electricity. The token comes back on
// the receipt.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
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
  final _phoneController =
      TextEditingController(text: Session.instance.user?.phone ?? '');

  String? _selectedProvider;
  String? _selectedMeterType;
  int? _selectedQuickAmount;
  bool _isValidating = false;
  bool _isValidated = false;
  String _customerName = '';
  String _customerAddress = '';

  /// label ("Ikeja Electric (IKEDC)") → provider id.
  Map<String, String> _discos = {};
  ServiceLimit _limit = const ServiceLimit(minimum: 1000);

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final list = asList(await api.get('/api/services/electricity/providers'));
      if (!mounted) return;
      setState(() => _discos = {
            for (final d in list)
              (d['shortName'] != null
                  ? '${d['name']} (${d['shortName']})'
                  : str(d['name'])): str(d['id']),
          });
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
    final limit = await Catalog.limitFor('electricity');
    if (mounted) setState(() => _limit = limit);
  }

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
    FocusScope.of(context).unfocus();
    setState(() => _isValidating = true);
    try {
      final r = asMap(await api.post('/api/services/electricity/verify', {
        'provider': _discos[_selectedProvider],
        'meterNumber': _meterController.text.trim(),
        'meterType': _selectedMeterType,
      }));
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isValidated = true;
        _customerName = str(r['customerName']);
        _customerAddress = str(r['address']);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      dpSnack(context, errorMessage(e), error: true);
    }
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
    final limitError = _limit.check(amount, DP.naira);
    if (limitError != null) {
      dpSnack(context, limitError, error: true);
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      dpSnack(context, 'Enter the 11-digit phone number for the token', error: true);
      return;
    }
    final providerId = _discos[_selectedProvider]!;
    final meter = _meterController.text.trim();
    final meterType = _selectedMeterType!;
    showReviewAndPay(
      context,
      icon: DPIcons.bolt,
      title: _selectedProvider!,
      serviceLabel: 'Electricity',
      amount: amount,
      service: 'electricity',
      rows: [
        DPReviewRow('Customer', _customerName),
        DPReviewRow('Meter number', _meterController.text.trim()),
        DPReviewRow('Meter type', _meterLabels[_selectedMeterType]!),
        DPReviewRow('Token sent to', _phoneController.text.trim()),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(amount), strong: true),
      ],
      successRows: [
        DPReviewRow('Provider', _selectedProvider!),
        DPReviewRow('Meter number', meter),
      ],
      resultRows: (txn) {
        final m = asMap(txn['metadata']);
        return [
          if (m['token'] != null) DPReviewRow('Token', str(m['token'])),
          if (m['units'] != null) DPReviewRow('Units', str(m['units'])),
        ];
      },
      footnote: 'Check the meter number. Electricity tokens can\'t be reversed.',
      onPay: (pin) async {
        final r = await api.post('/api/services/electricity', {
          'provider': providerId,
          'meterNumber': meter,
          'meterType': meterType,
          'amount': amount,
          'phone': phone,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final canVerify = !_isValidating &&
        _meterController.text.trim().length >= 6 &&
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
                    const DPServiceBanner(
                      title: 'Pay electricity and get your token instantly.',
                      subtitle: 'Prepaid and postpaid meters on every disco.',
                      icon: DPIcons.bolt,
                      image: DPAssets.svcElectricity,
                      style: DPBannerStyle.green,
                      tag: 'Electricity',
                    ),
                    const SizedBox(height: 20),
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
                          items: _discos.keys.toList(),
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
                                    _customerName,
                                    style: TextStyle(
                                      color: DP.green,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_customerAddress.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Text(
                                      _customerAddress,
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
                    DPHelper(_limit.describe(DP.naira)),
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
