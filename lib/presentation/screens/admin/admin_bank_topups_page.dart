// lib/presentation/screens/admin/admin_bank_topups_page.dart
// Nigeria bank-transfer top-ups waiting for an admin. Opened from the
// admin dashboard, or from the push "Foday has sent ₦50,000" (tap, or its
// Confirm / Cancel buttons — those act straight away).
//   GET  /api/admin/funding/bank          pending top-ups
//   GET  /api/admin/funding/bank/:id
//   POST /api/admin/funding/bank/:id/confirm | cancel { note }
import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminBankTopUpsPage extends StatefulWidget {
  /// From a notification: the top-up, and "confirm" / "cancel" when a
  /// notification button was tapped.
  final String? focusId;
  final String? action;
  const AdminBankTopUpsPage({super.key, this.focusId, this.action});

  @override
  State<AdminBankTopUpsPage> createState() => _AdminBankTopUpsPageState();
}

class _AdminBankTopUpsPageState extends State<AdminBankTopUpsPage> {
  int _version = 0;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    final id = widget.focusId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fromNotification(id, widget.action));
    }
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      asList(asMap(await api.get('/api/admin/funding/bank'))['topUps']);

  void _reload() => setState(() => _version++);

  Future<void> _fromNotification(String id, String? action) async {
    if (action == 'confirm' || action == 'cancel') {
      await _decide(id, action!, ask: false);
      return;
    }
    try {
      final t = asMap(asMap(await api.get('/api/admin/funding/bank/$id'))['topUp']);
      if (t.isNotEmpty && mounted) await _open(t);
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _decide(String id, String action, {bool ask = true, double? amount, String? name}) async {
    String? note;
    if (ask && action == 'cancel') {
      final c = TextEditingController(text: 'Payment not received.');
      note = await showAdminSheet<String>(
        context,
        title: 'Cancel top-up',
        builder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DPLabel('Message to the customer'),
            DPField(controller: c, maxLines: 2),
            const SizedBox(height: 16),
            DPButton(label: 'Cancel top-up', background: DP.red, onPressed: () => Navigator.pop(ctx, c.text.trim())),
          ],
        ),
      );
      if (note == null) return;
    } else if (ask) {
      final ok = await dpDialog(
        context,
        title: 'Confirm ${amount != null ? DP.naira(amount) : 'this top-up'}?',
        message: 'Only confirm after you have seen the money in the account${name != null ? ' from $name' : ''}. The wallet is credited immediately.',
        confirmLabel: 'Confirm and credit',
        cancelLabel: 'Not yet',
        tone: DPTone.info,
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    final r = await runWithFeedback(
      context,
      () => api.post('/api/admin/funding/bank/$id/$action', {if (note != null && note.isNotEmpty) 'note': note}),
    );
    if (!mounted || r == null) return;
    final m = asMap(r);
    final t = asMap(m['topUp']);
    final res = str(m['result']);
    final amt = DP.naira(toDouble(t['amount']));
    dpSnack(
      context,
      res == 'confirmed'
          ? '$amt credited to the customer'
          : res == 'cancelled'
              ? 'Top-up cancelled'
              : 'Already ${str(t['stage']) == 'confirmed' ? 'confirmed' : 'cancelled'} — nothing changed',
      success: res == 'confirmed',
    );
    if (_sheetOpen) Navigator.of(context).pop();
    _reload();
  }

  Future<void> _open(Map<String, dynamic> t) async {
    final u = asMap(t['user']);
    final a = asMap(t['account']);
    final pending = str(t['status']) == 'pending';
    _sheetOpen = true;
    await showAdminSheet<void>(
      context,
      title: '${str(u['fullName'], 'Customer')} · ${DP.naira(toDouble(t['amount']))}',
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPSummaryRow('Amount', DP.naira(toDouble(t['amount'])), strong: true),
          DPSummaryRow('Status', _stageLabel(str(t['stage']))),
          DPSummaryRow('Phone', str(u['phone'])),
          DPSummaryRow('Email', str(u['email'])),
          DPSummaryRow('Paid to', '${str(a['bankName'])} ${str(a['accountNumber'])}'),
          DPSummaryRow('Reference', str(t['reference'])),
          DPSummaryRow('Started', dateTimeLabel(parseDate(t['createdAt']))),
          if (t['sentAt'] != null) DPSummaryRow('"I have sent it"', dateTimeLabel(parseDate(t['sentAt']))),
          const SizedBox(height: 10),
          const DPBanner('Check your bank app for this amount from this customer before confirming.', tone: DPTone.warning),
          const SizedBox(height: 16),
          if (pending && adminCan('transactions:status'))
            Row(
              children: [
                Expanded(
                  child: DPOutlineButton(
                    label: 'Cancel',
                    color: DP.red,
                    onPressed: () => _decide(str(t['id']), 'cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DPButton(
                    label: 'Confirm',
                    icon: DPIcons.check,
                    onPressed: () => _decide(str(t['id']), 'confirm', amount: toDouble(t['amount']), name: str(u['fullName'])),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    _sheetOpen = false;
  }

  static String _stageLabel(String s) => switch (s) {
        'sent' => 'Customer says sent',
        'awaiting' => 'Not sent yet',
        'confirmed' => 'Confirmed',
        'cancelled' => 'Cancelled',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Bank Top-ups',
      breadcrumb: 'Admin / Funding',
      body: AsyncView<List<Map<String, dynamic>>>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return const DPEmptyState(
              icon: DPIcons.bank,
              title: 'No top-ups waiting',
              message: 'When a customer taps "I have sent it", it shows here and on your phone.',
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              children: [
                AdminListCard(
                  children: [
                    for (final t in list)
                      DPListRow(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        leading: DPIconBadge(
                          str(t['stage']) == 'sent' ? Icons.mark_email_unread_outlined : DPIcons.pending,
                          size: 40,
                          iconSize: 19,
                        ),
                        title: '${str(asMap(t['user'])['fullName'], 'Customer')} · ${DP.naira(toDouble(t['amount']))}',
                        subtitle: '${_stageLabel(str(t['stage']))} · ${agoOf(parseDate(t['sentAt'] ?? t['createdAt']))}',
                        trailing: Icon(DPIcons.chevronRight, color: DP.muted),
                        onTap: () => _open(t),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
