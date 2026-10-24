// lib/presentation/screens/airtime/airtime_screen.dart
// Network, phone, amount → review → POST /api/services/airtime.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
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

  /// name → id ("MTN" → "mtn") from GET /api/services/networks.
  Map<String, String> _networkIds = const {
    'MTN': 'mtn',
    'Airtel': 'airtel',
    'Glo': 'glo',
    '9mobile': '9mobile',
  };
  List<Map<String, String>> _recent = [];
  ServiceLimit _limit = const ServiceLimit(minimum: 50, perTxn: 50000);

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
    final limit = await Catalog.limitFor('airtime');
    final recent = await Catalog.recentRecipients('airtime');
    if (!mounted) return;
    setState(() {
      _limit = limit;
      _recent = [
        for (final t in recent)
          {
            'phone': str(t['recipient']),
            'network': str(asMap(t['metadata'])['network']),
          },
      ];
    });
  }

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
    final limitError = _limit.check(amount, DP.naira);
    if (limitError != null) {
      dpSnack(context, limitError, error: true);
      return;
    }
    final network = _selectedNetwork!;
    final networkId = _networkIds[network] ?? network.toLowerCase();
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
      onPay: (pin) async {
        final r = await api.post('/api/services/airtime', {
          'network': networkId,
          'phone': phone,
          'amount': amount,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
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
const DPServiceBanner(
                      title: 'Top up airtime in seconds.',
                      subtitle: 'MTN, Airtel, Glo and 9mobile — any Nigerian number.',
                      icon: DPIcons.smartphone,
                      image: DPAssets.svcAirtime,
                      style: DPBannerStyle.navy,
                      tag: 'Airtime',
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Choose network'),
                    DPChipRow(
                      options: _networkIds.keys.toList(),
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
                      style: TextStyle(
                        fontSize: 17,
                        color: DP.ink,
                        letterSpacing: 0.4,
                      ),
                      suffix: IconButton(
                        tooltip: 'Use my number',
                        icon: Icon(DPIcons.contact, color: DP.muted),
                        onPressed: () => setState(() {
                          final mine = Session.instance.user?.phone ?? '';
                          _phoneController.text = mine;
                          _autoDetectNetwork(mine);
                        }),
                      ),
                    ),
                    if (_selectedNetwork != null && phone.length >= 4)
                      DPHelper('$_selectedNetwork Nigeria'),
                    if (_recent.isNotEmpty) const SizedBox(height: 14),
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
                            onTap: () => setState(() {
                              _phoneController.text = c['phone']!;
                              if (_networkIds.containsKey(c['network'])) {
                                _selectedNetwork = c['network'];
                              }
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
                      style: TextStyle(fontSize: 17, color: DP.ink),
                    ),
                    DPHelper(_limit.describe(DP.naira)),
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
