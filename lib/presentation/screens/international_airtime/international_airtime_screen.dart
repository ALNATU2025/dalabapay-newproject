// lib/presentation/screens/international_airtime/international_airtime_screen.dart
// Country → type → network → plan/amount, all from
// /api/services/international/*, priced with the provider's exchange rate;
// payment is POST /api/services/international.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';

class _Country {
  final String code, name, flag, dialCode, currency;
  const _Country(this.code, this.name, this.flag, this.dialCode, this.currency);
  factory _Country.fromJson(Map<String, dynamic> j) => _Country(
        str(j['code']),
        str(j['name']),
        str(j['flag']),
        str(j['dialCode']),
        str(j['currency']),
      );

  @override
  bool operator ==(Object other) => other is _Country && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class InternationalAirtimeScreen extends StatefulWidget {
  const InternationalAirtimeScreen({super.key});

  @override
  State<InternationalAirtimeScreen> createState() =>
      _InternationalAirtimeScreenState();
}

class _InternationalAirtimeScreenState
    extends State<InternationalAirtimeScreen> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _email = TextEditingController();

  List<_Country> _countries = [];
  Map<String, String> _types = {}; // name → id
  Map<String, String> _operators = {}; // name → id
  List<Map<String, dynamic>> _variations = [];
  double _rate = 0;
  bool _loadingStep = false;

  _Country? _country;
  String? _type;
  String? _operator;
  Map<String, dynamic>? _variation;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _loadCountries();
  }

  Future<T?> _step<T>(Future<T> Function() call) async {
    setState(() => _loadingStep = true);
    try {
      return await call();
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
      return null;
    } finally {
      if (mounted) setState(() => _loadingStep = false);
    }
  }

  Future<void> _loadCountries() async {
    final r = await _step(() => api.get('/api/services/international/countries'));
    if (r == null || !mounted) return;
    setState(() => _countries = asList(r).map(_Country.fromJson).toList());
  }

  Future<void> _loadTypes() async {
    final c = _country!;
    final r = await _step(() => api.get('/api/services/international/product-types',
        query: {'country': c.code}));
    if (r == null || !mounted || _country != c) return;
    setState(() => _types = {for (final t in asList(r)) str(t['name']): str(t['id'])});
  }

  Future<void> _loadOperators() async {
    final c = _country!;
    final type = _types[_type]!;
    final r = await _step(() => api.get('/api/services/international/operators',
        query: {'country': c.code, 'productType': type}));
    if (r == null || !mounted || _country != c) return;
    setState(() => _operators = {for (final o in asList(r)) str(o['name']): str(o['id'])});
  }

  Future<void> _loadVariations() async {
    final c = _country!;
    final r = await _step(() => api.get('/api/services/international/variations', query: {
          'country': c.code,
          'operator': _operators[_operator],
          'productType': _types[_type],
        }));
    if (r == null || !mounted || _country != c) return;
    final m = asMap(r);
    setState(() {
      _rate = toDouble(m['rate']);
      _variations = asList(m['variations']);
      _variation = _variations.length == 1 ? _variations.first : null;
    });
  }

  bool get _fixed => _variation?['fixed'] == true;
  double get _min => toDouble(_variation?['min']);
  double get _max => toDouble(_variation?['max']);

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    _email.dispose();
    super.dispose();
  }

  double get _foreign => _fixed
      ? toDouble(_variation?['amount'])
      : (double.tryParse(_amount.text.trim()) ?? 0);
  double get _naira => _foreign * _rate;

  String _money(String cur, double v) => '$cur ${v.toStringAsFixed(2)}';

  void _openReview() {
    if (_country == null || _type == null || _operator == null) {
      dpSnack(context, 'Choose a country, type and network', error: true);
      return;
    }
    if (_variation == null) {
      dpSnack(context, 'Choose a plan', error: true);
      return;
    }
    if (_phone.text.trim().length < 5 || _foreign <= 0) {
      dpSnack(context, 'Enter the phone number and amount', error: true);
      return;
    }
    if (!_fixed && (_foreign < _min || (_max > 0 && _foreign > _max))) {
      dpSnack(context, 'Enter an amount between ${_money(_country!.currency, _min)} and ${_money(_country!.currency, _max)}', error: true);
      return;
    }
    final c = _country!;
    final body = <String, dynamic>{
      'country': c.code,
      'productType': _types[_type],
      'operator': _operators[_operator],
      'variationCode': str(_variation!['code']),
      'phone': _phone.text.trim(),
      if (!_fixed) 'amount': _foreign,
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
    };
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
        if (_fixed) DPReviewRow('Plan', str(_variation!['name'])),
        DPReviewRow('Exchange rate', '1 ${c.currency} ≈ ${DP.naira(_rate)}'),
        const DPReviewRow('Service fee', '₦0.00'),
        DPReviewRow('You pay', DP.naira(_naira), strong: true),
      ],
      footnote: 'International airtime can\'t be reversed once delivered.',
      onPay: (pin) async {
        final r = await api.post('/api/services/international', {...body, 'pin': pin});
        return asMap(asMap(r)['transaction']);
      },
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
                        final picked = await dpPickFromList<_Country>(
                          context,
                          title: 'Destination country',
                          items: _countries,
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
                          _variation = null;
                          _types = {};
                          _operators = {};
                          _variations = [];
                        });
                        _loadTypes();
                      },
                    ),
                    if (_loadingStep) const LinearProgressIndicator(color: DP.green),
                    if (c != null) ...[
                      const SizedBox(height: 16),
                      const DPLabel('Top-up type'),
                      DPChipRow(
                        options: _types.keys.toList(),
                        selected: _type,
                        height: 46,
                        onSelect: (t) {
                          setState(() {
                            _type = t;
                            _operator = null;
                            _variation = null;
                            _operators = {};
                            _variations = [];
                          });
                          _loadOperators();
                        },
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
                            items: _operators.keys.toList(),
                            selected: _operator,
                            labelOf: (x) => x,
                          );
                          if (picked == null || !mounted) return;
                          setState(() {
                            _operator = picked;
                            _variation = null;
                            _variations = [];
                          });
                          _loadVariations();
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
                      if (_variations.length > 1) ...[
                        const SizedBox(height: 16),
                        const DPLabel('Choose a plan'),
                        for (final v in _variations)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DPCard(
                              color: _variation == v ? DP.mint : DP.surface,
                              borderColor: _variation == v ? DP.green : DP.border,
                              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                              onTap: () => setState(() => _variation = v),
                              child: Row(
                                children: [
                                  Expanded(child: Text(str(v['name']), style: DP.bodyStrong)),
                                  if (v['fixed'] == true)
                                    Text(
                                      _money(c.currency, toDouble(v['amount'])),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: DP.green,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (_variations.isEmpty && !_loadingStep)
                        DPLoadError(error: null, onRetry: _loadVariations),
                      if (_variation != null && !_fixed) ...[
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
                        'Minimum ${_money(c.currency, _min)} · Maximum ${_money(c.currency, _max)}',
                      ),
                      ],
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
                              '1 ${c.currency} ≈ ${DP.naira(_rate)}',
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
                              DP.naira(Session.instance.user?.balance ?? 0),
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
