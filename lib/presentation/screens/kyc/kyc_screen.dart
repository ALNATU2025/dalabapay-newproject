// lib/presentation/screens/kyc/kyc_screen.dart
// KYC: BVN or NIN + details → POST /api/kyc, which creates your personal
// funding account (when the payment provider is connected).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';

class KYCScreen extends StatefulWidget {
  const KYCScreen({super.key});

  @override
  State<KYCScreen> createState() => _KYCScreenState();
}

class _KYCScreenState extends State<KYCScreen> {
  final _bvn = TextEditingController();
  final _nin = TextEditingController();
  final _dob = TextEditingController();
  final _address = TextEditingController();
  String? _gender;
  bool _agreed = false;
  bool _submitting = false;

  bool get _idOk => _bvn.text.length == 11 || _nin.text.length == 11;
  bool get _valid =>
      _idOk &&
      _dob.text.length == 10 &&
      _gender != null &&
      _address.text.trim().isNotEmpty &&
      _agreed;

  @override
  void initState() {
    super.initState();
    for (final c in [_bvn, _nin, _dob, _address]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_bvn, _nin, _dob, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(2010, 12, 31),
    );
    if (d == null) return;
    _dob.text =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final r = asMap(await api.post('/api/kyc', {
        if (_bvn.text.length == 11) 'bvn': _bvn.text,
        if (_bvn.text.length != 11 && _nin.text.length == 11) 'nin': _nin.text,
        'dateOfBirth': _dob.text,
        'gender': _gender,
        'address': _address.text.trim(),
      }));
      await Session.instance.refreshQuietly();
      if (!mounted) return;
      setState(() => _submitting = false);
      final account = r['dedicatedAccount'];
      if (account is Map) {
        _showSuccess(account.cast<String, dynamic>());
      } else {
        await dpDialog(
          context,
          title: 'Details submitted',
          message:
              'Thanks! We\'re checking your details. Your personal account number will appear on Add Money once it\'s ready.',
          tone: DPTone.info,
        );
        if (mounted) Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      dpSnack(context, errorMessage(e), error: true);
    }
  }

  void _showSuccess(Map<String, dynamic> account) {
    final number = str(account['accountNumber']);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: DP.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 12),
              const DPStatusHero(size: 84),
              const SizedBox(height: 14),
              Text('Account created!', style: DP.title),
              const SizedBox(height: 6),
              Text(
                'Your dedicated account has been set up successfully',
                textAlign: TextAlign.center,
                style: DP.body.copyWith(color: DP.muted),
              ),
              const SizedBox(height: 18),
              DPCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(
                  children: [
                    DPSummaryRow(
                      'Account Number',
                      number,
                      strong: true,
                      trailing: IconButton(
                        icon: const Icon(DPIcons.copy,
                            size: 18, color: DP.green),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: number));
                          dpSnack(ctx, 'Account details copied to clipboard',
                              success: true);
                        },
                      ),
                    ),
                    DPSummaryRow('Account Name', str(account['accountName'])),
                    DPSummaryRow('Bank', str(account['bankName'])),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const DPBanner(
                'Your account tier has been upgraded. You can now receive payments!',
              ),
              const SizedBox(height: 20),
              DPButton(
                label: 'Go to Dashboard',
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.popUntil(
                    context,
                    (r) => r.settings.name == '/dashboard' || r.isFirst,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(AppUser user) {
    final account = user.dedicatedAccount;
    final pending = user.kycStatus == 'pending';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Center(
          child: DPStatusHero(
            kind: pending ? DPStatusKind.pending : DPStatusKind.success,
            size: 84,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          pending ? 'Verification in progress' : 'You\'re verified',
          textAlign: TextAlign.center,
          style: DP.title,
        ),
        const SizedBox(height: 6),
        Text(
          pending
              ? 'We\'re checking your details. Your account number will appear here once it\'s ready.'
              : 'Transfer to your personal account to fund your wallet.',
          textAlign: TextAlign.center,
          style: DP.body.copyWith(color: DP.muted),
        ),
        if (account != null) ...[
          const SizedBox(height: 18),
          DPCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              children: [
                DPSummaryRow(
                  'Account Number',
                  str(account['accountNumber']),
                  strong: true,
                  trailing: IconButton(
                    icon: const Icon(DPIcons.copy, size: 18, color: DP.green),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: str(account['accountNumber'])));
                      dpSnack(context, 'Account number copied', success: true);
                    },
                  ),
                ),
                DPSummaryRow('Account Name', str(account['accountName'])),
                DPSummaryRow('Bank', str(account['bankName'])),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
    if (user != null &&
        (user.dedicatedAccount != null || user.kycStatus == 'pending')) {
      return Scaffold(
        backgroundColor: DP.bg,
        body: SafeArea(
          child: Column(
            children: [
              const DPTopBar(title: 'Verify your identity'),
              Expanded(child: _buildStatus(user)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Verify your identity'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DPHeadline(
                      'Complete Your KYC',
                      subtitle:
                          'Provide your identification details to create your dedicated account.',
                    ),
                    DPCard(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 6, bottom: 4),
                            child: Text('Your Information', style: DP.section),
                          ),
                          DPSummaryRow('Full Name', user?.fullName ?? ''),
                          DPSummaryRow('Email', user?.email ?? ''),
                          DPSummaryRow('Phone', user?.phone ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const DPBanner(
                      'You only need to provide either BVN or NIN, not both.',
                      tone: DPTone.info,
                      icon: DPIcons.info,
                    ),
                    const SizedBox(height: 18),
                    const DPLabel('Bank Verification Number (BVN)'),
                    DPField(
                      controller: _bvn,
                      hint: 'Enter 11-digit BVN (optional if providing NIN)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      prefix: const Icon(DPIcons.bank, size: 20),
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('National Identification Number (NIN)'),
                    DPField(
                      controller: _nin,
                      hint: 'Enter 11-digit NIN (optional if providing BVN)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      prefix: const Icon(DPIcons.badge, size: 20),
                    ),
                    if (!_idOk &&
                        (_bvn.text.isNotEmpty || _nin.text.isNotEmpty))
                      const DPHelper(
                        'Please enter a valid BVN or NIN (11 digits)',
                        color: DP.amber,
                      ),
                    const SizedBox(height: 16),
                    const DPLabel('Date of Birth'),
                    DPField(
                      controller: _dob,
                      hint: 'DD/MM/YYYY',
                      readOnly: true,
                      onTap: _pickDob,
                      prefix: const Icon(DPIcons.calendar, size: 20),
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('Gender'),
                    DPChipRow(
                      options: const ['Male', 'Female'],
                      selected: _gender,
                      height: 46,
                      onSelect: (g) => setState(() => _gender = g),
                    ),
                    const SizedBox(height: 16),
                    const DPLabel('Residential Address'),
                    DPField(
                      controller: _address,
                      hint: 'Enter your residential address',
                      maxLines: 2,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => setState(() => _agreed = !_agreed),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreed,
                              onChanged: (v) =>
                                  setState(() => _agreed = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                children: [
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: DP.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              style: DP.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    DPButton(
                      label: _valid
                          ? 'Create Dedicated Account'
                          : 'Fill Required Fields',
                      loading: _submitting,
                      onPressed: _valid && !_submitting ? _submit : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(DPIcons.lock, size: 15, color: DP.muted),
                        SizedBox(width: 6),
                        Text(
                          'Your information is secure and encrypted',
                          style: DP.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
