// lib/presentation/screens/insurance/insurance_screen.dart
// UI only — third-party motor insurance form with sample dropdown values.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class _InsType {
  final String name;
  final IconData icon;
  final double amount;
  const _InsType(this.name, this.icon, this.amount);
}

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  static const _types = [
    _InsType('Private', Icons.directions_car_outlined, 3000),
    _InsType('Commercial', Icons.local_shipping_outlined, 5000),
    _InsType('Tricycle', Icons.electric_rickshaw_outlined, 1500),
    _InsType('Motorcycle', Icons.two_wheeler_outlined, 3000),
  ];
  static const _makes = ['Toyota', 'Honda', 'Lexus', 'Hyundai', 'Kia', 'Mercedes-Benz', 'Ford', 'Volkswagen'];
  static const _models = ['Corolla', 'Camry', 'Highlander', 'RAV4', 'Sienna'];
  static const _colors = ['Black', 'White', 'Silver', 'Grey', 'Blue', 'Red'];
  static const _engines = ['1.0 – 1.5L', '1.6 – 2.0L', '2.1 – 3.0L', 'Above 3.0L'];
  static const _states = ['Abuja (FCT)', 'Lagos', 'Ogun', 'Oyo', 'Rivers', 'Kano', 'Enugu'];
  static const _lgas = ['Ikeja', 'Eti-Osa', 'Alimosho', 'Surulere', 'Kosofe'];

  _InsType? _type = _types.first;
  final _plate = TextEditingController();
  final _chassis = TextEditingController();
  final _year = TextEditingController();
  final _name = TextEditingController(text: MockUser.fullName);
  final _email = TextEditingController(text: MockUser.email);
  final _phone = TextEditingController(text: MockUser.phone);
  String? _make, _model, _color, _engine, _state, _lga;

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
    if (_type == null || _plate.text.trim().isEmpty || _name.text.trim().isEmpty) {
      dpSnack(context, 'Fill in the plate number and insured name', error: true);
      return;
    }
    final amount = _type!.amount;
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
        const DPReviewRow('Certificate', 'TPM-2026-0048213'),
      ],
      footnote: 'Your certificate is emailed to you after payment.',
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
                    _select('Vehicle Make', _make, _makes, (v) {
                      _make = v;
                      _model = null;
                    }),
                    _select('Vehicle Model', _model, _models,
                        (v) => _model = v,
                        enabled: _make != null),
                    _select('Vehicle Color', _color, _colors,
                        (v) => _color = v),
                    _select('Engine Capacity', _engine, _engines,
                        (v) => _engine = v),
                    const SizedBox(height: 8),
                    const SectionTitle('Location Information'),
                    _select('State', _state, _states, (v) {
                      _state = v;
                      _lga = null;
                    }),
                    _select('Local Government Area', _lga, _lgas,
                        (v) => _lga = v,
                        enabled: _state != null),
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
