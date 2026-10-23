// lib/presentation/screens/payout/payout_screen.dart
// Send money to a bank account or mobile money wallet, at home or in
// another country (through Cashwyre):
//   GET  /api/payouts/countries
//   GET  /api/payouts/banks?country=&type=bank|mobile_money
//   POST /api/payouts/lookup   (account name, where supported)
//   POST /api/payouts/quote    (price in the sender's currency)
//   POST /api/payouts/send     (quote + PIN)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';

/// "GHS 1,250.00" for any currency code.
String moneyCode(num? value, String code) {
  if (code == 'NGN' || code == 'SLE') return DP.moneyIn(value, code);
  final s = DP.moneyIn(value, 'NGN').replaceFirst('₦', '');
  return '$code $s';
}

/// Flag for a two-letter country code (drawn for Nigeria and Sierra Leone).
Widget countryFlag(String code, {double size = 24}) {
  if (code == 'NG' || code == 'SL') return DPFlag(code, width: size);
  final up = code.toUpperCase();
  if (up.length != 2) return Icon(DPIcons.globe, size: size * 0.8, color: DP.muted);
  final emoji = String.fromCharCodes(up.codeUnits.map((c) => 0x1F1E6 + c - 65));
  return SizedBox(
    width: size,
    child: Text(emoji, textAlign: TextAlign.center, style: TextStyle(fontSize: size * 0.8, height: 1)),
  );
}

