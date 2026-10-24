// lib/presentation/screens/education/education_screen.dart
// WAEC / JAMB PINs (GET /api/services/education/products). Service → plan
// → (JAMB profile ID, POST /api/services/education/verify) → phone →
// quantity → review → POST /api/services/education. PINs show on the receipt.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/catalog.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class _EduService {
  final String id;
  final String name;
  final bool needsProfile;
  final bool showQuantity;
  final List<Plan> plans;
  const _EduService(
    this.id,
    this.name, {
    this.needsProfile = false,
    this.showQuantity = false,
    required this.plans,
  });

  String get provider => id; // for the logo

  factory _EduService.fromJson(Map<String, dynamic> j) => _EduService(
        str(j['id']),
        str(j['name']),
        needsProfile: j['requiresProfile'] == true,
        showQuantity: j['allowQuantity'] == true,
        plans: Plan.listFrom(j['variations']),
      );

  @override
  bool operator ==(Object other) => other is _EduService && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  List<_EduService> _services = [];

  final _profileController = TextEditingController();
  final _phoneController =
      TextEditingController(text: Session.instance.user?.phone ?? '');
  _EduService? _service;
  Plan? _plan;
  int _quantity = 1;
  bool _validating = false;
  bool _validated = false;
  String _candidateName = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final list = asList(await api.get('/api/services/education/products'));
      if (!mounted) return;
      setState(() => _services = list.map(_EduService.fromJson).toList());
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  void dispose() {
    _profileController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _logo(String provider, {double size = 28}) {
    final asset = DPAssets.providerFor(provider);
    final fallback = Icon(DPIcons.school, color: DP.navyIcon, size: size * 0.8);
    if (asset == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: DPImage(asset, width: size, height: size, fallback: fallback),
    );
  }

  Future<void> _validate() async {
    FocusScope.of(context).unfocus();
    setState(() => _validating = true);
    try {
      final r = asMap(await api.post('/api/services/education/verify', {
        'service': _service!.id,
        'profileId': _profileController.text.trim(),
        if (_plan != null) 'variationCode': _plan!.code,
      }));
      if (!mounted) return;
      setState(() {
        _validating = false;
        _validated = true;
        _candidateName = str(r['customerName']);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _validating = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  void _openReview() {
    if (_service == null || _plan == null) {
      dpSnack(context, 'Choose a service and a plan', error: true);
      return;
    }
    if (_service!.needsProfile && !_validated) {
      dpSnack(context, 'Validate your Profile ID first', error: true);
      return;
    }
    if (_phoneController.text.trim().length != 11) {
      dpSnack(context, 'Phone number must be exactly 11 digits', error: true);
      return;
    }
    final total = _plan!.price * _quantity;
    final service = _service!;
    final plan = _plan!;
    final quantity = _quantity;
    final phone = _phoneController.text.trim();
    final profileId = _profileController.text.trim();
    showReviewAndPay(
      context,
      icon: DPIcons.school,
      title: _plan!.name,
      serviceLabel: _service!.name,
      amount: total,
      service: 'education',
      rows: [
        DPReviewRow('Service', _service!.name),
        DPReviewRow('Plan', _plan!.name),
        if (_service!.needsProfile)
          DPReviewRow('Profile ID', _profileController.text.trim()),
        DPReviewRow('Phone number', _phoneController.text.trim()),
        if (_quantity > 1) ...[
          DPReviewRow('Price each', DP.naira(_plan!.price)),
          DPReviewRow('Quantity', '$_quantity'),
        ],
        DPReviewRow('Total to pay', DP.naira(total), strong: true),
      ],
      successRows: [
        DPReviewRow('Service', service.name),
        if (service.needsProfile && _candidateName.isNotEmpty)
          DPReviewRow('Candidate', _candidateName),
      ],
      resultRows: (txn) => [
        for (final p in asList(asMap(txn['metadata'])['pins'])) ...[
          if (p['serial'] != null) DPReviewRow('Serial', str(p['serial'])),
          DPReviewRow('PIN', str(p['pin'])),
        ],
        if (asMap(txn['metadata'])['token'] != null)
          DPReviewRow('Token', str(asMap(txn['metadata'])['token'])),
      ],
      footnote: 'Your PIN or token appears on the receipt after payment.',
      onPay: (pin) async {
        final r = await api.post('/api/services/education', {
          'service': service.id,
          'variationCode': plan.code,
          'quantity': quantity,
          'phone': phone,
          if (service.needsProfile) 'profileId': profileId,
          'pin': pin,
        });
        return asMap(asMap(r)['transaction']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (_plan?.price ?? 0) * _quantity;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Education',
              actionLabel: 'History',
              onAction: () => Navigator.pushNamed(context, '/transactions'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPServiceBanner(
                      title: 'Exam PINs and result checkers in seconds.',
                      subtitle: 'WAEC and JAMB, delivered instantly.',
                      icon: DPIcons.school,
                      image: DPAssets.svcEducation,
                      style: DPBannerStyle.ocean,
                      tag: 'Education',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Exam PINs and result checkers, delivered instantly.',
                      style: DP.body.copyWith(color: DP.muted),
                    ),
                    const SizedBox(height: 20),
                    const DPLabel('Select Service'),
                    DPSelectField(
                      value: _service?.name,
                      hint: 'Choose a service',
                      leading: _service == null
                          ? const Icon(DPIcons.school,
                              color: DP.navyIcon, size: 20)
                          : _logo(_service!.provider),
                      onTap: () async {
                        final picked = await dpPickFromList<_EduService>(
                          context,
                          title: 'Education service',
                          items: _services,
                          selected: _service,
                          labelOf: (s) => s.name,
                          leadingOf: (s) => _logo(s.provider),
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          _service = picked;
                          _plan = picked.plans.length == 1
                              ? picked.plans.first
                              : null;
                          _quantity = 1;
                          _validated = false;
                        });
                      },
                    ),
                    if (_service != null) ...[
                      const SizedBox(height: 20),
                      const SectionTitle('Select Plan'),
                      for (final p in _service!.plans) _planTile(p),
                    ],
                    if (_service?.needsProfile == true) ...[
                      const SizedBox(height: 12),
                      DPLabel(
                        'Profile ID',
                        trailing: _validated
                            ? null
                            : DPTextLink(
                                label: _validating ? 'Checking…' : 'Validate',
                                color: _profileController.text.isNotEmpty
                                    ? DP.green
                                    : DP.faint,
                                onTap: _profileController.text.isNotEmpty &&
                                        !_validating
                                    ? _validate
                                    : null,
                              ),
                      ),
                      DPField(
                        controller: _profileController,
                        hint: 'Enter your Profile ID',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() => _validated = false),
                        prefix: const Icon(DPIcons.user, size: 20),
                      ),
                      if (_validated) ...[
                        const SizedBox(height: 12),
                        DPBanner(
                          _candidateName,
                          title: 'Profile Validated',
                          icon: DPIcons.checkCircle,
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    const DPLabel('Phone Number'),
                    DPField(
                      controller: _phoneController,
                      hint: 'Enter 11-digit phone number',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      prefix: const Icon(DPIcons.smartphone, size: 20),
                    ),
                    if (_service?.showQuantity == true) ...[
                      const SizedBox(height: 20),
                      const DPLabel('Quantity'),
                      Row(
                        children: [
                          DPIconSquare(
                            icon: Icons.remove_rounded,
                            color: _quantity > 1 ? DP.ink : DP.faint,
                            onTap: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '$_quantity',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: DP.ink,
                              ),
                            ),
                          ),
                          DPIconSquare(
                            icon: DPIcons.plus,
                            color: _quantity < 10 ? DP.ink : DP.faint,
                            onTap: _quantity < 10
                                ? () => setState(() => _quantity++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    WalletCommissionCard(amount: total, service: 'education'),
                    const SizedBox(height: 14),
                    const DPBanner(
                      'Your PIN and serial number show on the receipt and in your transaction history.',
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
          label: 'Review payment',
          icon: DPIcons.forward,
          onPressed: _openReview,
        ),
      ),
    );
  }

  Widget _planTile(Plan p) {
    final selected = _plan == p;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DPCard(
        color: selected ? DP.mint : DP.surface,
        borderColor: selected ? DP.green : DP.border,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: () => setState(() => _plan = p),
        child: Row(
          children: [
            Expanded(child: Text(p.name, style: DP.bodyStrong)),
            Text(
              DP.naira(p.price, decimals: false),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DP.green,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: DP.green,
            ),
          ],
        ),
      ),
    );
  }
}
