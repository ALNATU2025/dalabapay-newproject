// lib/presentation/screens/insurance/insurance_screen.dart
// Third-party motor insurance. Types, makes, colours and states come from
// GET /api/services/insurance/options (models and LGAs load on demand);
// payment is POST /api/services/insurance.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';

class _InsType {
  final String code;
  final String name;
  final IconData icon;
  final double amount;
  const _InsType(this.code, this.name, this.icon, this.amount);

  static IconData iconFor(String code) => switch (code) {
        'commercial' => Icons.local_shipping_outlined,
        'tricycle' => Icons.electric_rickshaw_outlined,
        'motorcycle' => Icons.two_wheeler_outlined,
        _ => Icons.directions_car_outlined,
      };

  @override
  bool operator ==(Object other) => other is _InsType && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  List<_InsType> _types = [];
  Map<String, String> _makeIds = {}; // name → id
  List<String> _models = [];
  List<String> _colors = [];
  List<String> _engines = [];
  List<String> _states = [];
  List<String> _lgas = [];
  bool _loading = true;
  Object? _loadError;

  _InsType? _type;
  final _plate = TextEditingController();
  final _chassis = TextEditingController();
  final _year = TextEditingController();
  final _name = TextEditingController(text: Session.instance.user?.fullName ?? '');
  final _email = TextEditingController(text: Session.instance.user?.email ?? '');
  final _phone = TextEditingController(text: Session.instance.user?.phone ?? '');
  String? _make, _model, _color, _engine, _state, _lga;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final o = asMap(await api.get('/api/services/insurance/options'));
      List<String> strings(dynamic v) =>
          (v as List? ?? const []).map((e) => '$e').toList();
      if (!mounted) return;
      setState(() {
        _types = [
          for (final t in asList(o['types']))
            _InsType(str(t['code']), str(t['name']),
                _InsType.iconFor(str(t['code'])), toDouble(t['amount'])),
        ];
        _type ??= _types.isEmpty ? null : _types.first;
        _makeIds = {for (final m in asList(o['makes'])) str(m['name']): str(m['id'])};
        _colors = strings(o['colors']);
        _engines = strings(o['engineCapacities']);
        _states = strings(o['states']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _loadModels(String make) async {
    setState(() => _models = []);
    try {
      final r = asList(await api.get('/api/services/insurance/models',
          query: {'make': _makeIds[make] ?? make}));
      if (mounted && _make == make) {
        setState(() => _models = r.map((m) => str(m['name'])).toList());
      }
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _loadLgas(String state) async {
    setState(() => _lgas = []);
    try {
      final r = await api.get('/api/services/insurance/lgas', query: {'state': state});
      if (mounted && _state == state) {
        setState(() => _lgas = (r as List? ?? const []).map((e) => '$e').toList());
      }
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  void dispose() {
    for (final c in [_plate, _chassis, _year, _name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(
    String title,
    List<String> items,
    String? current,
    ValueChanged<String> onPicked,
  ) async {
    final v = await dpPickFromList<String>(
      context,
      title: title,
      items: items,
      selected: current,
      labelOf: (x) => x,
    );
    if (v != null && mounted) setState(() => onPicked(v));
  }

  Widget _select(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String> onPicked, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPLabel(label),
          DPSelectField(
            value: value,
            hint: 'Select ${label.toLowerCase()}',
            enabled: enabled,
            onTap: () => _pick(label, items, value, onPicked),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPLabel(label),
          DPField(
            controller: c,
            hint: hint,
            keyboardType: keyboard,
            inputFormatters: formatters,
            textCapitalization: caps,
          ),
        ],
      ),
    );
  }

  void _openReview() {
    if (_type == null || _plate.text.trim().length < 5 || _name.text.trim().isEmpty) {
      dpSnack(context, 'Fill in the plate number and insured name', error: true);
      return;
    }
    if (_phone.text.trim().length != 11 || !_email.text.contains('@')) {
      dpSnack(context, 'Enter a valid email and 11-digit phone number', error: true);
      return;
    }
    final year = _year.text.trim();
    if (year.isNotEmpty && year.length != 4) {
      dpSnack(context, 'Enter the 4-digit year of make', error: true);
      return;
    }
    final amount = _type!.amount;
    final body = <String, dynamic>{
      'typeCode': _type!.code,
      'plateNumber': _plate.text.trim().toUpperCase(),
      if (_chassis.text.trim().isNotEmpty) 'chassisNumber': _chassis.text.trim(),
      if (year.isNotEmpty) 'yearOfMake': year,
      if (_make != null) 'make': _make,
      if (_model != null) 'model': _model,
      if (_color != null) 'color': _color,
      if (_engine != null) 'engineCapacity': _engine,
      if (_state != null) 'state': _state,
      if (_lga != null) 'lga': _lga,
      'insuredName': _name.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'phone': _phone.text.trim(),
    };
    showReviewAndPay(
      context,
      icon: DPIcons.shield,
      title: '${_type!.name} — Third Party Motor',
      serviceLabel: 'Motor Insurance',
      amount: amount,
      service: 'insurance',
      rows: [
        DPReviewRow('Cover', '${_type!.name} third party'),
        DPReviewRow('Insured name', _name.text.trim()),
        DPReviewRow('Plate number', _plate.text.trim().toUpperCase()),
        DPReviewRow(
          'Vehicle',
          [_make, _model, _year.text.trim()]
              .where((e) => e != null && e.isNotEmpty)
              .join(' '),
        ),
        DPReviewRow('Phone number', _phone.text.trim()),
        DPReviewRow('Total to pay', DP.naira(amount), strong: true),
      ],
      successRows: [
        DPReviewRow('Cover', '${_type!.name} third party'),
        DPReviewRow('Plate number', _plate.text.trim().toUpperCase()),
      ],
      resultRows: (txn) {
        final cert = asMap(txn['metadata'])['certificateNumber'];
        return [if (cert != null) DPReviewRow('Certificate', str(cert))];
      },
      footnote: 'Your certificate is emailed to you after payment.',
      onPay: (pin) async {
        final r = await api.post('/api/services/insurance', {...body, 'pin': pin});
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Insurance',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Third-party motor cover in minutes. Stay road-legal.',
                      style: DP.body.copyWith(color: DP.muted),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Select Insurance Type'),
                    if (_loading)
                      const DPLoading(padding: 24)
                    else if (_loadError != null)
                      DPLoadError(error: _loadError, onRetry: _loadOptions)
                    else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.1,
                      children: [for (final t in _types) _typeCard(t)],
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('Vehicle Information'),
                    _field('Plate Number', _plate, 'Enter plate number',
                        caps: TextCapitalization.characters),
                    _field('Chasis Number', _chassis, 'Enter chasis number',
                        caps: TextCapitalization.characters),
                    _field(
                      'Year of Make',
                      _year,
                      'e.g. 2018',
                      keyboard: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                    _select('Vehicle Make', _make, _makeIds.keys.toList(), (v) {
                      _make = v;
                      _model = null;
                      _loadModels(v);
                    }),
                    _select('Vehicle Model', _model, _models,
                        (v) => _model = v,
                        enabled: _make != null && _models.isNotEmpty),
                    _select('Vehicle Color', _color, _colors,
                        (v) => _color = v),
                    _select('Engine Capacity', _engine, _engines,
                        (v) => _engine = v),
                    const SizedBox(height: 8),
                    const SectionTitle('Location Information'),
                    _select('State', _state, _states, (v) {
                      _state = v;
                      _lga = null;
                      _loadLgas(v);
                    }),
                    _select('Local Government Area', _lga, _lgas,
                        (v) => _lga = v,
                        enabled: _state != null && _lgas.isNotEmpty),
                    const SizedBox(height: 8),
                    const SectionTitle('Personal Information'),
                    _field('Insured Name', _name, 'Enter full name',
                        caps: TextCapitalization.words),
                    _field('Email Address', _email, 'Enter email address',
                        keyboard: TextInputType.emailAddress),
                    _field(
                      'Phone Number',
                      _phone,
                      '0803 456 7890',
                      keyboard: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                    ),
                    const SizedBox(height: 6),
                    WalletCommissionCard(
                      amount: _type?.amount ?? 0,
                      service: 'insurance',
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
          label: 'Proceed to Pay',
          icon: DPIcons.forward,
          onPressed: _openReview,
        ),
      ),
    );
  }

  Widget _typeCard(_InsType t) {
    final selected = _type == t;
    return DPCard(
      color: selected ? DP.mint : DP.surface,
      borderColor: selected ? DP.green : DP.border,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => setState(() => _type = t),
      child: Row(
        children: [
          DPIconBadge(
            t.icon,
            size: 36,
            iconSize: 19,
            color: selected ? DP.green : DP.navyIcon,
            background: selected ? DP.surface : DP.blueTint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DP.bodyStrong.copyWith(fontSize: 14),
                ),
                Text(
                  DP.naira(t.amount, decimals: false),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DP.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
