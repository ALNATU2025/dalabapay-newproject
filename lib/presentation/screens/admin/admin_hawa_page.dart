// lib/presentation/screens/admin/admin_hawa_page.dart
// Hawa, the admin AI assistant (step 1: questions, read-only). The admin
// types a question; the server answers it from live data with the admin's
// own permissions. POST /api/admin/hawa/chat, GET /api/admin/hawa/status.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import 'admin_widgets.dart';

const _hawaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7C3AED), Color(0xFF2779FD), Color(0xFF079A68)],
);

const _toolLabels = {
  'dashboard_stats': 'Dashboard',
  'search_users': 'Users',
  'get_user': 'User profile',
  'user_history': 'User history',
  'search_transactions': 'Transactions',
  'get_transaction': 'Transaction details',
  'pending_bank_funding': 'Bank top-ups',
  'approvals_summary': 'Approvals',
  'accounts_to_approve': 'Accounts to approve',
  'kyc_requests': 'KYC requests',
  'refund_queue': 'Refund queue',
  'disputes': 'Disputes',
  'alerts': 'Alerts',
  'settings': 'Settings',
  'commission_rates': 'Commission',
  'provider_status': 'Providers',
};

class HawaMessage {
  final String role; // user | assistant
  final String text;
  final List<String> tools;
  final bool error;
  final bool local; // not sent to the server (welcome, errors)
  const HawaMessage(this.role, this.text, {this.tools = const [], this.error = false, this.local = false});
}

class AdminHawaPage extends StatefulWidget {
  /// For tests and screenshots: start with these messages, skip the status call.
  @visibleForTesting
  final List<HawaMessage>? initialMessages;
  @visibleForTesting
  final bool? configured;

  const AdminHawaPage({super.key, this.initialMessages, this.configured});

  @override
  State<AdminHawaPage> createState() => _AdminHawaPageState();
}

class _AdminHawaPageState extends State<AdminHawaPage> {
  static const _welcome = HawaMessage(
    'assistant',
    "Hi, I'm Hawa 👋 Ask me anything about Dalabapay: payments, users, approvals, top-ups or revenue, "
        'for Nigeria or Sierra Leone. For now I can look things up; actions like approving are coming soon.',
    local: true,
  );
  static const _suggestions = [
    "Today's summary for Nigeria",
    'Who is waiting for approval?',
    'Any bank top-ups to confirm?',
    'Show the latest failed payments and why they failed',
    'Sierra Leone revenue this week',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final List<HawaMessage> _messages = [...(widget.initialMessages ?? const [_welcome])];
  bool _thinking = false;
  bool? _configured;
  String _model = '';

  @override
  void initState() {
    super.initState();
    _configured = widget.configured;
    if (widget.configured == null) _checkStatus();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final s = asMap(await api.get('/api/admin/hawa/status'));
      if (!mounted) return;
      setState(() {
        _configured = s['configured'] == true;
        _model = str(s['model']);
      });
    } catch (_) {
      if (mounted) setState(() => _configured = true); // let the chat report the problem
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty || _thinking) return;
    HapticFeedback.selectionClick();
    _input.clear();
    setState(() {
      _messages.add(HawaMessage('user', q));
      _thinking = true;
    });
    _toBottom();
    final history = _messages.where((m) => !m.local && !m.error).toList();
    final recent = history.length > 20 ? history.sublist(history.length - 20) : history;
    try {
      final r = asMap(await api.post('/api/admin/hawa/chat', {
        'messages': [
          for (final m in recent) {'role': m.role, 'content': m.text},
        ],
      }));
      if (!mounted) return;
      setState(() {
        _messages.add(HawaMessage(
          'assistant',
          str(r['reply']),
          tools: [for (final t in (r['tools'] as List? ?? const [])) str(asMap(t)['name'])],
        ));
        _thinking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(HawaMessage('assistant', errorMessage(e), error: true, local: true));
        _thinking = false;
      });
    }
    _toBottom();
  }

  void _retry() {
    final lastQ = _messages.lastWhere((m) => m.role == 'user', orElse: () => const HawaMessage('user', ''));
    if (lastQ.text.isEmpty) return;
    setState(() {
      // Drop the failed question and its error; ask again.
      final i = _messages.lastIndexOf(lastQ);
      _messages.removeRange(i, _messages.length);
    });
    _send(lastQ.text);
  }

