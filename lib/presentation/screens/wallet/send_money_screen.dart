// lib/presentation/screens/wallet/send_money_screen.dart
// UI only — wallet-to-wallet transfer by phone or email. Typing a full
// number "finds" a sample recipient; nothing is sent.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';
import '../../widgets/payment_flow.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int _mode = 0; // 0 phone, 1 email
  bool _lookingUp = false;
  String? _recipientName;

  static const double _balance = MockUser.walletBalance;

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  String get _recipientLabel => _mode == 0
      ? _phoneController.text.trim()
      : _emailController.text.trim();

  bool get _identifierValid => _mode == 0
      ? _phoneController.text.trim().length >= 11
      : RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(_emailController.text.trim());

  bool get _canContinue =>
      _recipientName != null && _amount > 0 && _amount <= _balance;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setMode(int m) => setState(() {
        _mode = m;
        _recipientName = null;
      });

  Future<void> _lookup() async {
    if (!_identifierValid || _lookingUp) return;
    setState(() => _lookingUp = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _lookingUp = false;
      _recipientName = 'Chidi Eze';
    });
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    showReviewAndPay(
      context,
      icon: DPIcons.upRight,
      title: 'To $_recipientName',
      serviceLabel: 'Wallet transfer',
      amount: _amount,
      service: 'transfer',
      payLabel: 'Send ${DP.naira(_amount)}',
      successTitle: 'Money sent',
      successSubtitle: 'Your transfer is on its way.',
      rows: [
        DPReviewRow('Recipient', _recipientName!),
        DPReviewRow(_mode == 0 ? 'Phone number' : 'Email', _recipientLabel),
        if (_noteController.text.trim().isNotEmpty)
          DPReviewRow('Note', _noteController.text.trim()),
        const DPReviewRow('Transfer fee', '₦0.00'),
        DPReviewRow('Total to pay', DP.naira(_amount), strong: true),
      ],
      footnote: 'Transfers to the wrong person may not be recoverable.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final over = _amount > _balance;
    final byPhone = _mode == 0;
    final spinner = const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPTopBar(title: 'Send Money'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DPSegmented(
                      options: const ['Phone Number', 'Email'],
                      index: _mode,
                      onChanged: _setMode,
                    ),
                    const SizedBox(height: 20),
                    DPLabel(
                      byPhone ? 'Recipient Phone Number' : 'Recipient Email',
                    ),
                    if (byPhone)
                      DPField(
                        key: const ValueKey('phone'),
                        controller: _phoneController,
                        hint: 'e.g. 08012345678',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                        prefix: const Icon(DPIcons.user, size: 20),
                        onChanged: (_) {
                          setState(() => _recipientName = null);
                          if (_identifierValid) _lookup();
                        },
                        suffix: _lookingUp ? spinner : null,
                      )
                    else
                      DPField(
                        key: const ValueKey('email'),
                        controller: _emailController,
                        hint: 'name@email.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        prefix: const Icon(DPIcons.mail, size: 20),
                        onChanged: (_) => setState(() => _recipientName = null),
                        onSubmitted: (_) => _lookup(),
                        suffix: _lookingUp
                            ? spinner
                            : IconButton(
                                tooltip: 'Find recipient',
                                icon: const Icon(DPIcons.search),
                                onPressed: _lookup,
                              ),
                      ),
                    AnimatedSize(
                      duration: DPMotion.base,
                      curve: DPMotion.curve,
                      child: _recipientName != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: DPAppear(
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                  decoration: BoxDecoration(
                                    color: DP.mint,
                                    borderRadius:
                                        BorderRadius.circular(DP.rMd),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        DPIcons.checkCircle,
                                        color: DP.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _recipientName!.toUpperCase(),
                                          style: const TextStyle(
                                            color: DP.green,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 18),
                    const DPLabel('Amount'),
                    DPField(
                      controller: _amountController,
                      hint: '0.00',
                      prefixText: '₦  ',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      errorText:
                          over ? 'This is more than your wallet balance' : null,
                      style: const TextStyle(
                        fontSize: 16,
                        color: DP.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DPHelper(
                      'Wallet balance: ${DP.naira(_balance)}  ·  No transfer fee',
                    ),
                    const SizedBox(height: 18),
                    const DPLabel('Add Note (Optional)'),
                    DPField(
                      controller: _noteController,
                      hint: 'Enter a note...',
                      maxLength: 60,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DPBottomAction(
        footnote: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(DPIcons.shieldCheck, size: 16, color: DP.navyIcon),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Your money is safe and secure with Dalabapay',
                style: DP.caption,
              ),
            ),
          ],
        ),
        child: DPButton(
          label: 'Continue',
          loading: _lookingUp,
          onPressed: _canContinue ? _continue : null,
        ),
      ),
    );
  }
}
