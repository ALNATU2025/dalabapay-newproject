// lib/presentation/screens/admin/admin_kyc_page.dart
// Manual KYC for Sierra Leone: approve or reject new accounts, and review
// account-level upgrades (Tier 2 ID, Tier 3 bank, Tier 4 business) with
// their documents.
//   GET  /api/admin/kyc/accounts?status=pending|rejected
//   POST /api/admin/users/:id/approve | reject { reason }
//   GET  /api/admin/kyc/requests?status=pending|approved|rejected
//   GET  /api/admin/kyc/requests/:id   (with the photos)
//   POST /api/admin/kyc/requests/:id/approve | reject { reason }
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';

class AdminKycPage extends StatefulWidget {
  const AdminKycPage({super.key});

  @override
  State<AdminKycPage> createState() => _AdminKycPageState();
}

class _AdminKycPageState extends State<AdminKycPage> {
  int _tab = 0; // 0 new accounts, 1 upgrades
  String _status = 'pending';
  int _version = 0;

  bool get _canApprove => adminCan('users:approve');

  Future<List<Map<String, dynamic>>> _load() async {
    if (_tab == 0) {
      return asList(await api.get('/api/admin/kyc/accounts', query: {'status': _status == 'approved' ? 'pending' : _status}));
    }
    return asList(await api.get('/api/admin/kyc/requests', query: {'status': _status}));
  }

  void _reload() => setState(() => _version++);

