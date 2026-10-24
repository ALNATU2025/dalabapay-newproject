// lib/presentation/screens/cards/create_card_screen.dart
// Request a new virtual dollar card: amount to load, brand, the card
// issuer's identity checks (date of birth, address, ID), then review and
// pay from the wallet.
//   GET  /api/cards/quote?action=create&amountUsd=
//   POST /api/cards
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';
import 'cards_screen.dart';

class CreateCardScreen extends StatefulWidget {
  final Map<String, dynamic> config;
  const CreateCardScreen({super.key, required this.config});

  @override
  State<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends State<CreateCardScreen> {
  final _amount = TextEditingController(text: '10');
  final _cardName = TextEditingController();
  final _house = TextEditingController();
  final _address = TextEditingController();
  final _idNumber = TextEditingController();

  String _brand = 'Visa';
  DateTime? _dob;
  String? _idType;
  String? _idImage; // base64
  Map<String, dynamic>? _quote;
  bool _quoting = false;
  Timer? _debounce;

  static const _quick = [10, 25, 50, 100];

  List<Map<String, dynamic>> get _idTypes => asList(widget.config['idTypes']);
  Map<String, dynamic>? get _idTypeInfo {
    final m = _idTypes.where((t) => t['id'] == _idType);
    return m.isEmpty ? null : m.first;
  }

  List<String> get _brands {
    final b = widget.config['brands'];
    return b is List && b.isNotEmpty ? b.map((e) => '$e').toList() : const ['Visa', 'Mastercard'];
  }

  bool get _needsImage => _idTypeInfo?['needsImage'] == true;
  bool get _sl => Session.instance.isSierraLeone;
  double get _minUsd => toDouble(widget.config['minUsd'] ?? 5);
  double get _maxUsd => toDouble(widget.config['maxUsd'] ?? 2000);

  @override
  void initState() {
    super.initState();
    final user = Session.instance.user;
    _cardName.text = user?.fullName ?? '';
    if (_idTypes.isNotEmpty) _idType = str(_idTypes.first['id']);
    _loadQuote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    _cardName.dispose();
    _house.dispose();
    _address.dispose();
    _idNumber.dispose();
    super.dispose();
  }

  double get _usd => double.tryParse(_amount.text) ?? 0;

  void _amountChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _loadQuote);
  }

  Future<void> _loadQuote() async {
    final v = _usd;
    if (v < _minUsd || v > _maxUsd) {
      setState(() => _quote = null);
      return;
    }
    setState(() => _quoting = true);
    try {
      final q = asMap(await api.get('/api/cards/quote', query: {'action': 'create', 'amountUsd': v}));
      if (mounted && _usd == v) setState(() => _quote = q);
    } catch (_) {
      if (mounted) setState(() => _quote = null);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        if (mounted) dpSnack(context, 'That photo is too large. Try again with a smaller one.', error: true);
        return;
      }
      setState(() => _idImage = base64Encode(bytes));
    } catch (e) {
      if (mounted) dpSnack(context, 'Couldn\'t open the photo: $e', error: true);
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    String? err;
    final v = _usd;
    if (v < _minUsd || v > _maxUsd) {
      err = 'Load between ${usd(_minUsd)} and ${usd(_maxUsd)}';
    } else if (_cardName.text.trim().length < 2) {
      err = 'Enter the name for the card';
    } else if (_dob == null) {
      err = 'Choose your date of birth';
    } else if (_house.text.trim().isEmpty) {
      err = 'Enter your house number';
    } else if (_address.text.trim().length < 5) {
      err = 'Enter your home address';
    } else if (_idType == null) {
      err = 'Choose your ID type';
    } else if (_idNumber.text.trim().length < 4) {
      err = 'Enter your ID number';
    } else if (_needsImage && _idImage == null) {
      err = 'Add a photo of your ${str(_idTypeInfo?['name'], 'ID')}';
    } else if (_quote == null) {
      err = 'Couldn\'t get the price. Please try again.';
    }
    if (err != null) {
      dpSnack(context, err, error: true);
      if (_quote == null) _loadQuote();
      return;
    }
    final q = _quote!;
    final local = toDouble(q['local']);
    final txn = await showReviewAndPay(
      context,
      icon: DPIcons.card,
      title: 'New $_brand dollar card',
      serviceLabel: 'Dollar card',
      amount: local,
      service: _sl ? 'sl_card' : 'card',
      rows: [
        DPReviewRow('Card', '$_brand · virtual'),
        DPReviewRow('Name on card', _cardName.text.trim()),
        DPReviewRow('Loaded on the card', usd(v)),
        DPReviewRow('Card creation fee', usd(toDouble(q['feeUsd']))),
        DPReviewRow('Rate', '\$1 = ${DP.naira(toDouble(q['rate']))}'),
        DPReviewRow('Total to pay', DP.naira(local), strong: true),
      ],
      footnote: 'Your details are sent to the card issuer for identity checks. Your ID number is not stored by Dalabapay.',
      successTitle: 'Card on its way',
      successSubtitle: 'Your dollar card is being created. It\'s usually ready within a minute.',
      onPay: (pin) async {
        final r = asMap(await api.post('/api/cards', {
          'amountUsd': v,
          'brand': _brand,
          'cardName': _cardName.text.trim(),
          'dateOfBirth': _iso(_dob!),
          'homeAddressNumber': _house.text.trim(),
          'homeAddress': _address.text.trim(),
          'idType': _idType,
          'idNumber': _idNumber.text.trim(),
          if (_needsImage && _idImage != null) 'idImageBase64': _idImage,
          'pin': pin,
        }));
        return asMap(r['transaction']);
      },
    );
    if (txn != null && mounted && str(txn['status']) != 'failed' && str(txn['status']) != 'refunded') {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quick = _quick.map((a) => usd(a)).toList();
    final selectedQuick = _quick.contains(_usd.toInt()) && _usd == _usd.roundToDouble() ? usd(_usd.toInt()) : null;
    final q = _quote;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'New dollar card'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPServiceBanner(
                      title: 'Your dollar card, ready in a minute.',
                      subtitle: 'Choose how much to load. You can add more any time.',
                      icon: DPIcons.card,
                      style: DPBannerStyle.sunset,
                      tag: 'New card',
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Amount to load'),
                    DPChipGrid(
                      options: quick,
                      selected: selectedQuick,
                      height: 46,
                      onSelect: (label) {
                        final i = quick.indexOf(label);
                        if (i >= 0) {
                          _amount.text = _quick[i].toString();
                          _amountChanged();
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    DPField(
                      controller: _amount,
                      hint: '0.00',
                      prefixText: '\$ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      onChanged: (_) => _amountChanged(),
                    ),
                    DPHelper(
                      _quoting
                          ? 'Working out the price…'
                          : q != null
                              ? 'You pay ${DP.naira(toDouble(q['local']))} (includes ${usd(toDouble(q['feeUsd']))} card fee)'
                              : 'Load between ${usd(_minUsd)} and ${usd(_maxUsd)}.',
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Card'),
                    DPChipRow(
                      options: _brands,
                      selected: _brand,
                      onSelect: (b) => setState(() => _brand = b),
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('Name on card'),
                    DPField(
                      controller: _cardName,
                      hint: _sl ? 'Fatmata Kamara' : 'Your name',
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    ),
                    const SizedBox(height: 24),
                    const SectionTitle('Identity check'),
                    const DPHelper('The card issuer needs these details to approve your card.', icon: DPIcons.shieldCheck),
                    const SizedBox(height: 12),
                    const DPLabel('Date of birth'),
                    DPSelectField(
                      value: _dob == null ? null : dateLabel(_dob!),
                      hint: 'Choose date',
                      leading: Icon(DPIcons.calendar, color: DP.muted, size: 20),
                      onTap: _pickDob,
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('House number'),
                    DPField(controller: _house, hint: 'e.g. 12B', inputFormatters: [LengthLimitingTextInputFormatter(20)]),
                    const SizedBox(height: 16),
                    const DPLabel('Home address'),
                    DPField(
                      controller: _address,
                      hint: _sl ? 'Street, town, Freetown' : 'Street, city, state',
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(200)],
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('ID type'),
                    DPChipRow(
                      options: [for (final t in _idTypes) str(t['name'])],
                      selected: str(_idTypeInfo?['name']),
                      onSelect: (name) => setState(() {
                        _idType = str(_idTypes.firstWhere((t) => t['name'] == name)['id']);
                      }),
                    ),
                    const SizedBox(height: 16),
                    DPLabel('${str(_idTypeInfo?['name'], 'ID')} number'),
                    DPField(
                      controller: _idNumber,
                      hint: 'ID number',
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    ),
                    if (_needsImage) ...[
                      const SizedBox(height: 16),
                      DPLabel('Photo of your ${str(_idTypeInfo?['name'], 'ID')}'),
                      DPCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            DPIconBadge(_idImage == null ? DPIcons.camera : DPIcons.checkCircle, size: 40, iconSize: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _idImage == null ? 'Clear photo of the front, all corners visible' : 'Photo added',
                                style: DP.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DPOutlineButton(
                              label: 'Take photo',
                              icon: DPIcons.camera,
                              height: 46,
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DPOutlineButton(
                              label: 'Choose photo',
                              icon: DPIcons.download,
                              height: 46,
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
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
        child: DPButton(label: 'Continue to review', icon: DPIcons.forward, onPressed: _review),
      ),
    );
  }
}