class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  bool _loading = true;
  Object? _error;
  bool _connected = true;
  List<Map<String, dynamic>> _countries = [];
  Map<String, dynamic>? _country;
  String _type = 'bank'; // bank | mobile_money
  List<Map<String, dynamic>> _banks = [];
  bool _banksLoading = false;
  Map<String, dynamic>? _bank;
  bool _lookingUp = false;
  bool _quoting = false;
  String? _lookedUpFor;

  bool get _sl => Session.instance.isSierraLeone;
  String get _service => _sl ? 'sl_payout' : 'payout';
  String get _currency => str(_country?['currency']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _has(Map<String, dynamic> c, String type) =>
      (type == 'bank' ? c['bank'] : c['mobileMoney']) != false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = asMap(await api.get('/api/payouts/countries'));
      final list = asList(r['countries']);
      if (!mounted) return;
      final home = Session.instance.isSierraLeone ? 'SL' : 'NG';
      setState(() {
        _connected = r['connected'] != false;
        _countries = list;
        _loading = false;
      });
      final start = list.where((c) => c['code'] == home).toList();
      if (start.isNotEmpty) _selectCountry(start.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _selectCountry(Map<String, dynamic> c) {
    var type = _type;
    if (!_has(c, type)) type = type == 'bank' ? 'mobile_money' : 'bank';
    setState(() {
      _country = c;
      _type = type;
      _bank = null;
      _lookedUpFor = null;
    });
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    final c = _country;
    if (c == null) return;
    setState(() {
      _banksLoading = true;
      _banks = [];
      _bank = null;
    });
    try {
      final r = await api.get('/api/payouts/banks', query: {'country': c['code'], 'type': _type});
      if (!mounted) return;
      setState(() {
        _banks = asList(r);
        _banksLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _banksLoading = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _pickCountry() async {
    final c = await dpPickFromList<Map<String, dynamic>>(
      context,
      title: 'Send to which country?',
      items: _countries,
      labelOf: (c) => str(c['name']),
      subtitleOf: (c) => [
        str(c['currency']),
        if (c['bank'] != false) 'Bank',
        if (c['mobileMoney'] != false) 'Mobile money',
      ].join(' · '),
      leadingOf: (c) => countryFlag(str(c['code'])),
      selected: _country,
      searchable: true,
    );
    if (c != null) _selectCountry(c);
  }

  Future<void> _pickBank() async {
    final b = await dpPickFromList<Map<String, dynamic>>(
      context,
      title: _type == 'bank' ? 'Choose bank' : 'Choose mobile money',
      items: _banks,
      labelOf: (b) => str(b['name']),
      selected: _bank,
      searchable: _banks.length > 8,
    );
    if (b != null) {
      setState(() {
        _bank = b;
        _lookedUpFor = null;
      });
      _lookup();
    }
  }

  String get _cleanNumber => _number.text.replaceAll(RegExp(r'[\s-]'), '');

  /// Fills the account name when the country supports a name check.
  Future<void> _lookup() async {
    final b = _bank;
    final c = _country;
    final n = _cleanNumber;
    if (b == null || c == null || n.length < 6) return;
    final key = '${c['code']}:${b['code']}:$n';
    if (_lookedUpFor == key) return;
    setState(() => _lookingUp = true);
    try {
      final r = asMap(await api.post('/api/payouts/lookup', {
        'country': c['code'],
        'bankCode': b['code'],
        'accountNumber': n,
      }));
      if (!mounted) return;
      final name = str(r['accountName']);
      setState(() {
        _lookedUpFor = key;
        if (name.isNotEmpty) _name.text = name;
      });
    } catch (_) {
      // The name can be typed in.
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    final c = _country;
    final b = _bank;
    final amount = double.tryParse(_amount.text) ?? 0;
    String? err;
    if (c == null) {
      err = 'Choose a country';
    } else if (b == null) {
      err = _type == 'bank' ? 'Choose the bank' : 'Choose the mobile money provider';
    } else if (_cleanNumber.length < 5) {
      err = _type == 'bank' ? 'Enter the account number' : 'Enter the mobile money number';
    } else if (_name.text.trim().length < 2) {
      err = 'Enter the account holder\'s name';
    } else if (amount <= 0) {
      err = 'Enter the amount to send';
    }
    if (err != null) {
      dpSnack(context, err, error: true);
      return;
    }
    setState(() => _quoting = true);
    Map<String, dynamic> q;
    try {
      q = asMap(await api.post('/api/payouts/quote', {
        'country': c!['code'],
        'accountType': _type,
        'bankCode': b!['code'],
        'accountNumber': _cleanNumber,
        'accountName': _name.text.trim(),
        'amount': amount,
        if (_note.text.trim().isNotEmpty) 'narration': _note.text.trim(),
      }));
    } catch (e) {
      if (mounted) {
        setState(() => _quoting = false);
        dpSnack(context, errorMessage(e), error: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _quoting = false);

    final charge = toDouble(q['charge']);
    final sendCode = str(q['currency']);
    final cross = sendCode != DP.currency;
    final method = _type == 'bank' ? 'Bank account' : 'Mobile money';
    final txn = await showReviewAndPay(
      context,
      icon: _type == 'bank' ? DPIcons.bank : DPIcons.smartphone,
      title: 'Send to ${str(q['accountName'])}',
      serviceLabel: 'Transfer · ${str(q['countryName'])}',
      amount: charge,
      service: _service,
      rows: [
        DPReviewRow('Recipient', str(q['accountName'])),
        DPReviewRow(method, '${str(q['bankName'])} · ${str(q['accountNumber'])}'),
        DPReviewRow('Country', str(q['countryName'])),
        DPReviewRow('They receive', moneyCode(toDouble(q['amount']), sendCode)),
        if (!cross && q['fee'] != null) DPReviewRow('Fee', DP.naira(toDouble(q['fee']))),
        if (cross && q['rate'] != null)
          DPReviewRow('Rate', '1 $sendCode = ${DP.naira(toDouble(q['rate']))} (fees included)'),
        DPReviewRow('Total to pay', DP.naira(charge), strong: true),
      ],
      footnote: 'Check the details. Money sent to the wrong account may not be recoverable. This price is held for 10 minutes.',
      successTitle: 'Transfer sent',
      successSubtitle: 'The money is on its way. We\'ll notify you when it arrives.',
      onPay: (pin) async {
        final r = await api.post('/api/payouts/send', {'quoteToken': q['quoteToken'], 'pin': pin});
        return asMap(asMap(r)['transaction']);
      },
    );
    if (txn != null && mounted && str(txn['status']) != 'failed') {
      _amount.clear();
      _note.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Bank & mobile money',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: _loading || _error != null || !_connected
          ? null
          : DPBottomAction(
              child: DPButton(
                label: 'Continue to review',
                icon: DPIcons.forward,
                loading: _quoting,
                onPressed: _quoting ? null : _review,
              ),
            ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: DPSkeletonList(rows: 5));
    }
    if (_error != null) return DPLoadError(error: _error, onRetry: _load);
    if (!_connected || _countries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: DPBanner(
          'Sending to banks and mobile money is launching soon. Please check back later.',
          tone: DPTone.warning,
          icon: DPIcons.pending,
          title: 'Coming soon',
        ),
      );
    }
    final c = _country;
    final types = <String>[
      if (c == null || _has(c, 'bank')) 'bank',
      if (c == null || _has(c, 'mobile_money')) 'mobile_money',
    ];
    final typeIndex = types.indexOf(_type).clamp(0, types.length - 1);
    final isBank = _type == 'bank';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPHeadline(
            'Send money anywhere.',
            subtitle: 'To bank accounts and mobile money in ${_countries.length} countries. You pay in ${DP.currency == 'SLE' ? 'Leones' : 'Naira'}.',
          ),
          const DPLabel('Country'),
          DPSelectField(
            value: c == null ? null : '${str(c['name'])} (${str(c['currency'])})',
            hint: 'Choose a country',
            leading: c == null ? null : countryFlag(str(c['code'])),
            onTap: _pickCountry,
          ),
          const SizedBox(height: 18),
          if (types.length > 1) ...[
            DPSegmented(
              options: const ['Bank account', 'Mobile money'],
              index: typeIndex,
              onChanged: (i) {
                setState(() {
                  _type = types[i];
                  _lookedUpFor = null;
                });
                _loadBanks();
              },
            ),
            const SizedBox(height: 18),
          ] else if (c != null) ...[
            DPHelper(isBank
                ? 'Only bank transfers are available to ${str(c['name'])}.'
                : 'Only mobile money is available to ${str(c['name'])}.'),
            const SizedBox(height: 12),
          ],
          DPLabel(isBank ? 'Bank' : 'Mobile money provider'),
          DPSelectField(
            value: _bank == null ? null : str(_bank!['name']),
            hint: _banksLoading ? 'Loading…' : (isBank ? 'Choose bank' : 'Choose provider'),
            leading: Icon(isBank ? DPIcons.bank : DPIcons.smartphone, color: DP.muted, size: 20),
            enabled: !_banksLoading && _banks.isNotEmpty,
            onTap: _pickBank,
          ),
          if (!_banksLoading && _banks.isEmpty && c != null)
            const DPHelper('None available right now. Try the other option or another country.'),
          const SizedBox(height: 18),
          DPLabel(isBank ? 'Account number' : 'Mobile money number'),
          DPField(
            controller: _number,
            hint: isBank ? 'Account number' : (str(c?['code']) == 'SL' ? '076123456' : 'Phone number'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+ -]')),
              LengthLimitingTextInputFormatter(20),
            ],
            onChanged: (_) => _lookedUpFor = null,
            onSubmitted: (_) => _lookup(),
            suffix: _lookingUp
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Check name',
                    icon: Icon(DPIcons.search, color: DP.muted),
                    onPressed: _lookup,
                  ),
          ),
          const SizedBox(height: 18),
          const DPLabel('Account holder\'s name'),
          DPField(
            controller: _name,
            hint: _sl ? 'Fatmata Kamara' : 'Full name on the account',
            textCapitalization: TextCapitalization.words,
          ),
          if (!isBank) const DPHelper('Use the exact name registered on the mobile money wallet.'),
          const SizedBox(height: 18),
          DPLabel('Amount they receive${_currency.isEmpty ? '' : ' ($_currency)'}'),
          DPField(
            controller: _amount,
            hint: '0.00',
            prefixText: _currency.isEmpty ? null : '$_currency ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          ),
          const DPHelper('You\'ll see the total in your currency, with fees, before you pay.'),
          const SizedBox(height: 18),
          const DPLabel('Note (optional)'),
          DPField(
            controller: _note,
            hint: 'What it\'s for',
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
          ),
        ],
      ),
    );
  }
}