  void _clear() {
    setState(() {
      _messages
        ..clear()
        ..add(_welcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = !_thinking && _messages.every((m) => m.role != 'user');
    return AdminScaffold(
      title: 'Ask Hawa',
      breadcrumb: _model.isEmpty ? 'Admin · AI assistant' : 'Admin · AI assistant · $_model',
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: _thinking ? null : _clear,
          icon: Icon(Icons.add_comment_outlined, color: DP.navyInk, size: 20),
        ),
      ],
      body: Column(
        children: [
          if (_configured == false) _notSetUp(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                for (var i = 0; i < _messages.length; i++)
                  DPAppear(
                    key: ValueKey('m$i'),
                    child: _bubble(_messages[i], isLast: i == _messages.length - 1),
                  ),
                if (_thinking) const _Thinking(),
                if (showSuggestions) ...[
                  const SizedBox(height: 8),
                  Text('Try asking', style: DP.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 15, color: Color(0xFF7C3AED)),
                          label: Text(s, style: DP.body.copyWith(fontSize: 12.5)),
                          backgroundColor: DP.surface,
                          side: BorderSide(color: DP.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onPressed: _configured == false ? null : () => _send(s),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _notSetUp() => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DP.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DP.rMd),
          border: Border.all(color: DP.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.key_rounded, color: DP.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Hawa isn't set up yet. Add ANTHROPIC_API_KEY in Render → Environment, then try again.",
                style: DP.body.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      );

  Widget _avatar() => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(gradient: _hawaGradient, shape: BoxShape.circle, boxShadow: DP.glow(const Color(0xFF7C3AED), strength: 0.4)),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
      );

  Widget _bubble(HawaMessage m, {required bool isLast}) {
    final mine = m.role == 'user';
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: mine ? DP.navyGradient : null,
        color: mine ? null : (m.error ? DP.red.withValues(alpha: 0.08) : DP.surface),
        border: mine ? null : Border.all(color: m.error ? DP.red.withValues(alpha: 0.3) : DP.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            _rich(m.text, DP.body.copyWith(fontSize: 14, height: 1.45, color: mine ? Colors.white : (m.error ? DP.red : DP.ink))),
          ),
          if (m.tools.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.manage_search_rounded, size: 13, color: DP.muted),
                Text('Checked:', style: DP.caption.copyWith(fontSize: 11)),
                for (final t in {...m.tools})
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: DP.borderSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_toolLabels[t] ?? t, style: DP.caption.copyWith(fontSize: 10.5)),
                  ),
              ],
            ),
          ],
          if (m.error && isLast)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: bubble),
          ),
          if (mine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// **bold** and "- " / "• " bullets, nothing more.
  TextSpan _rich(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    for (var li = 0; li < lines.length; li++) {
      var line = lines[li];
      final bullet = RegExp(r'^\s*[-*•]\s+').firstMatch(line);
      if (bullet != null) line = '•  ${line.substring(bullet.end)}';
      final parts = line.split('**');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        spans.add(TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base));
      }
      if (li < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(children: spans, style: base);
  }

  Widget _composer() {
    final enabled = _configured != false;
    return Container(
      decoration: BoxDecoration(
        color: DP.surface,
        border: Border(top: BorderSide(color: DP.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  style: DP.body.copyWith(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Ask Hawa…',
                    counterText: '',
                    filled: true,
                    fillColor: DP.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: DP.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: DP.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Send',
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: enabled && !_thinking && _input.text.trim().isNotEmpty ? 1 : 0.45,
                  child: Material(
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: const BoxDecoration(gradient: _hawaGradient, shape: BoxShape.circle),
                      child: InkWell(
                        onTap: enabled && !_thinking ? () => _send() : null,
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hawa is looking things up: three bouncing dots.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(gradient: _hawaGradient, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DP.surface,
              border: Border.all(color: DP.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Transform.translate(
                          offset: Offset(0, -3 * _bounce((_c.value - i * 0.15) % 1)),
                          child: Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.5 + 0.5 * _bounce((_c.value - i * 0.15) % 1)),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('Hawa is checking…', style: DP.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _bounce(double t) => t < 0.5 ? (t < 0.25 ? t * 4 : (0.5 - t) * 4) : 0;
}
