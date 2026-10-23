// lib/presentation/screens/sierra_leone/sl_tiers_screen.dart
// Sierra Leone account levels (Tier 1–4): current limits, today's usage
// and upgrade requests, which an admin reviews.
//   GET  /api/tiers
//   POST /api/tiers/upgrade
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/photo_field.dart';

String _limit(dynamic v) => v == null ? 'No limit' : DP.moneyIn(toDouble(v), 'SLE', decimals: false);

class SlTiersScreen extends StatefulWidget {
  const SlTiersScreen({super.key});

  @override
  State<SlTiersScreen> createState() => _SlTiersScreenState();
}

class _SlTiersScreenState extends State<SlTiersScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = asMap(await api.get('/api/tiers'));
      if (mounted) setState(() => _data = d);
      Session.instance.refreshQuietly();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _upgrade(int tier) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SlUpgradeScreen(tier: tier, docTypes: asList(_data?['docTypes'])),
      ),
    );
    if (sent == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Account level'),
            Expanded(child: RefreshIndicator(onRefresh: _load, child: _body())),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final d = _data;
    if (d == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [if (_error != null) DPLoadError(error: _error, onRetry: _load) else const DPSkeletonList(rows: 5)],
      );
    }
    final tier = toInt(d['tier']);
    final approved = d['approved'] == true;
    final note = str(d['approvalNote']);
    final tiers = asList(d['tiers']);
    final current = tiers.firstWhere((t) => toInt(t['tier']) == tier, orElse: () => <String, dynamic>{});
    final requests = asList(d['requests']);
    final pending = requests.where((r) => r['status'] == 'pending').toList();
    final lastRejected = requests.isNotEmpty && requests.first['status'] == 'rejected' ? requests.first : null;
    final daily = current['daily'];
    final spent = toDouble(d['spentToday']);
    final maxBal = current['maxBalance'];
    final balance = toDouble(d['balance']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (!approved)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DPBanner(
              note.isNotEmpty
                  ? 'Your account was not approved: $note. Contact support if you think this is a mistake.'
                  : 'Your account is being reviewed. You can look around, but payments start once an admin approves it — usually within a few hours.',
              tone: note.isNotEmpty ? DPTone.error : DPTone.warning,
              icon: note.isNotEmpty ? DPIcons.alert : DPIcons.pending,
              title: note.isNotEmpty ? 'Not approved' : 'Pending approval',
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: DP.navyGradient,
            borderRadius: BorderRadius.circular(DP.rXl),
            boxShadow: DP.glow(DP.navy),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(DPIcons.shieldCheck, color: Color(0xFF7FE3BC), size: 18),
                  const SizedBox(width: 8),
                  Text('Your level', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Tier $tier', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _meter('Spent today', spent, daily),
              const SizedBox(height: 12),
              _meter('Wallet balance', balance, maxBal),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DPBanner(
              'Your Tier ${toInt(pending.first['tier'])} request is being reviewed. We\'ll notify you when it\'s done.',
              tone: DPTone.info,
              icon: DPIcons.pending,
            ),
          )
        else if (lastRejected != null && toInt(lastRejected['tier']) > tier)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DPBanner(
              'Your Tier ${toInt(lastRejected['tier'])} request wasn\'t approved: ${str(lastRejected['rejectionReason'])}. You can fix it and send it again.',
              tone: DPTone.error,
              icon: DPIcons.alert,
            ),
          ),
        const DPSectionHeader('Levels'),
        for (final t in tiers) _tierCard(t, tier, approved, pending.isNotEmpty),
      ],
    );
  }

  Widget _meter(String label, double used, dynamic limit) {
    final max = limit == null ? null : toDouble(limit);
    final ratio = max == null || max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
            const Spacer(),
            Flexible(
              child: Text(
                max == null ? '${DP.moneyIn(used, 'SLE')} · no limit' : '${DP.moneyIn(used, 'SLE')} of ${_limit(max)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(DP.rPill),
          child: LinearProgressIndicator(
            value: max == null ? 0 : ratio,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(ratio > 0.9 ? const Color(0xFFFFB86B) : const Color(0xFF7FE3BC)),
          ),
        ),
      ],
    );
  }

  Widget _tierCard(Map<String, dynamic> t, int current, bool approved, bool hasPending) {
    final n = toInt(t['tier']);
    final reached = n <= current;
    final next = n == current + 1;
    final here = n == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DPCard(
        color: here ? DP.mint : DPAuto.surface,
        borderColor: here ? DP.green : DPAuto.border,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DPIconBadge(reached ? DPIcons.checkCircle : DPIcons.lock, size: 36, iconSize: 18,
                    color: reached ? DP.green : DP.muted, background: reached ? DP.mint : DP.bg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tier $n${here ? ' · your level' : ''}', style: DP.bodyStrong),
                      Text(str(t['requirement']), style: DP.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('Daily: ${_limit(t['daily'])}', style: DP.caption.copyWith(fontWeight: FontWeight.w600)),
                Text('Balance: ${_limit(t['maxBalance'])}', style: DP.caption.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            if (next && approved && !hasPending) ...[
              const SizedBox(height: 12),
              DPButton(label: 'Upgrade to Tier $n', icon: DPIcons.forward, height: 46, onPressed: () => _upgrade(n)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The form for one upgrade (Tier 2 ID, Tier 3 bank, Tier 4 business).
class SlUpgradeScreen extends StatefulWidget {
  final int tier;
  final List<Map<String, dynamic>> docTypes;
  const SlUpgradeScreen({super.key, required this.tier, required this.docTypes});

  @override
  State<SlUpgradeScreen> createState() => _SlUpgradeScreenState();
}

class _SlUpgradeScreenState extends State<SlUpgradeScreen> {
  final _a = TextEditingController(); // doc number / bank name / business name
  final _b = TextEditingController(); // account number / registration no.
  final _c = TextEditingController(); // account name / business address
  String? _docType;
  final Map<String, String?> _photos = {};
  bool _sending = false;

  List<Map<String, dynamic>> get _types => widget.docTypes.isNotEmpty
      ? widget.docTypes
      : const [
          {'id': 'nin', 'name': 'NIN'},
          {'id': 'national_id', 'name': 'National ID card'},
          {'id': 'passport', 'name': 'Passport'},
          {'id': 'voters_card', 'name': "Voter's card"},
        ];

  @override
  void initState() {
    super.initState();
    _docType = str(_types.first['id']);
    if (widget.tier == 3) _c.text = Session.instance.user?.fullName ?? '';
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  String get _title => switch (widget.tier) {
        2 => 'Add your ID',
        3 => 'Connect your bank account',
        _ => 'Add your business licence',
      };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final Map<String, dynamic> body = {'tier': widget.tier};
    String? err;
    if (widget.tier == 2) {
      if (_a.text.trim().length < 4) err = 'Enter the document number';
      if (_photos['front'] == null) err ??= 'Add a photo of the front of the document';
      body.addAll({
        'docType': _docType,
        'docNumber': _a.text.trim(),
        'front': _photos['front'],
        if (_photos['back'] != null) 'back': _photos['back'],
        if (_photos['selfie'] != null) 'selfie': _photos['selfie'],
      });
    } else if (widget.tier == 3) {
      if (_a.text.trim().length < 2) err = 'Enter the bank name';
      if (_b.text.trim().length < 6) err ??= 'Enter the account number';
      if (_c.text.trim().length < 2) err ??= 'Enter the account name';
      body.addAll({
        'bankName': _a.text.trim(),
        'accountNumber': _b.text.trim(),
        'accountName': _c.text.trim(),
        if (_photos['statement'] != null) 'statement': _photos['statement'],
      });
    } else {
      if (_a.text.trim().length < 2) err = 'Enter the business name';
      if (_b.text.trim().length < 3) err ??= 'Enter the registration / licence number';
      if (_c.text.trim().length < 5) err ??= 'Enter the business address';
      if (_photos['licence'] == null) err ??= 'Add a photo of the business licence';
      body.addAll({
        'businessName': _a.text.trim(),
        'registrationNumber': _b.text.trim(),
        'businessAddress': _c.text.trim(),
        'licence': _photos['licence'],
      });
    }
    if (err != null) {
      dpSnack(context, err, error: true);
      return;
    }
    setState(() => _sending = true);
    final r = await runWithFeedback(context, () => api.post('/api/tiers/upgrade', body), success: 'Sent for review');
    if (!mounted) return;
    setState(() => _sending = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  Widget _field(String label, TextEditingController c, {String? hint, TextInputType? type, int max = 100, bool words = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPLabel(label),
          DPField(
            controller: c,
            hint: hint,
            keyboardType: type,
            textCapitalization: words ? TextCapitalization.words : TextCapitalization.none,
            inputFormatters: [LengthLimitingTextInputFormatter(max)],
          ),
        ],
      ),
    );
  }

  Widget _photo(String key, String label, {bool required = true, String? hint}) => PhotoField(
        label: label,
        required: required,
        hint: hint ?? 'Clear photo, all corners visible',
        onChanged: (v) => _photos[key] = v,
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(title: 'Tier $t upgrade'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DPHeadline(_title, subtitle: 'An admin checks your details, usually within a day. We\'ll notify you.'),
                    if (t == 2) ...[
                      const DPLabel('Document'),
                      DPChipGrid(
                        options: [for (final d in _types) str(d['name'])],
                        selected: str(_types.firstWhere((d) => d['id'] == _docType, orElse: () => _types.first)['name']),
                        height: 44,
                        onSelect: (name) => setState(() => _docType = str(_types.firstWhere((d) => d['name'] == name)['id'])),
                      ),
                      const SizedBox(height: 16),
                      _field('Document number', _a, hint: 'As printed on the document', max: 40),
                      _photo('front', 'Front of the document'),
                      _photo('back', 'Back of the document', required: false),
                      _photo('selfie', 'Selfie holding the document', required: false, hint: 'Your face and the document, clearly visible'),
                    ] else if (t == 3) ...[
                      _field('Bank name', _a, hint: 'e.g. Rokel Commercial Bank', max: 80, words: true),
                      _field('Account number', _b, hint: 'Account number', type: TextInputType.number, max: 24),
                      _field('Account name', _c, hint: 'Name on the account', max: 100, words: true),
                      const DPHelper('The account name should match your Dalabapay name.'),
                      const SizedBox(height: 12),
                      _photo('statement', 'Bank statement or account letter', required: false),
                    ] else ...[
                      _field('Business name', _a, hint: 'Registered business name', max: 120, words: true),
                      _field('Registration / licence number', _b, hint: 'From the licence', max: 60),
                      _field('Business address', _c, hint: 'Street, town', max: 200, words: true),
                      _photo('licence', 'Business licence'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DPBottomAction(
        child: DPButton(label: 'Send for review', icon: DPIcons.forward, loading: _sending, onPressed: _sending ? null : _submit),
      ),
    );
  }
}
