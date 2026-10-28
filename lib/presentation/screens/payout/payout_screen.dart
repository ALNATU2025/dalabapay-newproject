// lib/presentation/screens/payout/payout_screen.dart
// Send money to a bank account or mobile money wallet, at home or in
// another country (through Cashwyre):
//   GET  /api/payouts/countries
//   GET  /api/payouts/banks?country=&type=bank|mobile_money
//   POST /api/payouts/lookup   (account name, as the number is typed)
//   POST /api/payouts/fee      (Cashwyre's fee and rate, as the amount is typed)
//   POST /api/payouts/quote    (price in the sender's currency)
//   POST /api/payouts/send     (quote + PIN)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';
import 'payout_onboarding.dart';

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
  final _amount = TextEditingController(); // what they receive (their currency)
  final _youSend = TextEditingController(); // what you pay in total (Leones)
  bool _typedInMine = false; // the last amount typed was in Leones
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
  String? _verifiedName; // from the bank / provider
  bool _lookupFailed = false;
  Timer? _lookupTimer;
  int _lookupSeq = 0;
  Map<String, dynamic>? _fee; // fee preview
  String? _feeError;
  bool _feeLoading = false;
  Timer? _feeTimer;
  int _feeSeq = 0;

  bool get _sl => Session.instance.isSierraLeone;
  String get _service => _sl ? 'sl_payout' : 'payout';
  String get _currency => str(_country?['currency']);

  @override
  void initState() {
    super.initState();
    _load();
    // First visit: a short introduction to banks and mobile money.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final go = await PayoutOnboarding.showIfNeeded(context);
      if (!go && mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _lookupTimer?.cancel();
    _feeTimer?.cancel();
    _name.dispose();
    _amount.dispose();
    _youSend.dispose();
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
      _resetName();
    });
    _loadBanks();
    _loadFee();
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
      subtitleOf: (c) => c['available'] == false
          ? '${str(c['currency'])} · Unavailable right now'
          : [
              str(c['currency']),
              if (c['bank'] != false) 'Bank',
              if (c['mobileMoney'] != false) 'Mobile money',
            ].join(' · '),
      leadingOf: (c) => countryFlag(str(c['code'])),
      selected: _country,
      searchable: true,
    );
    if (c == null || !mounted) return;
    if (c['available'] == false) {
      dpSnack(context, 'Transfers to ${str(c['name'])} aren\'t available right now. Please try again later.', error: true);
      return;
    }
    _selectCountry(c);
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
        _resetName();
      });
      _lookup();
    }
  }

  String get _cleanNumber => _number.text.replaceAll(RegExp(r'[\s-]'), '');

  void _resetName() {
    _lookupTimer?.cancel();
    _lookupSeq++;
    _lookedUpFor = null;
    _verifiedName = null;
    _lookupFailed = false;
    _lookingUp = false;
  }

  /// As the number is typed: wait a moment, then ask for the name.
  void _numberChanged(String _) {
    setState(_resetName);
    if (_cleanNumber.length >= 7) {
      _lookupTimer = Timer(const Duration(milliseconds: 700), _lookup);
    }
  }

  /// Fills the account holder's name from the bank / mobile money provider.
  Future<void> _lookup() async {
    final b = _bank;
    final c = _country;
    final n = _cleanNumber;
    if (b == null || c == null || n.length < 6) return;
    final key = '${c['code']}:${b['code']}:$n';
    if (_lookedUpFor == key) return;
    final seq = ++_lookupSeq;
    setState(() {
      _lookingUp = true;
      _lookupFailed = false;
    });
    try {
      final r = asMap(await api.post('/api/payouts/lookup', {
        'country': c['code'],
        'bankCode': b['code'],
        'accountNumber': n,
      }));
      if (!mounted || seq != _lookupSeq) return;
      final name = str(r['accountName']);
      setState(() {
        _lookedUpFor = key;
        _verifiedName = name.isEmpty ? null : name;
        _lookupFailed = name.isEmpty;
        if (name.isNotEmpty) _name.text = name;
      });
    } catch (_) {
      if (mounted && seq == _lookupSeq) setState(() => _lookupFailed = true);
    } finally {
      if (mounted && seq == _lookupSeq) setState(() => _lookingUp = false);
    }
  }

  /// As the amount is typed: Cashwyre's fee and rate, and the total.
  void _amountChanged(String _) {
    _typedInMine = false;
    _feeTimer?.cancel();
    _feeTimer = Timer(const Duration(milliseconds: 600), _loadFee);
  }

  /// Typed in Leones: Cashwyre converts it and the recipient's amount fills in.
  void _youSendChanged(String _) {
    _typedInMine = true;
    _feeTimer?.cancel();
    _feeTimer = Timer(const Duration(milliseconds: 600), _loadFee);
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _loadFee() async {
    final c = _country;
    final mine = _typedInMine;
    final amount = double.tryParse((mine ? _youSend : _amount).text) ?? 0;
    final seq = ++_feeSeq;
    if (c == null || amount <= 0) {
      setState(() {
        _fee = null;
        _feeError = null;
        _feeLoading = false;
        if (mine) {
          _amount.clear();
        } else {
          _youSend.clear();
        }
      });
      return;
    }
    setState(() => _feeLoading = true);
    try {
      final r = asMap(await api.post('/api/payouts/fee', {
        'country': c['code'],
        mine ? 'sendAmount' : 'amount': amount,
        'accountType': _type,
      }));
      if (!mounted || seq != _feeSeq) return;
      setState(() {
        _fee = r;
        _feeError = null;
        _feeLoading = false;
        // Fill in the other amount.
        if (mine) {
          _amount.text = _plain(toDouble(r['sendAmount']));
        } else {
          _youSend.text = toDouble(r['total']).toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (!mounted || seq != _feeSeq) return;
      setState(() {
        _fee = null;
        _feeError = errorMessage(e);
        _feeLoading = false;
      });
    }
  }

  /// Rows explaining the cost (form preview and review): what arrives,
  /// the service fee, the rate and the total.
  List<DPReviewRow> _breakdownRows(Map<String, dynamic> b) {
    final send = str(b['sendCurrency']);
    final cw = asMap(b['cashwyre']);
    final cross = send != DP.currency;
    final serviceFee = toDouble(cw['feeInYourCurrency']) + toDouble(b['dalabapayFee']);
    return [
      DPReviewRow('They receive', moneyCode(toDouble(b['sendAmount']), send)),
      if (cross) DPReviewRow('Amount in ${DP.currency == 'SLE' ? 'Leones' : 'Naira'}', DP.naira(toDouble(b['amountInYourCurrency']))),
      DPReviewRow('Service fee', DP.naira(serviceFee)),
      if (cross && b['rate'] != null) DPReviewRow('Rate', '1 $send = ${DP.naira(toDouble(b['rate']))}'),
      DPReviewRow('Total to pay', DP.naira(toDouble(b['total'])), strong: true),
    ];
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
    } else if (_lookingUp) {
      err = 'Checking the account name… one moment';
    } else if (_verifiedName == null && _name.text.trim().length < 2) {
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
        if (_name.text.trim().length >= 2) 'accountName': _verifiedName ?? _name.text.trim(),
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
    final method = _type == 'bank' ? 'Bank account' : 'Mobile money';
    final txn = await showReviewAndPay(
      context,
      icon: _type == 'bank' ? DPIcons.bank : DPIcons.smartphone,
      title: 'Send to ${str(q['accountName'])}',
      serviceLabel: 'Transfer · ${str(q['countryName'])}',
      amount: charge,
      service: _service,
      rows: [
        DPReviewRow('Recipient', '${str(q['accountName'])}${q['nameVerified'] == true ? ' ✓' : ''}'),
        DPReviewRow(method, '${str(q['bankName'])} · ${str(q['accountNumber'])}'),
        DPReviewRow('Country', str(q['countryName'])),
        ...(q['breakdown'] is Map
            ? _breakdownRows(asMap(q['breakdown']))
            : [
                DPReviewRow('They receive', moneyCode(toDouble(q['amount']), sendCode)),
                DPReviewRow('Total to pay', DP.naira(charge), strong: true),
              ]),
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
      _youSend.clear();
      _fee = null;
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
              title: 'Send money',
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
          DPServiceBanner(
            title: 'Send money globally.',
            subtitle: 'Banks and mobile money in ${_countries.length} countries. Select the country you want to send to.',
            icon: DPIcons.globe,
            image: DPAssets.svcSendMoney,
            style: DPBannerStyle.ocean,
            tag: 'Send money',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final step in const ['Country', 'Recipient', 'Amount', 'Pay'])
                Expanded(
                  child: Column(
                    children: [
                      Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: DP.green.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(DP.rPill))),
                      const SizedBox(height: 6),
                      Text(step, style: DP.tiny),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
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
                  _resetName();
                });
                _loadBanks();
                _loadFee();
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
            onChanged: _numberChanged,
            onSubmitted: (_) => _lookup(),
            suffix: _lookingUp
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _verifiedName != null
                    ? const Padding(padding: EdgeInsets.all(12), child: Icon(DPIcons.checkCircle, color: DP.green))
                    : IconButton(
                        tooltip: 'Check name',
                        icon: Icon(DPIcons.search, color: DP.muted),
                        onPressed: _lookup,
                      ),
          ),
          if (_lookingUp)
            const DPHelper('Checking the account name…')
          else if (_verifiedName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DPCard(
                color: DP.mint,
                borderColor: DP.green,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const Icon(DPIcons.shieldCheck, color: DP.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_verifiedName!, style: DP.bodyStrong.copyWith(color: DP.green)),
                          Text(isBank ? 'Name confirmed by the bank' : 'Name confirmed by ${str(_bank?['name'], 'the provider')}', style: DP.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_verifiedName == null) ...[
            const SizedBox(height: 18),
            const DPLabel('Account holder\'s name'),
            DPField(
              controller: _name,
              hint: _sl ? 'Fatmata Kamara' : 'Full name on the account',
              textCapitalization: TextCapitalization.words,
            ),
            if (_lookupFailed)
              const DPHelper('We couldn\'t confirm the name automatically. Type it exactly as it is on the account.')
            else if (!isBank)
              const DPHelper('Use the exact name registered on the mobile money wallet.'),
          ],
          const SizedBox(height: 18),
          DPLabel('You send (${DP.currency == 'SLE' ? 'Leones' : 'Naira'})'),
          DPField(
            controller: _youSend,
            hint: '0.00',
            prefixText: DP.currency == 'SLE' ? 'Le ' : '₦ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            onChanged: _youSendChanged,
          ),
          const DPHelper('Enter how much you want to spend, fees included — or type what they should receive below.'),
          const SizedBox(height: 14),
          DPLabel('They receive${_currency.isEmpty ? '' : ' ($_currency)'}'),
          DPField(
            controller: _amount,
            hint: '0.00',
            prefixText: _currency.isEmpty ? null : '$_currency ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            onChanged: _amountChanged,
          ),
          if (_feeLoading && _fee == null)
            const DPHelper('Working out the fees…')
          else if (_feeError != null)
            DPHelper(_feeError!, color: DP.red)
          else if (_fee != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: DPCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  children: [
                    for (final r in _breakdownRows(_fee!)) DPSummaryRow(r.label, r.value, strong: r.strong),
                    const SizedBox(height: 4),
                    Text('The service fee and rate are included in your total.', style: DP.tiny),
                  ],
                ),
              ),
            )
          else
            const DPHelper('Type an amount to see the converted amount, service fee, rate and your total.'),
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