  Future<String?> _askReason(String title) async {
    final c = TextEditingController();
    return showAdminSheet<String>(
      context,
      title: title,
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DPLabel('Reason (the customer sees this)'),
          DPField(controller: c, hint: 'e.g. The photo is not clear', maxLines: 3),
          const SizedBox(height: 16),
          DPButton(
            label: 'Reject',
            background: DP.red,
            onPressed: () {
              if (c.text.trim().length < 3) {
                dpSnack(ctx, 'Give a reason', error: true);
                return;
              }
              Navigator.pop(ctx, c.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _decideAccount(Map<String, dynamic> u, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason('Reject ${str(u['fullName'])}');
      if (reason == null) return;
    }
    if (!mounted) return;
    final r = await runWithFeedback(
      context,
      () => api.post('/api/admin/users/${u['id']}/${approve ? 'approve' : 'reject'}', {if (reason != null) 'reason': reason}),
      success: approve ? 'Account approved (Tier 1)' : 'Account rejected',
    );
    if (r != null && mounted) {
      Navigator.of(context).maybePop();
      _reload();
    }
  }

  Future<void> _decideRequest(Map<String, dynamic> req, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason('Reject Tier ${toInt(req['tier'])} request');
      if (reason == null) return;
    }
    if (!mounted) return;
    final r = await runWithFeedback(
      context,
      () => api.post('/api/admin/kyc/requests/${req['id']}/${approve ? 'approve' : 'reject'}', {if (reason != null) 'reason': reason}),
      success: approve ? 'Upgraded to Tier ${toInt(req['tier'])}' : 'Request rejected',
    );
    if (r != null && mounted) {
      Navigator.of(context).maybePop();
      _reload();
    }
  }

  void _openAccount(Map<String, dynamic> u) {
    showAdminSheet<void>(
      context,
      title: str(u['fullName']),
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPSummaryRow('Email', str(u['email'])),
          DPSummaryRow('Phone', str(u['phone'])),
          DPSummaryRow('Country', str(u['country']) == 'SL' ? 'Sierra Leone' : str(u['country'])),
          DPSummaryRow('Email verified', u['emailVerified'] == true ? 'Yes' : 'No'),
          DPSummaryRow('Phone verified', u['phoneVerified'] == true ? 'Yes' : 'No'),
          DPSummaryRow('Signed up', dateTimeLabel(parseDate(u['createdAt']))),
          if (str(u['approvalNote']).isNotEmpty) DPSummaryRow('Rejected because', str(u['approvalNote'])),
          const SizedBox(height: 16),
          if (_canApprove)
            Row(
              children: [
                Expanded(child: DPOutlineButton(label: 'Reject', color: DP.red, onPressed: () => _decideAccount(u, false))),
                const SizedBox(width: 10),
                Expanded(child: DPButton(label: 'Approve', icon: DPIcons.check, onPressed: () => _decideAccount(u, true))),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openRequest(Map<String, dynamic> brief) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _RequestDetail(
        id: str(brief['id']),
        canApprove: _canApprove && brief['status'] == 'pending',
        onDecide: _decideRequest,
      ),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _tab == 0 ? const ['pending', 'rejected'] : const ['pending', 'approved', 'rejected'];
    if (!statuses.contains(_status)) _status = 'pending';
    return AdminScaffold(
      title: 'KYC Review',
      breadcrumb: 'Admin / KYC Review',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Column(
              children: [
                DPSegmented(
                  options: const ['New accounts', 'Tier upgrades'],
                  index: _tab,
                  onChanged: (i) => setState(() {
                    _tab = i;
                    _status = 'pending';
                    _version++;
                  }),
                ),
                const SizedBox(height: 12),
                DPChipRow(
                  options: [for (final s in statuses) s[0].toUpperCase() + s.substring(1)],
                  selected: _status[0].toUpperCase() + _status.substring(1),
                  height: 38,
                  onSelect: (label) => setState(() {
                    _status = label.toLowerCase();
                    _version++;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Map<String, dynamic>>>(
              key: ValueKey('$_tab$_status$_version'),
              load: _load,
              builder: (context, rows, reload) {
                if (rows.isEmpty) {
                  return DPEmptyState(
                    icon: DPIcons.shieldCheck,
                    title: _status == 'pending' ? 'Nothing to review' : 'None yet',
                    message: _tab == 0 ? 'New Sierra Leone sign-ups appear here.' : 'Upgrade requests appear here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      for (final r in rows) _tab == 0 ? _accountRow(r) : _requestRow(r),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(Map<String, dynamic> u) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DPCard(
          onTap: () => _openAccount(u),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              DPAvatar(name: str(u['fullName']), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(u['fullName']), style: DP.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${str(u['phone'])} · ${timeAgo(parseDate(u['createdAt']))}', style: DP.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              StatusPill(_status == 'pending' ? 'Pending' : 'Rejected'),
            ],
          ),
        ),
      );

  Widget _requestRow(Map<String, dynamic> r) {
    final u = asMap(r['user']);
    final d = asMap(r['details']);
    final what = switch (toInt(r['tier'])) {
      2 => str(d['docTypeName'], 'ID document'),
      3 => 'Bank · ${str(d['bankName'])}',
      _ => 'Business · ${str(d['businessName'])}',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DPCard(
        onTap: () => _openRequest(r),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            DPIconBadge.blue(DPIcons.badge, size: 40, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${str(u['fullName'])} → Tier ${toInt(r['tier'])}', style: DP.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$what · ${timeAgo(parseDate(r['createdAt']))}', style: DP.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            StatusPill(str(r['status'])),
          ],
        ),
      ),
    );
  }
}

class _RequestDetail extends StatelessWidget {
  final String id;
  final bool canApprove;
  final Future<void> Function(Map<String, dynamic> req, bool approve) onDecide;
  const _RequestDetail({required this.id, required this.canApprove, required this.onDecide});

  static const _labels = {
    'docTypeName': 'Document',
    'docNumber': 'Document number',
    'bankName': 'Bank',
    'accountNumber': 'Account number',
    'accountName': 'Account name',
    'businessName': 'Business name',
    'registrationNumber': 'Registration no.',
    'businessAddress': 'Business address',
  };

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Upgrade request',
      breadcrumb: 'Admin / KYC Review / Request',
      body: AsyncView<Map<String, dynamic>>(
        load: () async => asMap(await api.get('/api/admin/kyc/requests/$id')),
        builder: (context, r, _) {
          final u = asMap(r['user']);
          final d = asMap(r['details']);
          final files = asList(r['files']);
          final pending = r['status'] == 'pending';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
            children: [
              DPCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Tier ${toInt(u['tier'])} → Tier ${toInt(r['tier'])}', style: DP.section)),
                        StatusPill(str(r['status'])),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DPSummaryRow('Customer', str(u['fullName'])),
                    DPSummaryRow('Phone', str(u['phone'])),
                    DPSummaryRow('Email', str(u['email'])),
                    DPSummaryRow('Balance', DP.moneyIn(toDouble(u['balance']), 'SLE')),
                    DPSummaryRow('Sent', dateTimeLabel(parseDate(r['createdAt']))),
                    for (final e in d.entries)
                      if (_labels.containsKey(e.key)) DPSummaryRow(_labels[e.key]!, str(e.value)),
                    if (str(r['rejectionReason']).isNotEmpty) DPSummaryRow('Rejected because', str(r['rejectionReason'])),
                    if (str(r['reviewedBy']).isNotEmpty) DPSummaryRow('Reviewed by', str(r['reviewedBy'])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (files.isEmpty) const DPHelper('No photos were attached.'),
              for (final f in files) _photo(context, f),
              if (canApprove && pending) ...[
                const SizedBox(height: 8),
                const DPHelper('Check the name matches the account and the photo is clear and unedited.', icon: DPIcons.info),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: DPOutlineButton(label: 'Reject', color: DP.red, onPressed: () => onDecide(r, false))),
                    const SizedBox(width: 10),
                    Expanded(child: DPButton(label: 'Approve', icon: DPIcons.check, onPressed: () => onDecide(r, true))),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _photo(BuildContext context, Map<String, dynamic> f) {
    final raw = str(f['data']);
    Widget img;
    try {
      img = Image.memory(base64Decode(raw), fit: BoxFit.contain, gaplessPlayback: true);
    } catch (_) {
      img = const DPHelper('This photo can\'t be shown.');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPLabel(str(f['label'], 'Photo')),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(12),
                child: InteractiveViewer(maxScale: 5, child: img),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DP.rLg),
              child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: img),
            ),
          ),
          const SizedBox(height: 4),
          Text('Tap to zoom', style: DP.tiny),
        ],
      ),
    );
  }
}
